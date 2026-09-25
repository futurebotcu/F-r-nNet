import 'business_plan.dart';

/// Hedef kitle — fiyatlandırma ticari işletme (fırıncı) ile tedarikçi
/// (toptancı) arasında farklıdır.
enum PricingAudience { bakery, supplier }

/// Paket fiyatları — TEK KAYNAK (Lansman fiyatlandırması).
///
/// Yalnız FALLBACK görüntüleme metinleri; gerçek fiyat MAĞAZADAN gelir
/// (RevenueCat priceString) ve UI önce onu gösterir. Kuruş hassasiyeti için
/// tutarlar KURUŞ cinsindendir. Fiyatlar UI içinde dağınık hard-code
/// EDİLMEZ — buradan gelir.
class PricingConfig {
  const PricingConfig._();

  static const String currency = 'TL';

  // Tutarlar (KURUŞ). Lansman fiyatı: aylık 499,99 TL · yıllık 4.999,90 TL.
  static const int premiumMonthlyCents = 49999;
  static const int premiumYearlyCents = 499990;

  /// Yıllığın aylık x12 karşılığı (indirimsiz) ve "2 Ay Bizden" tasarrufu.
  static const int premiumYearlyRegularCents = 599988;
  static const int premiumYearlySavingsCents = 99998;
  static const int paidListingFeeCents = 5000;

  // Biçimli etiketler (fallback — mağaza fiyatı varsa o gösterilir).
  static const String premiumMonthlyLabel = '499,99 TL / ay';
  static const String premiumYearlyLabel = '4.999,90 TL / yıl';
  static const String premiumYearlySavingsLabel = '2 Ay Bizden';
  static const String freeLabel = '0 TL';
  static const String paidListingLabel = '50 TL';

  // Hesap-tipi alias'ları (tek Premium modeli — hepsi aynı etikete bağlı).
  static const String bakeryProLabel = premiumMonthlyLabel;
  static const String bakeryPremiumLabel = premiumMonthlyLabel;
  static const String supplierProLabel = premiumMonthlyLabel;
  static const String supplierPremiumLabel = premiumMonthlyLabel;

  /// Paywall/plan kartı fiyat ipuçları.
  static const String premiumMonthlyHint = 'Premium 499,99 TL/ay';
  static const String premiumYearlyHint = 'Premium 4.999,90 TL/yıl';
  static const String bakeryProHint = premiumMonthlyHint;
  static const String bakeryPremiumHint = premiumMonthlyHint;
  static const String supplierProHint = premiumMonthlyHint;
  static const String supplierPremiumHint = premiumMonthlyHint;

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
