import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/group_category.dart';
import '../models/group_message.dart';
import '../models/social_group.dart';
import '../services/group_join_result.dart';
import 'social_group_repository.dart';

/// Supabase Sosyal Omurga V1 — `social_groups` + `group_members` +
/// `group_messages` tablolarına yazar/okur.
///
/// **Tasarım kararları:**
/// - profiles RLS owner-only olarak korunuyor; group satırlarına
///   `owner_name` + group_messages.`author_name/role` snapshot ediliyor
///   (BEFORE INSERT trigger profiles'tan doldurur).
/// - `member_count` denormalize sütun; group_members triggerla bakım edilir.
/// - createGroup → social_groups INSERT + owner satırı group_members INSERT
///   ile birlikte atomik **değil** (iki ayrı INSERT). Eğer ikinci başarısız
///   olursa grup üyesiz kalır; bu durumda owner SELECT ile görür ve manuel
///   yeniden join atabilir. Pratik nadir; V1 için kabul edilebilir.
/// - joinGroup → max_members aşımı server-side BEFORE INSERT triggerla
///   `group_full` PG exception'ı atar; client `PostgrestException` mesajını
///   yakalayıp `GroupJoinResult.full` döner.
/// - leaveGroup → owner ise no-op (owner kendi grubundan ayrılamaz, V1
///   ownership transfer ekranı yok). UI bunu özel olarak gizler veya
///   kullanıcı sessiz dönüş alır.
/// - `isJoined` interface'i sync; SupabaseRepo her `list*` çağrısında
///   joined set'i yeniler ve cache'ler. Cache miss durumunda `false` döner;
///   listenleyen provider sonraki tick'te doğru değeri okur.
class SupabaseSocialGroupRepository implements SocialGroupRepository {
  SupabaseSocialGroupRepository(this._client);

  final sb.SupabaseClient _client;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Sync `isJoined` için lazy cache. listGroups/listJoined/joinGroup/leaveGroup
  /// sonrası güncellenir.
  final Set<String> _joinedCache = <String>{};
  bool _joinedLoaded = false;

  void _notify() => _changes.add(null);

  String? get _currentUserId => _client.auth.currentUser?.id;

  static const String _groupColumns =
      'id, owner_id, name, description, category, city, is_private, '
      'max_members, tags, visual_seed, owner_name, member_count, '
      'created_at';

  static const String _messageColumns =
      'id, group_id, owner_id, text, author_name, author_role, '
      'is_deleted, created_at';

  // ─────────────────────────────────────── Mapping

  SocialGroup _groupFromRow(Map<String, dynamic> row) {
    final tagsRaw = row['tags'] as List?;
    return SocialGroup(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      category: GroupCategoryLabel.fromPersistKey(
          (row['category'] as String?) ?? 'bakers'),
      ownerName: (row['owner_name'] as String?) ?? '',
      ownerId: row['owner_id'] as String,
      city: (row['city'] as String?) ?? '',
      isPrivate: (row['is_private'] as bool?) ?? false,
      maxMembers: (row['max_members'] as num?)?.toInt(),
      currentMemberCount: ((row['member_count'] as num?) ?? 0).toInt(),
      createdAt: DateTime.parse(row['created_at'] as String),
      tags: tagsRaw == null
          ? const <String>[]
          : List<String>.unmodifiable(tagsRaw.cast<String>()),
      visualSeed: ((row['visual_seed'] as num?) ?? 0).toInt(),
    );
  }

  GroupMessage _messageFromRow(Map<String, dynamic> row) {
    return GroupMessage(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      authorName:
          (row['author_name'] as String?) ?? 'FırınNet Kullanıcısı',
      authorRole: (row['author_role'] as String?) ?? 'Üye',
      text: (row['text'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
      // V1'de pinned/reaction sütunları DB'de yok; ileride eklenebilir.
      isPinned: false,
      reactionCount: 0,
    );
  }

  /// Mevcut kullanıcının üye olduğu grup id'lerini çekip cache'ler.
  Future<void> _refreshJoinedCache() async {
    final userId = _currentUserId;
    _joinedCache.clear();
    if (userId == null) {
      _joinedLoaded = true;
      return;
    }
    final rows = await _client
        .from('group_members')
        .select('group_id')
        .eq('owner_id', userId);
    for (final r in (rows as List)) {
      _joinedCache.add((r as Map<String, dynamic>)['group_id'] as String);
    }
    _joinedLoaded = true;
  }

  Future<void> _ensureJoinedCache() async {
    if (!_joinedLoaded) await _refreshJoinedCache();
  }

  // ─────────────────────────────────────── Listing

  @override
  Future<List<SocialGroup>> listGroups({GroupCategory? category}) async {
    // Joined cache'i listeleme sırasında doldur — sync isJoined() için.
    await _ensureJoinedCache();
    var q = _client
        .from('social_groups')
        .select(_groupColumns)
        .eq('is_deleted', false);
    if (category != null) {
      q = q.eq('category', category.persistKey);
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_groupFromRow)
        .toList(growable: false);
  }

  @override
  Future<List<SocialGroup>> listPopular({int limit = 6}) async {
    await _ensureJoinedCache();
    final rows = await _client
        .from('social_groups')
        .select(_groupColumns)
        .eq('is_deleted', false)
        .order('member_count', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_groupFromRow)
        .toList(growable: false);
  }

  @override
  Future<List<SocialGroup>> listJoined() async {
    await _refreshJoinedCache();
    if (_joinedCache.isEmpty) return const <SocialGroup>[];
    final rows = await _client
        .from('social_groups')
        .select(_groupColumns)
        .eq('is_deleted', false)
        .inFilter('id', _joinedCache.toList(growable: false))
        .order('name');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_groupFromRow)
        .toList(growable: false);
  }

  @override
  Future<SocialGroup?> getGroup(String id) async {
    await _ensureJoinedCache();
    final row = await _client
        .from('social_groups')
        .select(_groupColumns)
        .eq('id', id)
        .eq('is_deleted', false)
        .maybeSingle();
    if (row == null) return null;
    return _groupFromRow(row);
  }

  @override
  bool isJoined(String id) => _joinedCache.contains(id);

  // ─────────────────────────────────────── Mutations

  @override
  Future<SocialGroup> createGroup({
    required String name,
    required String description,
    required GroupCategory category,
    String city = '',
    bool isPrivate = false,
    int? maxMembers,
    List<String> tags = const <String>[],
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    // Visual seed: deterministik ama biraz çeşitli.
    final visualSeed = DateTime.now().microsecondsSinceEpoch % 8;

    final groupRow = await _client
        .from('social_groups')
        .insert(<String, dynamic>{
          'owner_id': userId,
          'name': name.trim(),
          'description': description.trim(),
          'category': category.persistKey,
          if (city.trim().isNotEmpty) 'city': city.trim(),
          'is_private': isPrivate,
          // max_members null → DB default 250. Spec: kolon NOT NULL DEFAULT 250.
          if (maxMembers != null) 'max_members': maxMembers,
          'tags': tags,
          'visual_seed': visualSeed,
          // owner_name server-side trigger ile doldurulur.
        })
        .select(_groupColumns)
        .single();

    final groupId = groupRow['id'] as String;

    // Owner'ı group_members'a 'owner' rolüyle yaz.
    try {
      await _client.from('group_members').insert(<String, dynamic>{
        'group_id': groupId,
        'owner_id': userId,
        'role': 'owner',
      });
      _joinedCache.add(groupId);
    } catch (_) {
      // Üye satırı oluşmazsa grup üyesiz kalır; owner sonra join atabilir.
      // (Atomik transaction olsa daha güzel; V1 için trade-off.)
    }

    _notify();

    // member_count trigger ile +1 oldu — taze satırı yeniden çek.
    final refreshed = await _client
        .from('social_groups')
        .select(_groupColumns)
        .eq('id', groupId)
        .single();
    return _groupFromRow(refreshed);
  }

  @override
  Future<GroupJoinResult> joinGroup(String id) async {
    final userId = _currentUserId;
    if (userId == null) {
      return GroupJoinResult.notFound;
    }
    if (_joinedCache.contains(id)) {
      return GroupJoinResult.alreadyJoined;
    }

    // Grup var mı ve görünür mü? Görünmüyorsa RLS sayesinde null döner.
    final groupRow = await _client
        .from('social_groups')
        .select('id, max_members, member_count, is_deleted')
        .eq('id', id)
        .maybeSingle();
    if (groupRow == null || (groupRow['is_deleted'] as bool? ?? false)) {
      return GroupJoinResult.notFound;
    }

    try {
      await _client.from('group_members').insert(<String, dynamic>{
        'group_id': id,
        'owner_id': userId,
        'role': 'member',
      });
    } on sb.PostgrestException catch (e) {
      // BEFORE INSERT trigger `group_full` raise eder.
      final msg = e.message.toLowerCase();
      if (msg.contains('group_full')) return GroupJoinResult.full;
      if (msg.contains('group_not_found') ||
          msg.contains('group_deleted')) {
        return GroupJoinResult.notFound;
      }
      // duplicate key (composite PK) → zaten üye.
      if (e.code == '23505') return GroupJoinResult.alreadyJoined;
      rethrow;
    }
    _joinedCache.add(id);
    _notify();
    return GroupJoinResult.success;
  }

  @override
  Future<void> leaveGroup(String id) async {
    final userId = _currentUserId;
    if (userId == null) return;
    if (!_joinedCache.contains(id)) return;

    // Owner kendi grubundan ayrılamaz (V1 ownership transfer ekranı yok).
    // Sessizce no-op döner; UI tarafında "owner leave" özel ele alınmalı.
    final group = await _client
        .from('social_groups')
        .select('owner_id')
        .eq('id', id)
        .maybeSingle();
    if (group == null) return;
    if ((group['owner_id'] as String?) == userId) {
      return;
    }

    await _client
        .from('group_members')
        .delete()
        .eq('group_id', id)
        .eq('owner_id', userId);
    _joinedCache.remove(id);
    _notify();
  }

  @override
  Future<List<GroupMessage>> listMessages(String groupId) async {
    final rows = await _client
        .from('group_messages')
        .select(_messageColumns)
        .eq('group_id', groupId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_messageFromRow)
        .toList(growable: false);
  }

  @override
  Future<void> postMessage(GroupMessage m) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    await _client.from('group_messages').insert(<String, dynamic>{
      'group_id': m.groupId,
      'owner_id': userId,
      'text': m.text,
      // author_name / author_role server-side trigger ile.
    });
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
