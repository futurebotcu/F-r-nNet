/// Ticari işletme ücretlendirme planı.
///
/// persistKey değerleri DB `user_entitlements.plan` CHECK'iyle birebir aynıdır.
/// Trial aktifken sunucu effective plan olarak `premium` döndürür — bu enum
/// hem actual hem effective plan için kullanılır.
enum BusinessPlan { free, pro, premium }

extension BusinessPlanMeta on BusinessPlan {
  String get persistKey {
    switch (this) {
      case BusinessPlan.free:
        return 'free';
      case BusinessPlan.pro:
        return 'pro';
      case BusinessPlan.premium:
        return 'premium';
    }
  }

  String get label {
    switch (this) {
      case BusinessPlan.free:
        return 'Ücretsiz';
      case BusinessPlan.pro:
        return 'Pro';
      case BusinessPlan.premium:
        return 'Premium';
    }
  }

  static BusinessPlan fromKey(String? key) {
    switch (key) {
      case 'pro':
        return BusinessPlan.pro;
      case 'premium':
        return BusinessPlan.premium;
      default:
        return BusinessPlan.free;
    }
  }
}
