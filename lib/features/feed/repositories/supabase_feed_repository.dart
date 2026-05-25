import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/feed_comment.dart';
import '../models/feed_insight.dart';
import '../models/feed_media.dart';
import '../models/feed_post.dart';
import '../models/post_type.dart';
import 'feed_repository.dart';

/// Supabase Sosyal Omurga V1 implementasyonu — `feed_posts` + `feed_likes`
/// + `feed_saves` tablolarına yazar/okur.
///
/// **Tasarım kararları:**
/// - Profile RLS owner-only kaldı; author_name + author_role feed_posts
///   satırında snapshot tutuluyor (BEFORE INSERT trigger profiles'tan
///   doldurur). UI bu yüzden tek-sorgu çekiyor; profile join yok.
/// - `like_count` / `comment_count` DB tarafında sayaç triggerlarla bakım edilir
///   → client extra count query çağırmaz.
/// - `is_liked` / `is_saved` mevcut kullanıcı için `feed_likes` / `feed_saves`
///   ikinci sorgusuyla hesaplanır (composite PK üzerinden `eq + maybeSingle`
///   yerine; çoklu post için tek `in` sorgusu).
/// - `gradient` kaldırılan bir görsel detay olduğundan post ID hash'inden
///   deterministik üretilir → DB'de saklanmaz.
/// - Yorumlar (`feed_comments`) interface'in zorunlu bir parçası değil;
///   şu an UI snackbar ile yutuyor. İleride yorum sayısı sayaç üzerinden gelir.
/// - Realtime kullanılmıyor; iç `_notify()` ile UI refresh.
class SupabaseFeedRepository implements FeedRepository {
  SupabaseFeedRepository(this._client);

  final sb.SupabaseClient _client;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _notify() => _changes.add(null);

  String? get _currentUserId => _client.auth.currentUser?.id;

  static const String _postColumns =
      'id, owner_id, type, text, tags, group_id, group_name, '
      'author_name, author_role, like_count, comment_count, created_at';

  // ─────────────────────────────────────── Mapping

  /// post id seed → 8 farklı sıcak tonlu gradient.
  /// LocalFeedRepository ile aynı palet (görsel tutarlılık).
  static const List<List<Color>> _gradients = <List<Color>>[
    [Color(0xFFF3E6D3), Color(0xFFE5D2B0)],
    [Color(0xFFEDDDC4), Color(0xFFDFCCA8)],
    [Color(0xFFF2E2C6), Color(0xFFE4D0AC)],
    [Color(0xFFF5E8CF), Color(0xFFE8D6AE)],
    [Color(0xFFEEE0C4), Color(0xFFE0CDA8)],
    [Color(0xFFF3E5C8), Color(0xFFE6D2A8)],
    [Color(0xFFEEDDC0), Color(0xFFE0CBA4)],
    [Color(0xFFF1E2C5), Color(0xFFE4D0A8)],
  ];

  static List<Color> _gradientForId(String id) {
    final h = id.hashCode.abs();
    return _gradients[h % _gradients.length];
  }

  FeedPost _fromRow(
    Map<String, dynamic> row, {
    required Set<String> likedPostIds,
    required Set<String> savedPostIds,
    Map<String, List<FeedMedia>> mediaByPostId = const {},
  }) {
    final id = row['id'] as String;
    final tagsRaw = row['tags'] as List?;
    return FeedPost(
      id: id,
      ownerId: (row['owner_id'] as String?) ?? '',
      type: PostTypeMeta.fromPersistKey((row['type'] as String?) ?? 'question'),
      author: (row['author_name'] as String?) ?? 'FırınNet Kullanıcısı',
      role: (row['author_role'] as String?) ?? 'Üye',
      text: (row['text'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
      tags: tagsRaw == null
          ? const <String>[]
          : List<String>.unmodifiable(tagsRaw.cast<String>()),
      gradient: _gradientForId(id),
      likeCount: ((row['like_count'] as num?) ?? 0).toInt(),
      commentCount: ((row['comment_count'] as num?) ?? 0).toInt(),
      isLiked: likedPostIds.contains(id),
      isSaved: savedPostIds.contains(id),
      groupId: row['group_id'] as String?,
      groupName: row['group_name'] as String?,
      mediaList: mediaByPostId[id] ?? const <FeedMedia>[],
    );
  }

  /// V1 Social S3 — Verilen post id'leri için medya satırlarını tek
  /// sorguyla çeker ve post_id → list grouping döner. RLS SELECT post
  /// görünürse media görünür koşulu sayesinde owner harici post'ların
  /// medyası da görünür (post zaten public).
  Future<Map<String, List<FeedMedia>>> _fetchMediaByPostIds(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return const <String, List<FeedMedia>>{};
    try {
      final rows = await _client
          .from('feed_media')
          .select('id, post_id, owner_id, media_type, storage_path, '
              'width, height, size_bytes, created_at')
          .inFilter('post_id', postIds)
          .eq('is_deleted', false)
          .order('created_at', ascending: true);
      final byId = <String, List<FeedMedia>>{};
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final path = r['storage_path'] as String;
        final publicUrl =
            _client.storage.from('feed-media').getPublicUrl(path);
        final media = FeedMedia.fromRow(r, publicUrl: publicUrl);
        byId.putIfAbsent(media.postId, () => <FeedMedia>[]).add(media);
      }
      return byId;
    } catch (_) {
      return const <String, List<FeedMedia>>{};
    }
  }

  /// Mevcut kullanıcının beğendiği post id'lerini set olarak çeker.
  Future<Set<String>> _fetchLikedSet(List<String> postIds) async {
    final userId = _currentUserId;
    if (userId == null || postIds.isEmpty) return <String>{};
    final rows = await _client
        .from('feed_likes')
        .select('post_id')
        .eq('owner_id', userId)
        .inFilter('post_id', postIds);
    return (rows as List)
        .map((e) => (e as Map<String, dynamic>)['post_id'] as String)
        .toSet();
  }

  /// Mevcut kullanıcının kaydettiği post id'lerini set olarak çeker.
  Future<Set<String>> _fetchSavedSet(List<String> postIds) async {
    final userId = _currentUserId;
    if (userId == null || postIds.isEmpty) return <String>{};
    final rows = await _client
        .from('feed_saves')
        .select('post_id')
        .eq('owner_id', userId)
        .inFilter('post_id', postIds);
    return (rows as List)
        .map((e) => (e as Map<String, dynamic>)['post_id'] as String)
        .toSet();
  }

  // ─────────────────────────────────────── Posts

  @override
  Future<List<FeedPost>> listPosts({PostType? type}) async {
    var q = _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('is_deleted', false);
    if (type != null) {
      q = q.eq('type', type.persistKey);
    }
    final rows = await q.order('created_at', ascending: false).limit(100);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final ids = list.map((r) => r['id'] as String).toList(growable: false);

    // Üç paralel sorgu: isLiked / isSaved set + post id → media list.
    final liked = await _fetchLikedSet(ids);
    final saved = await _fetchSavedSet(ids);
    final media = await _fetchMediaByPostIds(ids);

    return list
        .map((row) => _fromRow(
              row,
              likedPostIds: liked,
              savedPostIds: saved,
              mediaByPostId: media,
            ))
        .toList(growable: false);
  }

  @override
  Future<List<FeedPost>> listPostsByOwner(String ownerId) async {
    // V1 Social S1 — Public profile sayfası için.
    final rows = await _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('is_deleted', false)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .limit(100);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final ids = list.map((r) => r['id'] as String).toList(growable: false);
    final liked = await _fetchLikedSet(ids);
    final saved = await _fetchSavedSet(ids);
    final media = await _fetchMediaByPostIds(ids);
    return list
        .map((row) => _fromRow(
              row,
              likedPostIds: liked,
              savedPostIds: saved,
              mediaByPostId: media,
            ))
        .toList(growable: false);
  }

  @override
  Future<List<FeedPost>> listPostsByOwnerPage({
    required String ownerId,
    int offset = 0,
    int limit = 20,
  }) async {
    // M4 Polish — profile lazy paging. is_deleted=false + owner_id filter
    // korunur; range(offset, offset+limit-1) ile RPC-friendly sayfalama.
    final from = offset;
    final to = offset + limit - 1;
    final rows = await _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('is_deleted', false)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .range(from, to);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final ids = list.map((r) => r['id'] as String).toList(growable: false);
    final liked = await _fetchLikedSet(ids);
    final saved = await _fetchSavedSet(ids);
    final media = await _fetchMediaByPostIds(ids);
    return list
        .map((row) => _fromRow(
              row,
              likedPostIds: liked,
              savedPostIds: saved,
              mediaByPostId: media,
            ))
        .toList(growable: false);
  }

  @override
  Future<List<FeedPost>> listPostsPage({
    int offset = 0,
    int limit = 20,
    PostType? type,
  }) async {
    // V2 Social Core — donor `posts_repository.getPage` paged akışı.
    // is_deleted=false korunur; range(offset, offset+limit-1) inclusive.
    var q = _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('is_deleted', false);
    if (type != null) {
      q = q.eq('type', type.persistKey);
    }
    final rows = await q
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final ids = list.map((r) => r['id'] as String).toList(growable: false);
    final liked = await _fetchLikedSet(ids);
    final saved = await _fetchSavedSet(ids);
    final media = await _fetchMediaByPostIds(ids);
    return list
        .map((row) => _fromRow(
              row,
              likedPostIds: liked,
              savedPostIds: saved,
              mediaByPostId: media,
            ))
        .toList(growable: false);
  }

  @override
  Future<List<FeedPost>> listPostsPageForFollowing({
    required Set<String> followingIds,
    int offset = 0,
    int limit = 20,
  }) async {
    // Social UI Polish Sprint 2A — Takip Edilenler segmenti.
    // Server-side `.in_('owner_id', ids)` filter; pagination doğru
    // çalışır. Migration / RPC YOK; mevcut RLS (to authenticated select)
    // any-author postu görmeye izin verir.
    if (followingIds.isEmpty) return const <FeedPost>[];
    final rows = await _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('is_deleted', false)
        .inFilter('owner_id', followingIds.toList(growable: false))
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final ids = list.map((r) => r['id'] as String).toList(growable: false);
    final liked = await _fetchLikedSet(ids);
    final saved = await _fetchSavedSet(ids);
    final media = await _fetchMediaByPostIds(ids);
    return list
        .map((row) => _fromRow(
              row,
              likedPostIds: liked,
              savedPostIds: saved,
              mediaByPostId: media,
            ))
        .toList(growable: false);
  }

  @override
  Future<FeedPost> updatePost({
    required String postId,
    required String text,
    List<String>? tags,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    // V2 Social Core — donor `updatePost(caption)` muadili. Owner-only.
    // Soft-delete RLS RETURNING için SELECT policy zaten owner-self
    // soft-deleted satırı görür; UPDATE WITH CHECK owner_id=auth.uid()
    // burada da geçer. 0-row update silent-fail kapatılır: `.select`
    // boş dönerse StateError.
    final updateMap = <String, dynamic>{
      'text': text.trim(),
      if (tags != null) 'tags': tags,
    };
    final rows = await _client
        .from('feed_posts')
        .update(updateMap)
        .eq('id', postId)
        .eq('owner_id', userId)
        .select(_postColumns);
    if ((rows as List).isEmpty) {
      throw StateError(
        'Gönderi güncellenemedi: yetki yok veya kayıt bulunamadı.',
      );
    }
    final row = (rows.first as Map).cast<String, dynamic>();
    // Liked/saved set'leri tek post için ayrıca çekmeye gerek yok;
    // UI invalidate sonrası feed listesi tekrar dolar.
    _notify();
    return _fromRow(row, likedPostIds: <String>{}, savedPostIds: <String>{});
  }

  @override
  Future<FeedPost> addPost({
    required PostType type,
    required String author,
    required String role,
    required String text,
    List<String> tags = const <String>[],
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    final row = await _client
        .from('feed_posts')
        .insert(<String, dynamic>{
          'owner_id': userId,
          'type': type.persistKey,
          'text': text.trim(),
          'tags': tags,
          // author_name / author_role server-side trigger ile doldurulur.
        })
        .select(_postColumns)
        .single();
    _notify();
    return _fromRow(row, likedPostIds: <String>{}, savedPostIds: <String>{});
  }

  @override
  Future<FeedMedia> uploadFeedImage({
    required String postId,
    required Uint8List bytes,
    required String fileExtension,
    int? width,
    int? height,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    final ext = fileExtension.toLowerCase().replaceAll('.', '');
    // V1 P0 — RFC-4122 v4 UUID. Önceki implementasyon hex-timestamp tabanlı
    // bir string üretiyordu (örn. `0006522be759e1e9-0`); Postgres `uuid`
    // tipine cast'lenince `22P02 invalid_text_representation` atıyor ve
    // feed_media INSERT sessizce fail oluyordu. Storage'a dosya yüklenmiş
    // ama DB satırı yok → orphan + UI'da resim yok.
    final mediaId = _generateUuidV4();
    final path = '$userId/$postId/$mediaId.$ext';
    final mime = _mimeForImageExt(ext);

    // 1) Storage upload — path prefix RLS policy `{userId}/...` ile uyumlu.
    await _client.storage.from('feed-media').uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(
            contentType: mime,
            upsert: false,
          ),
        );

    // 2) feed_media INSERT — RLS owner_id = auth.uid() + post owner cross-check.
    // INSERT fail olursa storage objesini geri al (orphan engelle).
    try {
      final row = await _client
          .from('feed_media')
          .insert(<String, dynamic>{
            'id': mediaId,
            'post_id': postId,
            'owner_id': userId,
            'media_type': 'image',
            'storage_path': path,
            if (width != null) 'width': width,
            if (height != null) 'height': height,
            'size_bytes': bytes.length,
          })
          .select(
            'id, post_id, owner_id, media_type, storage_path, '
            'width, height, size_bytes, created_at',
          )
          .single();
      final publicUrl =
          _client.storage.from('feed-media').getPublicUrl(path);
      _notify();
      return FeedMedia.fromRow(row, publicUrl: publicUrl);
    } catch (e) {
      // INSERT fail → storage cleanup (best-effort). Hata caller'a iletilir.
      try {
        await _client.storage.from('feed-media').remove(<String>[path]);
      } catch (_) {
        // Storage remove'u yakalamaya gerek yok — INSERT zaten ana hata.
      }
      rethrow;
    }
  }

  static String _mimeForImageExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  static String _mimeForVideoExt(String ext) {
    switch (ext) {
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }

  @override
  Future<FeedMedia> uploadFeedVideo({
    required String postId,
    required Uint8List bytes,
    required String fileExtension,
    int? width,
    int? height,
    int? durationMs,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    final ext = fileExtension.toLowerCase().replaceAll('.', '');
    final mediaId = _generateUuidV4();
    final path = '$userId/$postId/$mediaId.$ext';
    final mime = _mimeForVideoExt(ext);

    // 1) Storage upload — path prefix RLS owner_id=auth.uid().
    await _client.storage.from('feed-media').uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(
            contentType: mime,
            upsert: false,
          ),
        );

    // 2) feed_media INSERT — media_type='video' + size_bytes.
    // INSERT fail → storage rollback.
    try {
      final row = await _client
          .from('feed_media')
          .insert(<String, dynamic>{
            'id': mediaId,
            'post_id': postId,
            'owner_id': userId,
            'media_type': 'video',
            'storage_path': path,
            if (width != null) 'width': width,
            if (height != null) 'height': height,
            'size_bytes': bytes.length,
          })
          .select(
            'id, post_id, owner_id, media_type, storage_path, '
            'width, height, size_bytes, created_at',
          )
          .single();
      final publicUrl =
          _client.storage.from('feed-media').getPublicUrl(path);
      _notify();
      return FeedMedia.fromRow(row, publicUrl: publicUrl);
    } catch (e) {
      try {
        await _client.storage.from('feed-media').remove(<String>[path]);
      } catch (_) {}
      rethrow;
    }
  }

  /// RFC 4122 v4 UUID — `Random.secure()` + version/variant bit-set.
  /// Postgres `uuid` tipinin beklediği `8-4-4-4-12` hex formatı.
  static String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    // Version 4: bytes[6] üst 4 bit = 0100.
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    // Variant RFC 4122: bytes[8] üst 2 bit = 10.
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String h(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
  }

  @override
  Future<void> deletePost(String postId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    // V1 Feed F1 — Soft-delete. RLS UPDATE policy `owner_id = auth.uid()`;
    // defansif olarak client de `eq('owner_id', userId)` ekler. Yorum/like
    // satırları is_deleted=false select policy'si üzerinden zaten gizlenir
    // (post is_deleted=true olunca cascade'e gerek yok).
    //
    // V1 P0 Hardening — `update().eq().eq()` zinciri 0 row affect ettiğinde
    // exception fırlatmıyor → UI sahte başarı snackbar gösteriyor, DB
    // değişmiyor (kullanıcı raporu "post silme çalışmıyor"). `.select('id')`
    // ile dönen liste boşsa owner-mismatch / not-found / RLS reddi
    // durumunu üst katmana taşı; PostCard `catch (e)` dalı net hata
    // snackbar'ı gösterir.
    final rows = await _client
        .from('feed_posts')
        .update(<String, dynamic>{'is_deleted': true})
        .eq('id', postId)
        .eq('owner_id', userId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw StateError(
        'Gönderi silinemedi: yetki yok veya kayıt bulunamadı.',
      );
    }
    _notify();
  }

  @override
  Future<FeedPost> toggleLike(String postId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    // V1 Feed Core Transplant — idempotent toggle. SELECT→INSERT/DELETE
    // arasında race window var; çift tap aynı anda iki INSERT atarsa
    // ikincisi 23505 (unique_violation) alır. Eski kod bunu yutmuyordu;
    // şimdi yakalıyor → "zaten beğenildi" no-op olarak değerlendiriyor.
    final existing = await _client
        .from('feed_likes')
        .select('post_id')
        .eq('post_id', postId)
        .eq('owner_id', userId)
        .maybeSingle();

    try {
      if (existing == null) {
        await _client.from('feed_likes').insert(<String, dynamic>{
          'post_id': postId,
          'owner_id': userId,
        });
      } else {
        await _client
            .from('feed_likes')
            .delete()
            .eq('post_id', postId)
            .eq('owner_id', userId);
      }
    } on sb.PostgrestException catch (e) {
      // Race: çift tap ardı ardına INSERT → ikinci 23505. Idempotent yutma.
      if (e.code != '23505') rethrow;
    }
    _notify();

    // Güncel post satırını döndür (like_count trigger ile güncellendi).
    final row = await _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('id', postId)
        .single();
    final liked = await _fetchLikedSet(<String>[postId]);
    final saved = await _fetchSavedSet(<String>[postId]);
    return _fromRow(row, likedPostIds: liked, savedPostIds: saved);
  }

  @override
  Future<FeedPost> toggleSave(String postId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    final existing = await _client
        .from('feed_saves')
        .select('post_id')
        .eq('post_id', postId)
        .eq('owner_id', userId)
        .maybeSingle();

    try {
      if (existing == null) {
        await _client.from('feed_saves').insert(<String, dynamic>{
          'post_id': postId,
          'owner_id': userId,
        });
      } else {
        await _client
            .from('feed_saves')
            .delete()
            .eq('post_id', postId)
            .eq('owner_id', userId);
      }
    } on sb.PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
    _notify();

    final row = await _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('id', postId)
        .single();
    final liked = await _fetchLikedSet(<String>[postId]);
    final saved = await _fetchSavedSet(<String>[postId]);
    return _fromRow(row, likedPostIds: liked, savedPostIds: saved);
  }

  @override
  Future<List<FeedInsight>> listInsights() async {
    // V1: Insight kartları statik kalır — gerçek metric backend'i ileride.
    // LocalFeedRepository ile aynı içerik (UX'in tutarlılığı için).
    return const <FeedInsight>[
      FeedInsight(
        kind: FeedInsightKind.trending,
        headline: 'Bugün ekşi maya konuşuluyor',
        body:
            'Ekşi Maya Atölyesi grubunda yaz mayası tartışması son 24 saatte '
            '37 yorum aldı. Konya / İstanbul ustaları aktif.',
      ),
      FeedInsight(
        kind: FeedInsightKind.topConversation,
        headline: 'Tip 550 yeni hasat',
        body:
            'Bu hafta en çok konuşulan: protein 13.2 / W 290 yeni hasat un. '
            '4 farklı değirmen, 12 farklı şehirden geri bildirim.',
      ),
      FeedInsight(
        kind: FeedInsightKind.newGroups,
        headline: '3 yeni bölgesel grup',
        body:
            'Son 7 günde Bursa, İzmir Karşıyaka ve Antep\'te yeni fırıncı '
            'grupları açıldı. Yakındaki ustaları takip et.',
      ),
    ];
  }

  // ─────────────────────────────────────── Comments (V1 P1-B)

  static const String _commentColumns =
      'id, post_id, owner_id, text, author_name, author_role, '
      'is_deleted, created_at';

  @override
  Future<List<FeedComment>> listComments(String postId) async {
    final rows = await _client
        .from('feed_comments')
        .select(_commentColumns)
        .eq('post_id', postId)
        .eq('is_deleted', false)
        .order('created_at', ascending: true)
        .limit(200);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FeedComment.fromRow)
        .toList(growable: false);
  }

  @override
  Future<FeedComment> addComment({
    required String postId,
    required String text,
    String? currentAuthorName,
    String? currentAuthorRole,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    final row = await _client
        .from('feed_comments')
        .insert(<String, dynamic>{
          'post_id': postId,
          'owner_id': userId,
          'text': text.trim(),
          // author_name / author_role → server-side snapshot trigger.
        })
        .select(_commentColumns)
        .single();
    _notify();
    return FeedComment.fromRow(row);
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    // Soft delete: is_deleted=true. comment_count trigger UPDATE branch
    // sayacı -1 yapar (yalnızca daha önce visible olan kayıtlar için).
    await _client
        .from('feed_comments')
        .update(<String, dynamic>{'is_deleted': true})
        .eq('id', commentId)
        .eq('owner_id', userId);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
