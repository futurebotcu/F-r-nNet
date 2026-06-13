// Onboarding sayfa modeli — her sayfanın görsel "hero" türü + metni.
//
// Hero türü, sayfanın anlamına göre asset'siz premium bir illüstrasyon seçer
// (brand hariç — ilk sayfa gerçek marka ikonunu gösterir).

/// Intro sayfasının görsel kimliği.
enum OnboardingHeroKind {
  /// FırınNet marka ikonu (ilk sayfa).
  brand,

  /// Sosyal akış / paylaşım kartı.
  social,

  /// Pazar / teklif kartları.
  market,

  /// Bayi defteri / düzen kartı.
  ledger,
}

/// Tek bir onboarding sayfasının verisi (görsel + başlık + açıklama).
class OnboardingPageData {
  const OnboardingPageData({
    required this.kind,
    required this.title,
    required this.body,
  });

  final OnboardingHeroKind kind;
  final String title;
  final String body;
}
