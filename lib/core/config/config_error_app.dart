import 'package:flutter/material.dart';

/// Release build production config'siz derlendiğinde gösterilen engelleyici
/// ekran. Mock/local moda geçilmez; [reason] yalnız eksik anahtar ADINI içerir
/// (değer/secret yazılmaz).
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Uygulama yapılandırması eksik',
                    key: ValueKey('config_error_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu sürüm hatalı derlenmiş ($reason). Lütfen uygulamayı '
                    'mağazadan güncelle.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
