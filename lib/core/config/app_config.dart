/// Build-time configuration.
///
/// Anahtarlar `--dart-define=SUPABASE_URL=…` / `--dart-define=SUPABASE_ANON_KEY=…`
/// ile geçirilir. Anahtar yoksa [supabaseEnabled] false döner ve uygulama
/// local/mock moduna düşer; crash etmez.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get supabaseEnabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Social login (Google / Apple) OAuth callback deep link.
  ///
  /// Supabase Auth `redirectTo` parametresine geçer. Provider sayfası
  /// (Google/Apple) tamamlandıktan sonra browser bu URL'e döner; Android
  /// `AndroidManifest.xml` intent-filter, iOS `Info.plist` CFBundleURLTypes
  /// bu scheme'i yakalar ve Supabase SDK session'ı oluşturur.
  ///
  /// Manuel setup gereksinimleri için bkz. GOOGLE_APPLE_AUTH_V1_REPORT.md.
  static const String authRedirectUrl = 'firinnet://auth-callback';

  // ── RevenueCat (Store Billing) public SDK anahtarları ──
  // Public SDK key oldukları için client'ta dart-define ile okunur. Anahtar
  // yoksa [storePaymentsEnabled] false → ödeme butonları "hazırlanıyor"
  // gösterir; SAHTE purchase YAPILMAZ. Webhook secret'ları server (edge) env.
  static const String revenueCatIosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: '',
  );
  static const String revenueCatAndroidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: '',
  );

  /// Store ödemeleri kullanılabilir mi? Supabase açık + en az bir platform
  /// RevenueCat public key mevcut. (Platform seçimi PaymentService'te.)
  static bool get storePaymentsEnabled =>
      supabaseEnabled &&
      (revenueCatIosApiKey.isNotEmpty || revenueCatAndroidApiKey.isNotEmpty);
}
