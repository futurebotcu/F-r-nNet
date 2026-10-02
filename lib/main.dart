import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/theme/app_colors.dart';
import 'core/config/config_error_app.dart';
import 'core/config/app_config.dart';
import 'core/services/crash_reporting_service.dart';
import 'features/notifications/push/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  // Release fail-fast: production config eksikse local/mock seed moda
  // SESSİZCE düşülmez; uygulama başlatılmaz, yapılandırma hatası gösterilir.
  final configError = AppConfig.releaseConfigError(isRelease: kReleaseMode);
  if (configError != null) {
    runApp(ConfigErrorApp(reason: configError));
    return;
  }

  if (AppConfig.supabaseEnabled) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  // Push (FCM) — guard'lı init; config eksik/başarısızsa app etkilenmez.
  // (Firebase.initializeApp burada yapılır; Crashlytics buna bağlı.)
  await PushNotificationService.initFirebase();

  // Crash reporting (Crashlytics) — Firebase hazırsa + release/profile'da aktif;
  // debug'da kapalı, Firebase yoksa no-op. PII/secret crash'e bağlanmaz.
  await CrashReportingService.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: FirinNetApp()));
}
