import '../../profile/models/bakery_profile.dart';
import '../../subscriptions/models/business_plan.dart';

/// Store ödeme akışı sonucu.
enum PaymentResult { success, cancelled, pending, unavailable, error }

class StorePrice {
  const StorePrice({required this.productId, required this.priceLabel});

  final String productId;
  final String priceLabel;
}

/// Store'dan dönen fiyatları istenen ürün id'lerine eşler. Google Play
/// identifier'ı 'id:basePlan' formatında gelebilir; her fiyat hem ham
/// identifier hem base ürün id anahtarıyla erişilebilir olur (UI base id ile
/// bakar). Aynı ürünün birden fazla base planı dönerse [preferred] seçimi
/// (örn. 'id:monthly') base id anahtarını belirler.
Map<String, StorePrice> mapStorePrices(
  List<String> requestedIds,
  List<StorePrice> storePrices, {
  String? Function(List<String> identifiers, String productId)? preferred,
}) {
  final identifiers = <String>[for (final p in storePrices) p.productId];
  final byIdentifier = <String, StorePrice>{
    for (final p in storePrices) p.productId: p,
  };
  final result = <String, StorePrice>{...byIdentifier};
  for (final requested in requestedIds) {
    final selected = preferred?.call(identifiers, requested) ??
        identifiers.firstWhere(
          (id) => id == requested || id.startsWith('$requested:'),
          orElse: () => '',
        );
    final price = byIdentifier[selected];
    if (price != null) {
      result[requested] = StorePrice(
        productId: requested,
        priceLabel: price.priceLabel,
      );
    }
  }
  return result;
}

/// Store ödeme servisine soyut erişim (RevenueCat orkestrasyonu).
///
/// Resmi ödeme modeli: App Store IAP + Play Billing. Havale/EFT/İyzico/Stripe
/// YOK. Anahtarlar yoksa [isAvailable] false → UI "hazırlanıyor" gösterir,
/// SAHTE purchase YAPILMAZ.
abstract class PaymentService {
  /// RevenueCat public key mevcut + init başarılı mı?
  bool get isAvailable;

  /// RevenueCat SDK'yı auth.uid (appUserID) ile başlatır. Anonymous purchase
  /// açılmaz; logout'ta logOut çağrılır.
  Future<void> initialize({required String? userId});

  /// Kullanıcı değişince (login/logout) appUserID senkronu.
  Future<void> setUser(String? userId);

  /// [account] için satın alınabilir planlar. Bireysel → boş.
  Future<List<BusinessPlan>> availablePlans(AccountType? account);

  /// Plan satın alma akışını başlatır.
  Future<PaymentResult> purchasePlan({
    required AccountType account,
    required BusinessPlan plan,
  });

  Future<PaymentResult> purchaseProduct({
    required String productId,
  });

  Future<Map<String, StorePrice>> fetchStorePrices(List<String> productIds);

  /// Önceki satın alımları geri yükler.
  Future<PaymentResult> restorePurchases();

  /// Purchase/restore sonrası backend'i RevenueCat ile senkronlar (edge).
  Future<void> syncEntitlements();

  /// Ücretli ilan (50 TL) için ödeme niyeti oluşturur + purchase akışı.
  /// listing_id sunucuda intent'e bağlanır; doğrulama edge'de yapılır.
  Future<PaymentResult> purchaseListingFee({
    required String listingKind,
    required String listingId,
  });
}
