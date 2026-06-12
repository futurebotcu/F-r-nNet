import 'package:shared_preferences/shared_preferences.dart';

/// Faz 2 UI Pass 3 — 3 sayfalık intro onboarding "görüldü" bayrağı.
///
/// İlk açılışta (oturum yok + guest değil + bayrak yok) intro gösterilir;
/// "Başla" veya "Atla" ile bayrak set edilir ve bir daha gösterilmez.
/// [GuestModeStorage] ile aynı dayanıklı desen (best-effort, test-injectable).
class OnboardingSeenStorage {
  OnboardingSeenStorage._();
  static final OnboardingSeenStorage instance = OnboardingSeenStorage._();

  static const String _key = 'firinnet.onboarding_seen';

  Future<SharedPreferences>? _futurePrefs;

  Future<SharedPreferences> get _prefs =>
      _futurePrefs ??= SharedPreferences.getInstance();

  Future<bool> read() async {
    try {
      final p = await _prefs;
      return p.getBool(_key) ?? false;
    } catch (_) {
      // Storage hatası → "görüldü" varsay; intro takılıp kullanıcıyı
      // auth akışından ALIKOYMASIN (güvenli taraf = göstermemek).
      return true;
    }
  }

  Future<void> markSeen() async {
    try {
      final p = await _prefs;
      await p.setBool(_key, true);
    } catch (_) {
      // Best-effort; storage hatası kullanıcıyı engellemesin.
    }
  }

  /// Test ortamında SharedPreferences mock'unu enjekte etmek için.
  static void setBackendForTest(SharedPreferences fake) {
    instance._futurePrefs = Future<SharedPreferences>.value(fake);
  }

  /// Test ortamında singleton state'ini sıfırlar.
  static void resetForTest() {
    instance._futurePrefs = null;
  }
}
