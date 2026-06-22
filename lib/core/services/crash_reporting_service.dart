import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// FırınNet — Firebase Crashlytics crash reporting (PR-7B).
///
/// Tasarım:
/// - Firebase init SONRASI çağrılır; Firebase yoksa (CI/dosyasız/dev ortam)
///   GRACEFUL no-op (push notification ile aynı guard deseni).
/// - Toplama (collection) yalnız RELEASE/PROFILE'da AÇIK; DEBUG'da KAPALI
///   (geliştirme sırasında spam + gereksiz rapor olmasın).
/// - Framework (widget/build) hataları → `recordFlutterFatalError`.
/// - Async / platform dispatcher uncaught hataları → `recordError(fatal)`.
/// - **Gizlilik:** `setUserIdentifier` / PII'li custom key ÇAĞRILMAZ. Crashlytics
///   yalnız stack trace + cihaz tanılama (model/OS) toplar; kullanıcı kimliği
///   crash'e BAĞLANMAZ. Secret/PII crash payload'ına yazılmaz.
class CrashReportingService {
  const CrashReportingService._();

  static bool _enabled = false;

  /// Aktif (release/profile + Firebase hazır) ise true.
  static bool get isEnabled => _enabled;

  /// Firebase init edildikten SONRA çağrılır (main bootstrap).
  static Future<void> init() async {
    // Firebase yapılandırılmamışsa (google-services.json yok / init başarısız)
    // crash reporting devre dışı — uygulama akışı etkilenmez.
    if (Firebase.apps.isEmpty) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      // Debug'da toplama kapalı; release/profile'da açık.
      final collect = !kDebugMode;
      await crashlytics.setCrashlyticsCollectionEnabled(collect);
      _enabled = collect;

      // Framework hataları (widget/build/layout).
      FlutterError.onError = (FlutterErrorDetails details) {
        // Debug'da kırmızı hata ekranı / konsol; release'te sessiz.
        FlutterError.presentError(details);
        crashlytics.recordFlutterFatalError(details);
      };

      // Framework dışı async / platform uncaught hatalar.
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      // Crashlytics kurulumu başarısız olsa bile app çökmemeli.
      debugPrint('[FirinNet][Crash] init failed: $e');
    }
  }
}
