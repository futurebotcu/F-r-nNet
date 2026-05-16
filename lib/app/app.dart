import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/constants/app_strings.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class FirinNetApp extends StatefulWidget {
  const FirinNetApp({super.key});

  @override
  State<FirinNetApp> createState() => _FirinNetAppState();
}

class _FirinNetAppState extends State<FirinNetApp> {
  late final _router = createRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appName,
      // Tek tema modu — bakery operasyon paleti (açık cream zemin,
      // espresso kartlar, mat bakır). Hem light hem dark slot'unda
      // aynı tema; sistemin temasından bağımsız tutarlı görünüm.
      theme: AppTheme.darkTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
