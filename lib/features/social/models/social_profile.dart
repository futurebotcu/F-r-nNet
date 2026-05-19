/// FırınNet Social — Public profile snapshot.
///
/// Donor (itsezlife) `User` model'inden esinli. Yalnız public-safe alanlar
/// (id, displayName, professionBadge, city). Server tarafı
/// `public_profile_snapshot(uuid[])` RPC ile çekilir (RLS-safe; profiles
/// tablosu owner-only kalır).
///
/// İstatistikler ayrı provider'lar (post count + follow counts) ile
/// composite olarak hazırlanır.
class SocialProfile {
  const SocialProfile({
    required this.id,
    this.displayName,
    this.professionBadge,
    this.city,
  });

  final String id;
  final String? displayName;
  final String? professionBadge;
  final String? city;

  static const String fallbackName = 'FırınNet Kullanıcısı';

  String get displayNameOrFallback =>
      (displayName == null || displayName!.trim().isEmpty)
          ? fallbackName
          : displayName!;

  /// İlk harf — avatar placeholder için.
  String get initial {
    final n = displayNameOrFallback;
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }
}
