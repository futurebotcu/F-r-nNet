import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_strings.dart';
import '../features/auth/models/auth_user.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/notifications/push/push_notification_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class FirinNetApp extends ConsumerStatefulWidget {
  const FirinNetApp({super.key});

  @override
  ConsumerState<FirinNetApp> createState() => _FirinNetAppState();
}

class _FirinNetAppState extends ConsumerState<FirinNetApp> {
  late final _router = createRouter();

  @override
  void initState() {
    super.initState();
    // ref.listen yalnız SONRAKİ değişimleri yakalar; zaten girişli oturum
    // (uygulama açılışında session restore) için mevcut kullanıcıyı da kaydet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(currentAuthUserProvider) != null) {
        PushNotificationService.registerForUser();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Push (FCM): login (oturum açılınca / app resume) → cihaz token'ını
    // Supabase'e kaydet. Çıkışta performSignOut zaten deactivate eder.
    ref.listen<AuthUser?>(currentAuthUserProvider, (prev, next) {
      if (next != null && prev?.id != next.id) {
        PushNotificationService.registerForUser();
      }
    });
    return MaterialApp.router(
      title: AppStrings.appName,
      // Tek tema modu: white-first + yellow accent social identity.
      // Sistem temasindan bagimsiz, tutarli aydinlik gorunum.
      theme: AppTheme.lightTheme(),
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
