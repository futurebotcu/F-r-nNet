import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
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
  // FN-AUDIT-008 — korumalı route'lar için root auth guard. Local mod
  // (supabaseEnabled=false) enforcement KAPALI (mock/demo/test bozulmaz);
  // aksi halde gerçek oturum (guest sayılmaz) şartı.
  late final _router = createRouter(
    isAuthed: () =>
        !AppConfig.supabaseEnabled ||
        ref.read(currentAuthUserProvider) != null,
  );

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
      // FN-AUDIT-008 — oturum değişince (login/logout) router guard'ı yeniden
      // değerlendir: çıkışta korumalı ekranda kalan kullanıcı /auth'a düşer.
      if (prev?.id != next?.id) {
        _router.refresh();
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
