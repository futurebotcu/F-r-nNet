import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/feed_comment.dart';
import '../models/feed_insight.dart';
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
  }) {
    final id = row['id'] as String;
    final tagsRaw = row['tags'] as List?;
    return FeedPost(
      id: id,
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
    );
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

    // İki paralel set sorgusu (current user için isLiked/isSaved).
    final results = await Future.wait<Set<String>>(<Future<Set<String>>>[
      _fetchLikedSet(ids),
      _fetchSavedSet(ids),
    ]);
    final liked = results[0];
    final saved = results[1];

    return list
        .map((row) =>
            _fromRow(row, likedPostIds: liked, savedPostIds: saved))
        .toList(growable: false);
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
  Future<FeedPost> toggleLike(String postId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    // Mevcut like'ı kontrol et, varsa sil, yoksa ekle.
    final existing = await _client
        .from('feed_likes')
        .select('post_id')
        .eq('post_id', postId)
        .eq('owner_id', userId)
        .maybeSingle();

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
