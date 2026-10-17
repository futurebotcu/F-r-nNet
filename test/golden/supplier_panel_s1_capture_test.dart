// Tedarikçi Paneli S1 — doğrulanabilir görsel çıktı.
//
// Panel (wholesaler) ekranını gerçek fontlarla render edip PNG olarak
// docs/audits/s1/ altına yazar. Golden karşılaştırması YAPMAZ (platforma
// bağlı rasterization); yalnız görsel kanıt üretir. CI 'golden' tag'ini hariç
// tutar; yerelde:  flutter test test/golden/supplier_panel_s1_capture_test.dart
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:firin_defter/app/theme/app_theme.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_store.dart';
import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/dashboard/screens/role_dashboard_screen.dart';
import 'package:firin_defter/features/messaging/providers/messaging_providers.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _captureKey = Key('s1-capture');
const _outDir = 'docs/audits/s1';

class _WholesalerProfile extends ProfileController {
  _WholesalerProfile(super.ref) {
    state = const BakeryProfile(
      displayName: 'Anadolu Un & Maya',
      accountType: AccountType.wholesaler,
      city: 'Konya',
      roleBadge: 'Toptancı',
      email: 't@t.com',
    );
  }
}

class _NoStoreRepo extends LocalB2bRepository {
  @override
  Future<B2bStore> myStore() async => const B2bStore(
        id: '',
        name: '',
        monogram: '?',
        tagline: '',
        description: '',
        categories: [],
        serviceRegions: [],
        productCount: 0,
        campaignCount: 0,
        isMine: true,
      );
}

Future<void> _loadFonts() async {
  final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
  final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
  for (final family in const ['Inter', 'Ahem', 'Roboto']) {
    await (FontLoader(family)
          ..addFont(Future<ByteData>.value(regular))
          ..addFont(Future<ByteData>.value(bold)))
        .load();
  }
  await (FontLoader('MaterialIcons')..addFont(Future<ByteData>.value(icons)))
      .load();
}

Future<void> _capture(
  WidgetTester tester, {
  required String name,
  required Size size,
  required double textScale,
  required BusinessPlan plan,
  bool noStore = false,
  DateTime? launchUntil,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileControllerProvider.overrideWith((ref) => _WholesalerProfile(ref)),
        totalUnreadMessagesProvider.overrideWith((ref) => 2),
        subscriptionRepositoryProvider.overrideWithValue(
          LocalSubscriptionRepository(
            plan: plan,
            supplierLaunchFreeUntil: launchUntil,
          ),
        ),
        b2bRepositoryProvider.overrideWithValue(
          noStore ? _NoStoreRepo() : LocalB2bRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const RepaintBoundary(
          key: _captureKey,
          child: RoleDashboardScreen(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();

  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await _loadFonts();
  });

  testWidgets('S1 panel — mağaza var, Premium (lansman), 390x844',
      (tester) async {
    await _capture(
      tester,
      name: 'panel_wholesaler_store_390x844',
      size: const Size(390, 844),
      textScale: 1.0,
      plan: BusinessPlan.premium,
      launchUntil: DateTime(2027, 10, 1),
    );
  });

  testWidgets('S1 panel — tam sayfa (uzun), Free plan', (tester) async {
    await _capture(
      tester,
      name: 'panel_wholesaler_store_full_free',
      size: const Size(390, 1500),
      textScale: 1.0,
      plan: BusinessPlan.free,
    );
  });

  testWidgets('S1 panel — mağaza yok (ilk giriş)', (tester) async {
    await _capture(
      tester,
      name: 'panel_wholesaler_no_store',
      size: const Size(390, 1500),
      textScale: 1.0,
      plan: BusinessPlan.free,
      noStore: true,
    );
  });

  testWidgets('S1 panel — 320px dar ekran, 1.3x yazı', (tester) async {
    await _capture(
      tester,
      name: 'panel_wholesaler_320_x1_3',
      size: const Size(320, 1700),
      textScale: 1.3,
      plan: BusinessPlan.premium,
    );
  });
}
