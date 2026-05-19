import 'dart:async';

import 'package:flutter/material.dart';

import '../models/feed_comment.dart';
import '../models/feed_insight.dart';
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
  })  : _meId = currentUserId,
        _meName = currentUserName {
    if (seed) _seed();
  }

  // ignore: unused_field
  final String _meId;
  // ignore: unused_field
  final String _meName;

  final List<FeedPost> _posts = <FeedPost>[];
  // V1 P1-B — Local fallback için in-memory yorumlar (post_id -> liste).
  final Map<String, List<FeedComment>> _comments = <String, List<FeedComment>>{};

  final StreamController<void> _changes =
      StreamController<void>.broadcast();
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
  Future<List<FeedPost>> listPostsByOwner(String ownerId) async {
    final src = _posts.where((p) => p.ownerId == ownerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(src);
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
  Future<List<FeedInsight>> listInsights() async {
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
      _posts[pi] = _posts[pi].copyWith(commentCount: _posts[pi].commentCount + 1);
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
          _posts[pi] = _posts[pi].copyWith(commentCount: _posts[pi].commentCount - 1);
        }
        _notify();
        return;
      }
    }
  }

  @override
  Stream<void> watch() => _changes.stream;

  // ─────────────────────────────────────── Seed

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
        author: 'Hasan Kara',
        role: 'Usta Fırıncı · Konya',
        text:
            'Tam buğday simit denemeleri 90 dakika fermantasyonla çok daha güzel '
            'oturdu. Tahin akışkanlığı 70/30 dengeledim, susam tutuşu da yerinde. '
            'Ekşi mayalı versiyonunu hafta sonu paylaşırım.',
        createdAt: ago(const Duration(hours: 2)),
        tags: const ['ekşimaya', 'simit', 'taşfırın'],
        gradient: _gradients[0],
        likeCount: 142,
        commentCount: 23,
      ),
      FeedPost(
        id: 'fp_seed_2',
        ownerId: 'seed_owner_2',
        type: PostType.supply,
        author: 'Konya Değirmen',
        role: 'Uncu · Toptan tedarik',
        text:
            'Yeni hasat ekstra unumuz analiz raporlarıyla birlikte çıktı. '
            'Protein 13.2, glüten W değeri 290 — uzun fermantasyon ve simit için '
            'ideal. Numune isteyen ustalara hafta sonu kargo başlıyor.',
        createdAt: ago(const Duration(hours: 5)),
        tags: const ['un', 'tip550', 'tedarik'],
        gradient: _gradients[1],
        likeCount: 89,
        commentCount: 12,
      ),
      FeedPost(
        id: 'fp_seed_3',
        ownerId: 'seed_owner_3',
        type: PostType.question,
        author: 'Selin Ateş',
        role: 'Pastacı · İstanbul Kadıköy',
        text:
            'Tepsi börek için tahin–pekmez sosu dengesi nasıl ayarlanmalı? '
            'Müşteri yağsız hissetmesin ama pekmezin baskın olmasını da '
            'istemiyorum. Tarif paylaşan?',
        createdAt: ago(const Duration(hours: 8)),
        tags: const ['börek', 'tarif', 'tahin'],
        gradient: _gradients[2],
        likeCount: 64,
        commentCount: 18,
      ),
      FeedPost(
        id: 'fp_seed_4',
        ownerId: 'seed_owner_4',
        type: PostType.equipment,
        author: 'Kara Endüstri',
        role: 'Ekipman · İstanbul Bayrampaşa',
        text:
            'Spiral mikser 80 L paslanmaz, 3 hız — 2022 model, az kullanılmış. '
            '54.000 ₺. İlgilenen ustalar Market\'ten ulaşabilir, garanti devri '
            'mümkün.',
        createdAt: ago(const Duration(hours: 14)),
        tags: const ['ekipman', 'mikser', 'ikinciel'],
        gradient: _gradients[3],
        likeCount: 47,
        commentCount: 9,
      ),
      FeedPost(
        id: 'fp_seed_5',
        ownerId: 'seed_owner_5',
        type: PostType.job,
        author: 'Konak Fırını',
        role: 'Fırın · İstanbul Kadıköy',
        text:
            'Taş fırın ustası arıyoruz. 5+ yıl deneyim, gece vardiyası, '
            '38.000–45.000 ₺ + servis + yemek. CV ve referans ile başvuru.',
        createdAt: ago(const Duration(hours: 20)),
        tags: const ['usta', 'taşfırın', 'iş'],
        gradient: _gradients[4],
        likeCount: 32,
        commentCount: 6,
      ),
      FeedPost(
        id: 'fp_seed_6',
        ownerId: 'seed_owner_6',
        type: PostType.production,
        author: 'Mehmet Taş Fırın',
        role: 'Fırın Sahibi · Gaziantep',
        text:
            'Gece üretiminde taş fırın 320° → 280° iniş eğrisini test ediyoruz. '
            'Trabzon ekmeği için 28 dakika, son 6 dakika buharsız bitiriyoruz. '
            'Kabuğun çıtırlığı tezgaha çıkarken bile sürüyor.',
        createdAt: ago(const Duration(days: 1)),
        tags: const ['taşfırın', 'geceüretimi', 'ekmek'],
        gradient: _gradients[5],
        likeCount: 304,
        commentCount: 56,
      ),
      // Seed'de 1 group highlight örneği — gerçek injection provider tarafında
      // popüler gruplardan dinamik üretilir.
      FeedPost(
        id: 'fp_seed_g1',
        ownerId: 'seed_owner_g1',
        type: PostType.groupHighlight,
        author: 'Konya Değirmen',
        role: 'Uncu · Toptan',
        text:
            'Yeni hasat ekstra unu çıktı, 25 kg paket toplu alımda avantajlı. '
            'Protein 13.2, glüten W 290.',
        createdAt: ago(const Duration(hours: 3)),
        tags: const ['un', 'tip550'],
        gradient: _gradients[6],
        likeCount: 21,
        commentCount: 5,
        groupId: 'g_un_tip550',
        groupName: 'Un & Hammadde Pazarı',
      ),
    ]);
  }
}
