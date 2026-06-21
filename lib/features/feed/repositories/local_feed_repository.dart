import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../models/feed_comment.dart';
import '../models/feed_insight.dart';
import '../models/feed_media.dart';
import '../models/feed_post.dart';
import '../models/post_type.dart';
import 'feed_repository.dart';

/// Bellek içi feed repository — demo seed ile gelir, uygulama yeniden
/// açıldığında veriler sıfırlanır.
class LocalFeedRepository implements FeedRepository {
  LocalFeedRepository({
    bool seed = true,
    String currentUserId = 'me_misafir',
    String currentUserName = 'Misafir',
  }) : _meId = currentUserId,
       _meName = currentUserName {
    if (seed) _seed();
  }

  // ignore: unused_field
  final String _meId;
  // ignore: unused_field
  final String _meName;

  final List<FeedPost> _posts = <FeedPost>[];
  // V1 P1-B — Local fallback için in-memory yorumlar (post_id -> liste).
  final Map<String, List<FeedComment>> _comments =
      <String, List<FeedComment>>{};

  final StreamController<void> _changes = StreamController<void>.broadcast();
  void _notify() => _changes.add(null);

  @override
  Future<List<FeedPost>> listPosts({PostType? type}) async {
    final src = type == null
        ? List<FeedPost>.from(_posts)
        : _posts.where((p) => p.type == type).toList();
    src.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(src);
  }

  @override
  Future<List<FeedPost>> listPostsPage({
    int offset = 0,
    int limit = 20,
    PostType? type,
  }) async {
    final src = type == null
        ? List<FeedPost>.from(_posts)
        : _posts.where((p) => p.type == type).toList();
    src.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (offset >= src.length) return const <FeedPost>[];
    final end = (offset + limit).clamp(0, src.length);
    return List.unmodifiable(src.sublist(offset, end));
  }

  @override
  Future<List<FeedPost>> listPostsByOwner(String ownerId) async {
    final src = _posts.where((p) => p.ownerId == ownerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(src);
  }

  @override
  Future<List<FeedPost>> listPostsByOwnerPage({
    required String ownerId,
    int offset = 0,
    int limit = 20,
  }) async {
    final src = _posts.where((p) => p.ownerId == ownerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (offset >= src.length) return const <FeedPost>[];
    final end = (offset + limit).clamp(0, src.length);
    return List.unmodifiable(src.sublist(offset, end));
  }

  @override
  Future<List<FeedPost>> listPostsPageForFollowing({
    required Set<String> followingIds,
    int offset = 0,
    int limit = 20,
  }) async {
    if (followingIds.isEmpty) return const <FeedPost>[];
    final src = _posts.where((p) => followingIds.contains(p.ownerId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (offset >= src.length) return const <FeedPost>[];
    final end = (offset + limit).clamp(0, src.length);
    return List.unmodifiable(src.sublist(offset, end));
  }

  @override
  Future<FeedPost> addPost({
    required PostType type,
    required String author,
    required String role,
    required String text,
    List<String> tags = const <String>[],
  }) async {
    final now = DateTime.now();
    final post = FeedPost(
      id: 'fp_${now.microsecondsSinceEpoch}',
      ownerId: _meId,
      type: type,
      author: author,
      role: role,
      text: text.trim(),
      createdAt: now,
      tags: List.unmodifiable(tags),
      gradient: _gradientForSeed(now.microsecondsSinceEpoch.abs()),
    );
    _posts.insert(0, post);
    _notify();
    return post;
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
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i == -1) {
      throw StateError('Post not found: $postId');
    }
    final post = _posts[i];
    final now = DateTime.now();
    final mediaId = 'fm_v_${now.microsecondsSinceEpoch}';
    final ext = fileExtension.toLowerCase().replaceAll('.', '');
    final path = '${post.ownerId}/$postId/$mediaId.$ext';
    final media = FeedMedia(
      id: mediaId,
      postId: postId,
      ownerId: post.ownerId,
      mediaType: 'video',
      storagePath: path,
      publicUrl: 'local://$path',
      width: width,
      height: height,
      sizeBytes: bytes.length,
      createdAt: now,
    );
    final newList = <FeedMedia>[...post.mediaList, media];
    _posts[i] = post.copyWith(mediaList: newList);
    _notify();
    return media;
  }

  @override
  Future<FeedMedia> uploadFeedImage({
    required String postId,
    required Uint8List bytes,
    required String fileExtension,
    int? width,
    int? height,
  }) async {
    // Local impl: fake URL + in-memory append. Test/seed için yeterli.
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i == -1) {
      throw StateError('Post not found: $postId');
    }
    final post = _posts[i];
    final now = DateTime.now();
    final mediaId = 'fm_${now.microsecondsSinceEpoch}';
    final ext = fileExtension.toLowerCase().replaceAll('.', '');
    final path = '${post.ownerId}/$postId/$mediaId.$ext';
    final media = FeedMedia(
      id: mediaId,
      postId: postId,
      ownerId: post.ownerId,
      mediaType: 'image',
      storagePath: path,
      publicUrl: 'local://$path',
      width: width,
      height: height,
      sizeBytes: bytes.length,
      createdAt: now,
    );
    final newList = <FeedMedia>[...post.mediaList, media];
    _posts[i] = post.copyWith(mediaList: newList);
    _notify();
    return media;
  }

  @override
  Future<void> deletePost(String postId) async {
    // V1 Feed F1 — Local parity: owner soft-delete. Listede görünmesin diye
    // doğrudan kaldırıyoruz (Supabase'de is_deleted=true SELECT filtresiyle
    // benzer davranış).
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i == -1) return;
    if (_posts[i].ownerId != _meId) return; // owner-only no-op
    _posts.removeAt(i);
    _comments.remove(postId);
    _notify();
  }

  @override
  Future<FeedPost> updatePost({
    required String postId,
    required String text,
    List<String>? tags,
  }) async {
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i == -1) {
      throw StateError('Gönderi güncellenemedi: kayıt bulunamadı.');
    }
    final old = _posts[i];
    if (old.ownerId != _meId) {
      throw StateError('Gönderi güncellenemedi: yetki yok.');
    }
    final updated = FeedPost(
      id: old.id,
      ownerId: old.ownerId,
      type: old.type,
      author: old.author,
      role: old.role,
      text: text.trim(),
      createdAt: old.createdAt,
      tags: tags != null ? List.unmodifiable(tags) : old.tags,
      gradient: old.gradient,
      likeCount: old.likeCount,
      commentCount: old.commentCount,
      isLiked: old.isLiked,
      isSaved: old.isSaved,
      groupId: old.groupId,
      groupName: old.groupName,
      mediaList: old.mediaList,
    );
    _posts[i] = updated;
    _notify();
    return updated;
  }

  @override
  Future<FeedPost> toggleLike(String postId) async {
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i == -1) throw StateError('Post not found: $postId');
    final p = _posts[i];
    final updated = p.copyWith(
      isLiked: !p.isLiked,
      likeCount: p.isLiked ? p.likeCount - 1 : p.likeCount + 1,
    );
    _posts[i] = updated;
    _notify();
    return updated;
  }

  @override
  Future<FeedPost> toggleSave(String postId) async {
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i == -1) throw StateError('Post not found: $postId');
    final p = _posts[i];
    final updated = p.copyWith(isSaved: !p.isSaved);
    _posts[i] = updated;
    _notify();
    return updated;
  }

  @override
  Future<FeedPost> toggleRepost(String postId) async {
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i == -1) throw StateError('Post not found: $postId');
    final p = _posts[i];
    final updated = p.copyWith(
      isReposted: !p.isReposted,
      repostCount: p.isReposted ? p.repostCount - 1 : p.repostCount + 1,
    );
    _posts[i] = updated;
    _notify();
    return updated;
  }

  @override
  Future<List<FeedInsight>> listInsights() async {
    return const <FeedInsight>[];
  }

  // ─────────────────────────────────────── Comments (V1 P1-B)

  @override
  Future<List<FeedComment>> listComments(String postId) async {
    final list = _comments[postId] ?? const <FeedComment>[];
    final visible = list.where((c) => !c.isDeleted).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(visible);
  }

  @override
  Future<FeedComment> addComment({
    required String postId,
    required String text,
    String? currentAuthorName,
    String? currentAuthorRole,
  }) async {
    final now = DateTime.now();
    final comment = FeedComment(
      id: 'fc_${now.microsecondsSinceEpoch}',
      postId: postId,
      ownerId: _meId,
      text: text.trim(),
      authorName: (currentAuthorName?.trim().isNotEmpty == true)
          ? currentAuthorName!.trim()
          : _meName,
      authorRole: (currentAuthorRole?.trim().isNotEmpty == true)
          ? currentAuthorRole!.trim()
          : 'Üye',
      isDeleted: false,
      createdAt: now,
    );
    (_comments[postId] ??= <FeedComment>[]).add(comment);

    // commentCount sayacı local'de manuel artırılır (server-side trigger yok).
    final pi = _posts.indexWhere((p) => p.id == postId);
    if (pi >= 0) {
      _posts[pi] = _posts[pi].copyWith(
        commentCount: _posts[pi].commentCount + 1,
      );
    }
    _notify();
    return comment;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    for (final list in _comments.values) {
      final i = list.indexWhere((c) => c.id == commentId);
      if (i >= 0) {
        final old = list[i];
        if (old.isDeleted) return;
        list[i] = FeedComment(
          id: old.id,
          postId: old.postId,
          ownerId: old.ownerId,
          text: old.text,
          authorName: old.authorName,
          authorRole: old.authorRole,
          isDeleted: true,
          createdAt: old.createdAt,
        );
        // commentCount düşür.
        final pi = _posts.indexWhere((p) => p.id == old.postId);
        if (pi >= 0 && _posts[pi].commentCount > 0) {
          _posts[pi] = _posts[pi].copyWith(
            commentCount: _posts[pi].commentCount - 1,
          );
        }
        _notify();
        return;
      }
    }
  }

  @override
  Stream<void> watch() => _changes.stream;

  // Local'de storm yok; içerik tick'i yapısalla aynı stream (guest/demo).
  @override
  Stream<void> watchContent() => _changes.stream;

  @override
  void dispose() => _changes.close();

  // ─────────────────────────────────────── Seed

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

  List<Color> _gradientForSeed(int seed) =>
      _gradients[seed % _gradients.length];

  void _seed() {
    final now = DateTime.now();
    DateTime ago(Duration d) => now.subtract(d);

    _posts.addAll([
      FeedPost(
        id: 'fp_seed_1',
        ownerId: 'seed_owner_1',
        type: PostType.production,
        author: 'Örnek · Hasan Kara',
        role: 'Usta Fırıncı · Konya',
        text:
            'Tam buğday simit denemeleri 90 dakika fermantasyonla çok daha güzel '
            'oturdu. Tahin akışkanlığı 70/30 dengeledim, susam tutuşu da yerinde. '
            'Ekşi mayalı versiyonunu hafta sonu paylaşırım.',
        createdAt: ago(const Duration(hours: 2)),
        tags: const ['ekşimaya', 'simit', 'taşfırın'],
        gradient: _gradients[0],
        likeCount: 2,
        commentCount: 1,
      ),
      FeedPost(
        id: 'fp_seed_2',
        ownerId: 'seed_owner_2',
        type: PostType.supply,
        author: 'Örnek · Konya Değirmen',
        role: 'Uncu · Toptan tedarik',
        text:
            'Yeni hasat ekstra unumuz analiz raporlarıyla birlikte çıktı. '
            'Protein 13.2, glüten W değeri 290 — uzun fermantasyon ve simit için '
            'ideal. Numune isteyen ustalara hafta sonu kargo başlıyor.',
        createdAt: ago(const Duration(hours: 5)),
        tags: const ['un', 'tip550', 'tedarik'],
        gradient: _gradients[1],
        likeCount: 1,
        commentCount: 0,
      ),
      FeedPost(
        id: 'fp_seed_3',
        ownerId: 'seed_owner_3',
        type: PostType.question,
        author: 'Örnek · Selin Ateş',
        role: 'Pastacı · İstanbul Kadıköy',
        text:
            'Tepsi börek için tahin–pekmez sosu dengesi nasıl ayarlanmalı? '
            'Müşteri yağsız hissetmesin ama pekmezin baskın olmasını da '
            'istemiyorum. Tarif paylaşan?',
        createdAt: ago(const Duration(hours: 8)),
        tags: const ['börek', 'tarif', 'tahin'],
        gradient: _gradients[2],
        likeCount: 2,
        commentCount: 1,
      ),
      FeedPost(
        id: 'fp_seed_4',
        ownerId: 'seed_owner_4',
        type: PostType.equipment,
        author: 'Örnek · Kara Endüstri',
        role: 'Ekipman · İstanbul Bayrampaşa',
        text:
            'Spiral mikser 80 L paslanmaz, 3 hız — 2022 model, az kullanılmış. '
            '54.000 ₺. İlgilenen ustalar Market\'ten ulaşabilir, garanti devri '
            'mümkün.',
        createdAt: ago(const Duration(hours: 14)),
        tags: const ['ekipman', 'mikser', 'ikinciel'],
        gradient: _gradients[3],
        likeCount: 1,
        commentCount: 0,
      ),
      FeedPost(
        id: 'fp_seed_5',
        ownerId: 'seed_owner_5',
        type: PostType.job,
        author: 'Örnek · Konak Fırını',
        role: 'Fırın · İstanbul Kadıköy',
        text:
            'Taş fırın ustası arıyoruz. 5+ yıl deneyim, gece vardiyası, '
            '38.000–45.000 ₺ + servis + yemek. CV ve referans ile başvuru.',
        createdAt: ago(const Duration(hours: 20)),
        tags: const ['usta', 'taşfırın', 'iş'],
        gradient: _gradients[4],
        likeCount: 0,
        commentCount: 0,
      ),
      FeedPost(
        id: 'fp_seed_6',
        ownerId: 'seed_owner_6',
        type: PostType.production,
        author: 'Örnek · Mehmet Taş Fırın',
        role: 'Fırın Sahibi · Gaziantep',
        text:
            'Gece üretiminde taş fırın 320° → 280° iniş eğrisini test ediyoruz. '
            'Trabzon ekmeği için 28 dakika, son 6 dakika buharsız bitiriyoruz. '
            'Kabuğun çıtırlığı tezgaha çıkarken bile sürüyor.',
        createdAt: ago(const Duration(days: 1)),
        tags: const ['taşfırın', 'geceüretimi', 'ekmek'],
        gradient: _gradients[5],
        likeCount: 3,
        commentCount: 1,
      ),
      // Seed'de 1 group highlight örneği — gerçek injection provider tarafında
      // popüler gruplardan dinamik üretilir.
      FeedPost(
        id: 'fp_seed_g1',
        ownerId: 'seed_owner_g1',
        type: PostType.groupHighlight,
        author: 'Örnek · Konya Değirmen',
        role: 'Uncu · Toptan',
        text:
            'Yeni hasat ekstra unu çıktı, 25 kg paket toplu alımda avantajlı. '
            'Protein 13.2, glüten W 290.',
        createdAt: ago(const Duration(hours: 3)),
        tags: const ['un', 'tip550'],
        gradient: _gradients[6],
        likeCount: 1,
        commentCount: 0,
        groupId: 'g_un_tip550',
        groupName: 'Un & Hammadde Pazarı',
      ),
    ]);
  }
}
