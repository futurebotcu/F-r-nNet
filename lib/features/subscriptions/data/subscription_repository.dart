import '../models/business_entitlements.dart';

/// Ticari işletme ücretlendirme durumuna soyut erişim.
///
/// Yalnız OKUMA + satır garantisi (ensure). Plan YAZMA client'ta yoktur —
/// server-side (service_role/backoffice). Bu PR'da satın alma/ödeme yok.
abstract class SubscriptionRepository {
  /// `my_entitlement()` RPC'sinin güvenli alanları.
  Future<BusinessEntitlements> myEntitlement();

  /// Çağıranın entitlement satırı yoksa oluşturur (ticari → 30 gün trial).
  /// İdempotent; panel girişinde güvenle çağrılır.
  Future<void> ensureMyEntitlement();

  /// Launch Premium promosunu server-side baslatir. Store/RevenueCat satin alma
  /// akisi baslatmaz; RPC idempotenttir.
  Future<BusinessEntitlements> activateLaunchPremiumPromo();

  /// Tedarikçi lansman kampanyası bilgilendirme pop-up'ı bu kullanıcı için
  /// daha önce gösterildi mi? Kalıcı kayıt server-side'dadır (cihaz
  /// değişiminde tekrar açılmaz).
  Future<bool> hasSeenSupplierLaunchNotice();

  /// Pop-up görüldü işaretini kalıcı yazar (idempotent). Satın alma/abonelik
  /// başlatmaz — yalnız bilgilendirme kaydıdır; kampanya hakkı bu kayda
  /// bağlı değildir (server uygun hesaplara doğrudan uygular).
  Future<void> markSupplierLaunchNoticeSeen();
}
