import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../messaging/services/chat_media_signed_url_cache.dart';
import '../models/group_category.dart';
import '../models/group_join_request.dart';
import '../models/group_member.dart';
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
      'is_deleted, attachments, created_at';

  static const String _chatMediaBucket = 'chat-media';

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
      // UGC Safety V1 — owner_id zaten SELECT'te vardı; artık parse edilir
      // (şikayet/engelleme + kendi mesajı ayrımı).
      ownerId: row['owner_id'] as String?,
      authorName:
          (row['author_name'] as String?) ?? 'FırınNet Kullanıcısı',
      authorRole: (row['author_role'] as String?) ?? 'Üye',
      text: (row['text'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
      // V1'de pinned/reaction sütunları DB'de yok; ileride eklenebilir.
      isPinned: false,
      reactionCount: 0,
      attachments: row['attachments'] as Map<String, dynamic>?,
    );
  }

  /// Sprint G — grup medya mesajının (image V1 / video V1.1) storage_path'i
  /// için signed URL üretip attachments['url']'e gömer (chat-media private).
  /// Hatada url'siz döner.
  Future<GroupMessage> _enrichImage(GroupMessage m) async {
    final path = m.imageStoragePath;
    if (!(m.hasImage || m.hasVideo) || path == null) return m;
    try {
      // Perf: aynı oturumda aynı path yeniden imzalanmaz (signed URL cache).
      final url = await ChatMediaSignedUrlCache.instance
          .resolveWith(_client, _chatMediaBucket, path);
      final next = Map<String, dynamic>.from(m.attachments ?? const {});
      next['url'] = url;
      return GroupMessage(
        id: m.id,
        groupId: m.groupId,
        ownerId: m.ownerId,
        authorName: m.authorName,
        authorRole: m.authorRole,
        text: m.text,
        createdAt: m.createdAt,
        isPinned: m.isPinned,
        reactionCount: m.reactionCount,
        attachments: next,
      );
    } catch (_) {
      return m;
    }
  }

  /// Mevcut kullanıcının üye olduğu grup id'lerini çekip cache'ler.
  ///
  /// Sprint 1 / GB-2 — Cache içeriği gerçekten değişirse `_notify()` çağrılır
  /// ki `isJoinedProvider` (sync, `groupChangesProvider` watch'lar) stale
  /// kalmasın. Diff-check zorunlu: aksi halde `listJoined` her çağrıda
  /// refresh → notify → tick → listJoined sonsuz döngüsüne girer.
  ///
  /// P0 — ATOMİK SWAP zorunlu: eski sürüm önce `_joinedCache.clear()` yapıp
  /// SONRA network'ü await ediyordu. O boş pencerede tetiklenen herhangi bir
  /// rebuild `isJoined`'ı false okuyor (üye kullanıcıda composer →
  /// "Sohbete katıl"), refresh aynı set ile bitince diff-check notify'ı da
  /// bastırıyor ve UI false'ta KİLİTLİ kalıyordu. Yeni set kenarda kurulur,
  /// await'ten sonra senkron swap edilir — okuyucular ya eski ya yeni seti
  /// görür, asla boş ara durumu görmez.
  Future<void> _refreshJoinedCache() async {
    final userId = _currentUserId;
    if (userId == null) {
      final hadAny = _joinedCache.isNotEmpty;
      _joinedCache.clear();
      _joinedLoaded = true;
      if (hadAny) _notify();
      return;
    }
    final rows = await _client
        .from('group_members')
        .select('group_id')
        .eq('owner_id', userId);
    final next = <String>{
      for (final r in (rows as List))
        (r as Map<String, dynamic>)['group_id'] as String,
    };
    final changed = next.length != _joinedCache.length ||
        !next.containsAll(_joinedCache);
    _joinedCache
      ..clear()
      ..addAll(next);
    _joinedLoaded = true;
    if (kDebugMode) {
      debugPrint('[FirinNet][Groups] joinedCache REFRESH uid=$userId '
          'count=${_joinedCache.length} repo=#${identityHashCode(this)}');
    }
    if (changed) _notify();
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
    // Hardening: defansif üst sınır (grup dizini büyüse de RAM korunur).
    final rows =
        await q.order('created_at', ascending: false).limit(500);
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
    // V1 P0 — is_private kolonu da çekilir; private gruplar `joinGroup`
    // yolundan değil `requestJoinGroup` ile katılır. RLS server tarafında
    // da aynı kontrolü yapar (group_members_insert_self policy), ama
    // client-side erken reddetme UX için temiz: gereksiz REST INSERT
    // attempt + 403 round-trip'i önler.
    final groupRow = await _client
        .from('social_groups')
        .select('id, max_members, member_count, is_deleted, is_private')
        .eq('id', id)
        .maybeSingle();
    if (groupRow == null || (groupRow['is_deleted'] as bool? ?? false)) {
      return GroupJoinResult.notFound;
    }
    if ((groupRow['is_private'] as bool?) ?? false) {
      return GroupJoinResult.requiresApproval;
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
      // duplicate key (composite PK) → zaten üye. P0: DB üyeliği doğruladı;
      // stale cache onarılır + notify edilir ki isJoinedProvider true'ya
      // dönüp footer "Sohbete katıl" yerine composer'a geçsin.
      if (e.code == '23505') {
        _joinedCache.add(id);
        _notify();
        return GroupJoinResult.alreadyJoined;
      }
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
    final list = (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_messageFromRow)
        .toList();
    // Sprint G — resim mesajlarını signed URL ile zenginleştir.
    final enriched = await Future.wait(list.map(_enrichImage));
    return List<GroupMessage>.unmodifiable(enriched);
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
      // Sprint G — opsiyonel resim eki (media_type:image, storage_path, ...).
      if (m.attachments != null) 'attachments': m.attachments,
      // author_name / author_role server-side trigger ile.
    });
    _notify();
  }

  // ─────────────────────────────────────── Private join requests (V1 P1-D)

  static const String _requestColumns =
      'id, group_id, requester_id, status, message, decided_by, decided_at, '
      'created_at, updated_at';

  @override
  Future<GroupJoinRequest> requestJoinGroup(
    String groupId, {
    String? message,
  }) async {
    final row = await _client.rpc(
      'request_group_join',
      params: <String, dynamic>{
        'p_group_id': groupId,
        if (message != null && message.trim().isNotEmpty)
          'p_message': message.trim(),
      },
    );
    if (row == null) {
      throw StateError('request_group_join boş döndü');
    }
    final map = Map<String, dynamic>.from(row as Map);
    _notify();
    return GroupJoinRequest.fromRow(map);
  }

  @override
  Future<GroupJoinRequest?> getMyJoinRequest(String groupId) async {
    final userId = _currentUserId;
    if (userId == null) return null;
    final row = await _client
        .from('group_join_requests')
        .select(_requestColumns)
        .eq('group_id', groupId)
        .eq('requester_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return GroupJoinRequest.fromRow(row);
  }

  @override
  Future<List<GroupJoinRequest>> listPendingJoinRequests(String groupId) async {
    // Önce request satırları (RLS: yalnız group owner görür); ardından
    // public_profile_snapshot RPC ile display_name/badge/city eşle.
    //
    // V1 Closure — Doğrudan `.from('profiles').inFilter(...)` kullanamayız:
    // profiles RLS owner-only (id = auth.uid()), bu nedenle owner için bile
    // requester profilleri filtrelenip empty döner. RPC SECURITY DEFINER,
    // yalnız üç güvenli kolon döner.
    final rows = await _client
        .from('group_join_requests')
        .select(_requestColumns)
        .eq('group_id', groupId)
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return const <GroupJoinRequest>[];

    final ids = list
        .map((r) => r['requester_id'] as String)
        .toSet()
        .toList(growable: false);

    final byId = await _fetchPublicProfileSnapshots(ids);

    return list
        .map((r) => GroupJoinRequest.fromRow(
              r,
              profileRow: byId[r['requester_id'] as String],
            ))
        .toList(growable: false);
  }

  @override
  Future<int> pendingJoinRequestCount(String groupId) async {
    // G.N4 — count(*) RLS-filtered: owner için pending sayısı; başka
    // kullanıcılar için 0 (RLS satır filtresi). Hata olursa 0 döneriz —
    // badge sessizce gizlenir, owner UX'i kırılmaz.
    try {
      final res = await _client
          .from('group_join_requests')
          .select('id')
          .eq('group_id', groupId)
          .eq('status', 'pending')
          .count(sb.CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<GroupJoinRequest> approveJoinRequest(String requestId) async {
    final row = await _client.rpc(
      'decide_group_join_request',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_approve': true,
      },
    );
    if (row == null) {
      throw StateError('decide_group_join_request boş döndü');
    }
    // Yeni üye eklendi → joined cache'i de invalidate edelim ki taze listJoined.
    _joinedLoaded = false;
    _notify();
    return GroupJoinRequest.fromRow(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<GroupJoinRequest> rejectJoinRequest(String requestId) async {
    final row = await _client.rpc(
      'decide_group_join_request',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_approve': false,
      },
    );
    if (row == null) {
      throw StateError('decide_group_join_request boş döndü');
    }
    _notify();
    return GroupJoinRequest.fromRow(Map<String, dynamic>.from(row as Map));
  }

  // ─────────────────────────────────────── Sprint 2 — Members management

  @override
  Future<List<GroupMemberProfile>> listMembers(String groupId) async {
    // group_members satırları RLS gating'i altında çekilir; ardından
    // public_profile_snapshot RPC ile display_name/badge/city eşle.
    //
    // V1 Closure — Doğrudan `.from('profiles').inFilter(...)` profiles
    // owner-only RLS yüzünden caller harici hiçbir satır döndürmez (her
    // üye "FırınNet Kullanıcısı" fallback'ine düşerdi). RPC SECURITY
    // DEFINER, yalnız üç güvenli kolon döner.
    final memberRows = await _client
        .from('group_members')
        .select('owner_id, role, joined_at')
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);
    final memberList = (memberRows as List).cast<Map<String, dynamic>>();
    if (memberList.isEmpty) return const <GroupMemberProfile>[];

    final userIds = memberList
        .map((r) => r['owner_id'] as String)
        .toSet()
        .toList(growable: false);

    final byId = await _fetchPublicProfileSnapshots(userIds);

    return memberList.map((r) {
      final p = byId[r['owner_id'] as String];
      return GroupMemberProfile(
        userId: r['owner_id'] as String,
        displayName: (p?['display_name'] as String?) ?? 'FırınNet Kullanıcısı',
        professionBadge: p?['profession_badge'] as String?,
        city: p?['city'] as String?,
        role: (r['role'] as String?) ?? 'member',
        joinedAt: DateTime.parse(r['joined_at'] as String),
      );
    }).toList(growable: false);
  }

  /// V1 Closure — Public profil alanlarını id listesi için RPC üzerinden
  /// çeker. profiles RLS owner-only olduğundan caller harici satırları
  /// REST select ile alamazdı; bu RPC SECURITY DEFINER ve yalnız üç güvenli
  /// kolonu (id, display_name, profession_badge, city) döner.
  ///
  /// Boş id listesi → boş Map (RPC çağrılmaz).
  /// RPC hata atarsa (örn. fonksiyon henüz canlı değilse) sessizce boş
  /// Map döner; UI tarafı fallback "FırınNet Kullanıcısı" gösterir.
  Future<Map<String, Map<String, dynamic>>> _fetchPublicProfileSnapshots(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const <String, Map<String, dynamic>>{};
    try {
      final rows = await _client.rpc(
        'public_profile_snapshot',
        params: <String, dynamic>{'p_user_ids': ids},
      );
      if (rows is! List) return const <String, Map<String, dynamic>>{};
      return <String, Map<String, dynamic>>{
        for (final p in rows.cast<Map<String, dynamic>>())
          p['id'] as String: p,
      };
    } catch (_) {
      return const <String, Map<String, dynamic>>{};
    }
  }

  @override
  Future<void> removeMember(String groupId, String memberId) async {
    await _client.rpc(
      'remove_group_member',
      params: <String, dynamic>{
        'p_group_id': groupId,
        'p_member_id': memberId,
      },
    );
    _notify();
  }

  @override
  Future<GroupLeaveOutcome> leaveGroupSafely(String groupId) async {
    final res = await _client.rpc(
      'leave_group_safely',
      params: <String, dynamic>{'p_group_id': groupId},
    );
    // Owner çıkışında joined cache'i geçersiz kıl; sonraki listJoined refresh
    // doğru durumu çekecek.
    _joinedLoaded = false;
    _joinedCache.remove(groupId);
    _notify();
    return GroupLeaveOutcome.fromPersist(res as String?);
  }

  @override
  Future<void> closeGroup(String groupId) async {
    // RLS social_groups_update_own owner için yeterli; RPC gerekmez.
    await _client
        .from('social_groups')
        .update(<String, dynamic>{'is_deleted': true})
        .eq('id', groupId);
    _joinedCache.remove(groupId);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
