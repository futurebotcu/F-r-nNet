// Golden baseline'lar Windows'ta üretildi; font rasterization platforma
// bağlı olduğu için Linux CI'da piksel eşleşmesi beklenemez. CI 'golden'
// tag'ini hariç tutar (yerel doğrulamada koşmaya devam eder).
@Tags(['golden'])
library;

import 'package:firin_defter/app/app.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/services/guest_mode_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _viewport = Size(390, 844);
const _captureKey = Key('golden-app');

Future<void> _loadGoldenFont() async {
  final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
  final materialIcons = await rootBundle.load(
    'fonts/MaterialIcons-Regular.otf',
  );
  await Future.wait(<Future<void>>[
    (FontLoader('Inter')
          ..addFont(Future<ByteData>.value(regular))
          ..addFont(Future<ByteData>.value(bold)))
        .load(),
    (FontLoader('Ahem')
          ..addFont(Future<ByteData>.value(regular))
          ..addFont(Future<ByteData>.value(bold)))
        .load(),
    (FontLoader('Roboto')
          ..addFont(Future<ByteData>.value(regular))
          ..addFont(Future<ByteData>.value(bold)))
        .load(),
    (FontLoader(
      'MaterialIcons',
    )..addFont(Future<ByteData>.value(materialIcons))).load(),
  ]);
}

Future<void> _pumpGuestApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{
    'firinnet.guest_mode': true,
  });
  GuestModeStorage.resetForTest();

  tester.view.physicalSize = _viewport;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1;
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  tester.platformDispatcher.localesTestValue = const <Locale>[
    Locale('tr', 'TR'),
  ];

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.platformDispatcher.clearLocalesTestValue();
    GuestModeStorage.resetForTest();
  });

  await tester.pumpWidget(
    const ProviderScope(
      child: RepaintBoundary(key: _captureKey, child: FirinNetApp()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();
  // Navigation IA Sprint — boot Topluluk sekmesine düşer (Feed embedded).
  expect(find.text(AppStrings.communitySubtitle), findsOneWidget);
}

Future<void> _capture(WidgetTester tester, String name) async {
  await expectLater(
    find.byKey(_captureKey),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  setUpAll(_loadGoldenFont);

  testWidgets('main screen visual regression baselines', (tester) async {
    await _pumpGuestApp(tester);

    // Topluluk (Genel Akış) — boot ekranı.
    await _capture(tester, 'community_feed');

    // Topluluk > Gruplar segmenti (alt nav değil, sekme-içi segment).
    await tester.tap(find.text(AppStrings.communitySegGroups));
    await tester.pumpAndSettle();
    await _capture(tester, 'community_groups');

    // Pazar — B2B native modül. Misafir (profil yok) → alıcı görünümü:
    // Ürünler · Kampanyalar · Tedarikçiler · Tekliflerim. Rol toggle YOK.
    await tester.tap(find.text(AppStrings.navPazar));
    await tester.pumpAndSettle();
    expect(find.text('Tekliflerim'), findsOneWidget);
    await _capture(tester, 'pazar_b2b');

    // İlanlar — Eleman segmenti (varsayılan).
    await tester.tap(find.text(AppStrings.navListings));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.listingsSubtitle), findsOneWidget);
    await _capture(tester, 'listings');

    // Mesajlar — konuşma listesi.
    await tester.tap(find.text(AppStrings.navMessages));
    await tester.pumpAndSettle();
    await _capture(tester, 'messages');

    // Panel — işletme araçları.
    await tester.tap(find.text(AppStrings.navPanel));
    await tester.pumpAndSettle();
    expect(find.textContaining(AppStrings.panelGreetingPrefix), findsOneWidget);
    await _capture(tester, 'panel');
  });
}
