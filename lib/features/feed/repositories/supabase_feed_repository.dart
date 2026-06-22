import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../app/theme/app_colors.dart';
import '../../../core/services/media_limits.dart';
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
  // Yapısal tick: post oluştur/sil/düzenle/medya → liste kompozisyonu değişir.
  final StreamController<void> _changes = StreamController<void>.broadcast();
  // İçerik tick'i: like/save/yorum → post SAYAÇLARI değişir, liste
  // kompozisyonu DEĞİL. Beğeni/yorum artık tüm paged feed'i yeniden çekmez
  // (kart optimistik override + dar sayaç güncellemesi yeterli).
  final StreamController<void> _contentChanges =
      StreamController<void>.broadcast();

  void _notify() => _changes.add(null);
  void _notifyContent() => _contentChanges.add(null);

  String? get _currentUserId => _client.auth.currentUser?.id;

  static const String _postColumns =
      'id, owner_id, type, text, tags, group_id, group_name, '
      'author_name, author_role, like_count, comment_count, repost_count, '
      'created_at';

  // ─────────────────────────────────────── Mapping

  /// post id seed → 8 farklı sıcak tonlu gradient.
  /// LocalFeedRepository ile aynı palet (görsel tutarlılık).
  static const List<List<Color>> _gradients = <List<Color>>[
    [AppColors.surfaceVariant, AppColors.background],
    [AppColors.background, AppColors.surfaceVariant],
    [AppColors.surfaceVariant, AppColors.surface],
    [AppColors.surface, AppColors.surfaceVariant],
    [AppColors.elevatedCard, AppColors.background],
    [AppColors.background, AppColors.elevatedCard],
    [AppColors.surfaceVariant, AppColors.elevatedCard],
    [AppColors.elevatedCard, AppColors.surface],
  ];

  static List<Color> _gradientForId(String id) {
    final h = id.hashCode.abs();
    return _gradients[h % _gradients.length];
  }

  FeedPost _fromRow(
    Map<String, dynamic> row, {
    required Set<String> likedPostIds,
    required Set<String> savedPostIds,
    Set<String> repostedPostIds = const <String>{},
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
      repostCount: ((row['repost_count'] as num?) ?? 0).toInt(),
      isLiked: likedPostIds.contains(id),
      isSaved: savedPostIds.contains(id),
      isReposted: repostedPostIds.contains(id),
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
          .select(
            'id, post_id, owner_id, media_type, storage_path, '
            'width, height, size_bytes, created_at',
          )
          .inFilter('post_id', postIds)
          .eq('is_deleted', false)
          .order('created_at', ascending: true);
      final byId = <String, List<FeedMedia>>{};
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final path = r['storage_path'] as String;
        final publicUrl = _client.storage.from('feed-media').getPublicUrl(path);
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

  /// Mevcut kullanıcının repost ettiği post id'lerini set olarak çeker.
  Future<Set<String>> _fetchRepostedSet(List<String> postIds) async {
    final userId = _currentUserId;
    if (userId == null || postIds.isEmpty) return <String>{};
    final rows = await _client
        .from('feed_reposts')
        .select('post_id')
        .eq('owner_id', userId)
        .inFilter('post_id', postIds);
    return (rows as List)
        .map((e) => (e as Map<String, dynamic>)['post_id'] as String)
        .toSet();
  }

  /// Post satırlarını FeedPost'a map'ler (liked/saved/reposted set + media tek
  /// seferde çekilir). Listeleme metotlarındaki tekrar eden bloğun ortağı.
  Future<List<FeedPost>> _mapRows(List<Map<String, dynamic>> list) async {
    if (list.isEmpty) return const <FeedPost>[];
    final ids = list.map((r) => r['id'] as String).toList(growable: false);
    final liked = await _fetchLikedSet(ids);
    final saved = await _fetchSavedSet(ids);
    final reposted = await _fetchRepostedSet(ids);
    final media = await _fetchMediaByPostIds(ids);
    return list
        .map(
          (row) => _fromRow(
            row,
            likedPostIds: liked,
            savedPostIds: saved,
            repostedPostIds: reposted,
            mediaByPostId: media,
          ),
        )
        .toList(growable: false);
  }

  /// Repost surfacing — [reposterOwnerIds] kullanıcılarının en yeni [limit]
  /// repost'unu, orijinal post içeriği + "X yeniden paylaştı" attribution ile
  /// feed girişi (isRepostEntry) olarak kurar. Reposter adı profiles own-only
  /// RLS nedeniyle `public_profile_snapshot` SECURITY DEFINER RPC'sinden gelir.
  /// Migration/DB/RLS değişikliği YOK — mevcut tablolar + RPC.
  Future<List<FeedPost>> _buildRepostEntries(
    Set<String> reposterOwnerIds, {
    required int limit,
  }) async {
    if (reposterOwnerIds.isEmpty || limit <= 0) return const <FeedPost>[];
    final repostRows = await _client
        .from('feed_reposts')
        .select('post_id, owner_id, created_at')
        .inFilter('owner_id', reposterOwnerIds.toList(growable: false))
        .order('created_at', ascending: false)
        .limit(limit);
    final reposts = (repostRows as List).cast<Map<String, dynamic>>();
    if (reposts.isEmpty) return const <FeedPost>[];

    final postIds =
        reposts.map((r) => r['post_id'] as String).toSet().toList();
    final ownerIds =
        reposts.map((r) => r['owner_id'] as String).toSet().toList();

    // Orijinal post içerikleri (silinmemiş).
    final postRows = await _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('is_deleted', false)
        .inFilter('id', postIds);
    final postById = <String, Map<String, dynamic>>{
      for (final r in (postRows as List).cast<Map<String, dynamic>>())
        r['id'] as String: r,
    };
    if (postById.isEmpty) return const <FeedPost>[];

    final visibleIds = postById.keys.toList(growable: false);
    final liked = await _fetchLikedSet(visibleIds);
    final saved = await _fetchSavedSet(visibleIds);
    final reposted = await _fetchRepostedSet(visibleIds);
    final media = await _fetchMediaByPostIds(visibleIds);

    // Reposter adları (batch RPC).
    final nameById = <String, String>{};
    try {
      final snap = await _client.rpc(
        'public_profile_snapshot',
        params: <String, dynamic>{'p_user_ids': ownerIds},
      );
      for (final r in (snap as List).cast<Map<String, dynamic>>()) {
        nameById[r['id'] as String] =
            (r['display_name'] as String?) ?? 'FırınNet Kullanıcısı';
      }
    } catch (_) {
      // İsim çözülemezse attribution sade fallback ile gösterilir.
    }

    final entries = <FeedPost>[];
    for (final r in reposts) {
      final postRow = postById[r['post_id'] as String];
      if (postRow == null) continue; // silinmiş/gizli post → atla
      final ownerId = r['owner_id'] as String;
      final original = _fromRow(
        postRow,
        likedPostIds: liked,
        savedPostIds: saved,
        repostedPostIds: reposted,
        mediaByPostId: media,
      );
      entries.add(
        FeedPost.repostEntry(
          original: original,
          repostedByProfileId: ownerId,
          repostedByName: nameById[ownerId] ?? 'FırınNet Kullanıcısı',
          repostedAt: DateTime.parse(r['created_at'] as String),
        ),
      );
    }
    return entries;
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
    final reposted = await _fetchRepostedSet(ids);
    final media = await _fetchMediaByPostIds(ids);

    return list
        .map(
          (row) => _fromRow(
            row,
            likedPostIds: liked,
            savedPostIds: saved,
            repostedPostIds: reposted,
            mediaByPostId: media,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<FeedPost>> listPostsByOwner(String ownerId) async {
    // V1 Social S1 — Public profile. Profilde kullanıcının repost'ları da
    // "X yeniden paylaştı" feed girişi olarak görünür (repost surfacing).
    final rows = await _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('is_deleted', false)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .limit(100);
    final postEntries =
        await _mapRows((rows as List).cast<Map<String, dynamic>>());
    final repostEntries =
        await _buildRepostEntries(<String>{ownerId}, limit: 100);
    return mergeFeedEntriesPage(
      postEntries: postEntries,
      repostEntries: repostEntries,
      offset: 0,
      limit: 100,
    );
  }

  @override
  Future<List<FeedPost>> listPostsByOwnerPage({
    required String ownerId,
    int offset = 0,
    int limit = 20,
  }) async {
    // M4 Polish — profile lazy paging + repost surfacing. Merge için en üst
    // (offset+limit) post çekilir, sahibin repost'larıyla birleştirilir.
    final end = offset + limit;
    final rows = await _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('is_deleted', false)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .range(0, end - 1);
    final postEntries =
        await _mapRows((rows as List).cast<Map<String, dynamic>>());
    final repostEntries =
        await _buildRepostEntries(<String>{ownerId}, limit: end);
    return mergeFeedEntriesPage(
      postEntries: postEntries,
      repostEntries: repostEntries,
      offset: offset,
      limit: limit,
    );
  }

  @override
  Future<List<FeedPost>> listPostsPage({
    int offset = 0,
    int limit = 20,
    PostType? type,
    Set<String> repostByOwnerIds = const <String>{},
  }) async {
    // V2 Social Core — paged akış. is_deleted=false korunur.
    // Repost surfacing: repostByOwnerIds dolu + tip filtresi yoksa, bu
    // kullanıcıların repost'ları ayrı feed girişi olarak birleştirilir.
    final merging = repostByOwnerIds.isNotEmpty && type == null;
    final end = offset + limit;
    var q = _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('is_deleted', false);
    if (type != null) {
      q = q.eq('type', type.persistKey);
    }
    // Merge için en üst (offset+limit) post; aksi halde yalnız sayfa dilimi.
    final rows = await q
        .order('created_at', ascending: false)
        .range(merging ? 0 : offset, end - 1);
    final postEntries =
        await _mapRows((rows as List).cast<Map<String, dynamic>>());
    if (!merging) return postEntries;
    final repostEntries =
        await _buildRepostEntries(repostByOwnerIds, limit: end);
    return mergeFeedEntriesPage(
      postEntries: postEntries,
      repostEntries: repostEntries,
      offset: offset,
      limit: limit,
    );
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
    // Repost surfacing: takip edilenlerin repost'ları da girişe katılır.
    final end = offset + limit;
    final rows = await _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('is_deleted', false)
        .inFilter('owner_id', followingIds.toList(growable: false))
        .order('created_at', ascending: false)
        .range(0, end - 1);
    final postEntries =
        await _mapRows((rows as List).cast<Map<String, dynamic>>());
    final repostEntries = await _buildRepostEntries(followingIds, limit: end);
    return mergeFeedEntriesPage(
      postEntries: postEntries,
      repostEntries: repostEntries,
      offset: offset,
      limit: limit,
    );
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
    MediaLimits.ensureImageUnderLimit(bytes.length);

    // 1) Storage upload — path prefix RLS policy `{userId}/...` ile uyumlu.
    await _client.storage
        .from('feed-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(contentType: mime, upsert: false),
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
      final publicUrl = _client.storage.from('feed-media').getPublicUrl(path);
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
    await _client.storage
        .from('feed-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(contentType: mime, upsert: false),
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
      final publicUrl = _client.storage.from('feed-media').getPublicUrl(path);
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
      throw StateError('Gönderi silinemedi: yetki yok veya kayıt bulunamadı.');
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
    _notifyContent();

    // Güncel post satırını döndür (like_count trigger ile güncellendi).
    final row = await _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('id', postId)
        .single();
    final liked = await _fetchLikedSet(<String>[postId]);
    final saved = await _fetchSavedSet(<String>[postId]);
    final reposted = await _fetchRepostedSet(<String>[postId]);
    return _fromRow(
      row,
      likedPostIds: liked,
      savedPostIds: saved,
      repostedPostIds: reposted,
    );
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
    _notifyContent();

    final row = await _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('id', postId)
        .single();
    final liked = await _fetchLikedSet(<String>[postId]);
    final saved = await _fetchSavedSet(<String>[postId]);
    final reposted = await _fetchRepostedSet(<String>[postId]);
    return _fromRow(
      row,
      likedPostIds: liked,
      savedPostIds: saved,
      repostedPostIds: reposted,
    );
  }

  @override
  Future<FeedPost> toggleRepost(String postId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    final existing = await _client
        .from('feed_reposts')
        .select('post_id')
        .eq('post_id', postId)
        .eq('owner_id', userId)
        .maybeSingle();

    try {
      if (existing == null) {
        await _client.from('feed_reposts').insert(<String, dynamic>{
          'post_id': postId,
          'owner_id': userId,
        });
      } else {
        await _client
            .from('feed_reposts')
            .delete()
            .eq('post_id', postId)
            .eq('owner_id', userId);
      }
    } on sb.PostgrestException catch (e) {
      // Race: çift tap → ikinci INSERT 23505. Idempotent yutma.
      if (e.code != '23505') rethrow;
    }
    // Repost surfacing: repost girişi akışa girer/çıkar → YAPISAL tick
    // (content tick paged feed'i tazelemez). Kart ikonu optimistik gösterilir.
    _notify();

    final row = await _client
        .from('feed_posts')
        .select(_postColumns)
        .eq('id', postId)
        .single();
    final liked = await _fetchLikedSet(<String>[postId]);
    final saved = await _fetchSavedSet(<String>[postId]);
    final reposted = await _fetchRepostedSet(<String>[postId]);
    return _fromRow(
      row,
      likedPostIds: liked,
      savedPostIds: saved,
      repostedPostIds: reposted,
    );
  }

  @override
  Future<List<FeedInsight>> listInsights() async {
    // Gerçek bir aggregate metric kaynağı bağlanana kadar aktivite iddiası
    // göstermeyiz.
    return const <FeedInsight>[];
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
    _notifyContent();
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
    _notifyContent();
  }

  @override
  Stream<void> watch() => _changes.stream;

  @override
  Stream<void> watchContent() => _contentChanges.stream;

  @override
  void dispose() {
    _changes.close();
    _contentChanges.close();
  }
}
