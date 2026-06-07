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
  expect(find.text(AppStrings.feedTitle), findsOneWidget);
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

    await _capture(tester, 'feed');

    await tester.tap(find.text('Gruplar'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.groupsTitle), findsOneWidget);
    await _capture(tester, 'groups');

    await tester.tap(find.text('Market'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.marketEmptyTitle), findsOneWidget);
    await _capture(tester, 'market_empty');

    await tester.tap(find.text('İlanlar'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.jobsTitle), findsOneWidget);
    expect(find.text(AppStrings.jobOfferEmptyGuest), findsOneWidget);
    await _capture(tester, 'jobs_empty');

    await tester.tap(find.text('Panel'));
    await tester.pumpAndSettle();
    expect(find.textContaining(AppStrings.panelGreetingPrefix), findsOneWidget);
    await _capture(tester, 'panel');
  });
}
