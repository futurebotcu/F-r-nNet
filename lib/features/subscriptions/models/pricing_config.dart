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
  static const int bakeryProMonthly = 299;
  static const int bakeryPremiumMonthly = 799;
  static const int supplierProMonthly = 999;
  static const int supplierPremiumMonthly = 2999;
  static const int paidListingFee = 50;

  // Biçimli etiketler ("2.999 TL / ay" → binlik ayracı nokta).
  static const String bakeryProLabel = '299 TL / ay';
  static const String bakeryPremiumLabel = '799 TL / ay';
  static const String supplierProLabel = '999 TL / ay';
  static const String supplierPremiumLabel = '2.999 TL / ay';
  static const String freeLabel = '0 TL';
  static const String paidListingLabel = '50 TL';

  /// Paywall/plan kartı fiyat ipuçları (ör. "Pro paket 299 TL/ay").
  static const String bakeryProHint = 'Pro paket 299 TL/ay';
  static const String bakeryPremiumHint = 'Premium paket 799 TL/ay';
  static const String supplierProHint = 'Pro paket 999 TL/ay';
  static const String supplierPremiumHint = 'Premium paket 2.999 TL/ay';

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
}
