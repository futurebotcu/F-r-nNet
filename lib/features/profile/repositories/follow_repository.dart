/// V1 Social S2 — Profil takip sistemi için soyut erişim.
///
/// Üç implementasyon:
///   * [SupabaseFollowRepository]: `profile_follows` tablosuna doğrudan.
///   * [LocalFollowRepository]: in-memory parite (test/local mode).
///   * [GuardedFollowRepository]: guest write guard dekoratörü.
///
/// Self-follow yapısal olarak engelli (DB CHECK + client erken-reddetme).
abstract class FollowRepository {
  /// `userId`'yi takip et (idempotent — zaten takipte ise no-op).
  Future<void> followProfile(String userId);

  /// `userId` takibini geri çek (yoksa no-op).
  Future<void> unfollowProfile(String userId);

  /// Toggle helper — takipteyse unfollow, değilse follow. Sonuçtaki son
  /// durumu (`isFollowing` true/false) döner.
  Future<bool> toggleFollow(String userId);

  /// Şu anki authenticated kullanıcı `userId`'yi takip ediyor mu?
  Future<bool> isFollowing(String userId);

  /// `(followers, following)` tuple. followers = `userId`'yi takip
  /// edenler; following = `userId`'nin takip ettikleri.
  Future<({int followers, int following})> getFollowCounts(String userId);

  /// V1 Social F2 — `userId`'yi takip eden user id'leri (most recent first).
  /// Followers list page için. RLS SELECT public; herkes okuyabilir.
  Future<List<String>> listFollowerIds(String userId);

  /// V1 Social F2 — `userId`'nin takip ettiği user id'leri.
  Future<List<String>> listFollowingIds(String userId);

  /// Repository değişikliklerinde tetiklenir (UI invalidation için).
  Stream<void> watch();
}
