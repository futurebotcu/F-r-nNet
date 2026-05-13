import '../models/feed_insight.dart';
import '../models/feed_post.dart';
import '../models/post_type.dart';

/// Feed için soyut erişim.
///
/// V1: [LocalFeedRepository] (in-memory) ile çalışır, demo seed barındırır.
/// V2: SupabaseFeedRepository — yalnızca aynı yüzeyi uyarlayacak,
///      UI ve servis katmanı değişmeyecek.
abstract class FeedRepository {
  /// Tüm postlar (newest first). Opsiyonel tip filtresi.
  Future<List<FeedPost>> listPosts({PostType? type});

  /// Yeni post ekle (composer'dan). Postu döner.
  Future<FeedPost> addPost({
    required PostType type,
    required String author,
    required String role,
    required String text,
    List<String> tags = const <String>[],
  });

  /// Like toggle: false → true (count+1), true → false (count-1).
  Future<FeedPost> toggleLike(String postId);

  /// Save (bookmark) toggle.
  Future<FeedPost> toggleSave(String postId);

  /// Insight kartları (sosyal büyüme rozetleri).
  Future<List<FeedInsight>> listInsights();

  /// Repository içeriği değiştiğinde yayın.
  Stream<void> watch();
}
