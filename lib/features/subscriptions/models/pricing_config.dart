import 'business_plan.dart';

/// Hedef kitle — fiyatlandırma ticari işletme (fırıncı) ile tedarikçi
/// (toptancı) arasında farklıdır.
enum PricingAudience { bakery, supplier }

/// Paket fiyatları — TEK KAYNAK (Paket Fiyatları UI V1).
///
/// Yalnız görüntüleme metinleri; ödeme entegrasyonu YOK. Fiyatlar UI içinde
/// dağınık hard-code EDİLMEZ — buradan gelir.
class PricingConfig {
  const PricingConfig._();

  static const String currency = 'TL';

  // Aylık fiyatlar (TL).
  static const int bakeryProMonthly = premiumMonthly;
  static const int bakeryPremiumMonthly = premiumMonthly;
  static const int supplierProMonthly = premiumMonthly;
  static const int supplierPremiumMonthly = premiumMonthly;
  static const int paidListingFee = 50;
  static const int premiumMonthly = 499;
  static const int premiumYearly = 4990;
  static const int premiumYearlyRegular = 5988;
  static const int premiumYearlySavings = 998;

  // Biçimli etiketler ("2.999 TL / ay" → binlik ayracı nokta).
  static const String bakeryProLabel = premiumMonthlyLabel;
  static const String bakeryPremiumLabel = premiumMonthlyLabel;
  static const String supplierProLabel = premiumMonthlyLabel;
  static const String supplierPremiumLabel = premiumMonthlyLabel;
  static const String premiumMonthlyLabel = '499 TL / ay';
  static const String premiumYearlyLabel = '4.990 TL / yıl';
  static const String premiumYearlySavingsLabel = '2 Ay Bizden';
  static const String freeLabel = '0 TL';
  static const String paidListingLabel = '50 TL';

  /// Paywall/plan kartı fiyat ipuçları (ör. "Pro paket 299 TL/ay").
  static const String bakeryProHint = premiumMonthlyHint;
  static const String bakeryPremiumHint = premiumMonthlyHint;
  static const String supplierProHint = premiumMonthlyHint;
  static const String supplierPremiumHint = premiumMonthlyHint;
  static const String premiumMonthlyHint = 'Premium 499 TL/ay';
  static const String premiumYearlyHint = 'Premium 4.990 TL/yıl';

  /// [audience] + [plan] için aylık fiyat etiketi.
  static String monthlyLabel(PricingAudience audience, BusinessPlan plan) {
    switch (plan) {
      case BusinessPlan.free:
        return freeLabel;
      case BusinessPlan.pro:
        return audience == PricingAudience.supplier
            ? supplierProLabel
            : bakeryProLabel;
      case BusinessPlan.premium:
        return audience == PricingAudience.supplier
            ? supplierPremiumLabel
            : bakeryPremiumLabel;
    }
  }

  static String premiumLabel({required bool yearly}) =>
      yearly ? premiumYearlyLabel : premiumMonthlyLabel;
}
