/// Build-time configuration.
///
/// Anahtarlar `--dart-define=SUPABASE_URL=…` / `--dart-define=SUPABASE_ANON_KEY=…`
/// ile geçirilir. Anahtar yoksa [supabaseEnabled] false döner ve uygulama
/// local/mock moduna düşer; crash etmez.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static bool get supabaseEnabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
