import 'package:shared_preferences/shared_preferences.dart';

/// Persistent guest mode flag (V1.3).
///
/// "Kayıtsız Devam Et" seçildiğinde true → app restart sonrası da
/// guest akışı korunur. Logout veya signIn ile temizlenir.
///
/// Android: SharedPreferences (`pm clear` ile silinir, beklenen davranış).
/// iOS: NSUserDefaults.
///
/// Test desteği: [setBackend] ile in-memory fake geçirilebilir.
class GuestModeStorage {
  GuestModeStorage._();
  static final GuestModeStorage instance = GuestModeStorage._();

  static const String _key = 'firinnet.guest_mode';

  /// `SharedPreferences` veya test sahtesi. Lazy init.
  Future<SharedPreferences>? _futurePrefs;

  Future<SharedPreferences> get _prefs =>
      _futurePrefs ??= SharedPreferences.getInstance();

  Future<bool> read() async {
    try {
      final p = await _prefs;
      return p.getBool(_key) ?? false;
    } catch (_) {
      // SharedPreferences hatası → guest false varsay (auth ekranına git).
      return false;
    }
  }

  Future<void> write(bool value) async {
    try {
      final p = await _prefs;
      if (value) {
        await p.setBool(_key, true);
      } else {
        await p.remove(_key);
      }
    } catch (_) {
      // Best-effort; storage hatası kullanıcıyı engellemesin.
    }
  }

  Future<void> clear() => write(false);

  /// Test ortamında SharedPreferences mock'unu enjekte etmek için.
  static void setBackendForTest(SharedPreferences fake) {
    instance._futurePrefs = Future<SharedPreferences>.value(fake);
  }

  /// Test ortamında singleton state'ini sıfırlar.
  static void resetForTest() {
    instance._futurePrefs = null;
  }
}
