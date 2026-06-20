// UI Hizalama (Yol B+) — Bireysel şoför "Bayi Yönetimi" scoped modu.
//
// Bireysel şoför /dealers açınca ayrı "Şoför Paneli" değil, normal Bayi
// Yönetimi diliyle scoped mod görür: başlık "Bayi Yönetimi", alt nav
// Genel Bakış · Bayiler · Hareketler · Raporlar. Owner aksiyonu yok; veri
// yalnız atanmış bayiler/driver_id kapsamında.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/premium/premium_bottom_nav.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/driver_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<LocalDealerRepository> _seedAssignedDriver() async {
  final repo = LocalDealerRepository(seed: true, currentUserId: 'u1');
  await repo.addDriver(driverUserId: 'u1', name: 'Ali Şoför');
  final driverId = (await repo.listDrivers()).first.id;
  await repo.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);
  return repo;
}

Widget _wrap(LocalDealerRepository repo) => ProviderScope(
      overrides: [dealerRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: DriverHomeScreen()),
    );

Finder _navLabel(String label) => find.descendant(
      of: find.byType(PremiumBottomNav),
      matching: find.text(label),
    );

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  testWidgets('Başlık "Bayi Yönetimi" + "Şoför Paneli" yok + normal alt nav',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(await _seedAssignedDriver()));
    await tester.pumpAndSettle();

    // Ayrı "Şoför Paneli" değil; scoped Bayi Yönetimi.
    expect(find.text('Bayi Yönetimi'), findsOneWidget);
    expect(find.text('Şoför Paneli'), findsNothing);

    // Normal Bayi Yönetimi dili: alt PremiumBottomNav.
    expect(find.byType(PremiumBottomNav), findsOneWidget);
    expect(_navLabel(AppStrings.dealerShellTabOverview), findsOneWidget);
    expect(_navLabel(AppStrings.dealerShellTabDealers), findsOneWidget);
    expect(_navLabel(AppStrings.dealerShellTabActivity), findsOneWidget);
    expect(_navLabel(AppStrings.dealerShellTabReports), findsOneWidget);

    // Ayrılaştırıcı eski tab adları nav'da yok.
    expect(_navLabel('Atanan Bayiler'), findsNothing);
    expect(_navLabel('Hareketlerim'), findsNothing);
    expect(_navLabel('Raporlarım'), findsNothing);

    // Owner-only aksiyonlar bireyselde görünmez.
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    expect(find.text('Bayi ata / atamaları yönet'), findsNothing);
  });

  testWidgets('Veri driver assignment kapsamında (atanmış var, atanmamış yok)',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(await _seedAssignedDriver()));
    await tester.pumpAndSettle();

    // Genel Bakış kısa listesi: atanmış bayi var, atanmamış bayi yok.
    expect(find.text('Hamdi Bakkal'), findsAtLeastNWidgets(1));
    expect(find.text('Mehmet Market'), findsNothing);

    // Bayiler tab'ında da yalnız atanmış bayi.
    await tester.tap(_navLabel(AppStrings.dealerShellTabDealers));
    await tester.pumpAndSettle();
    expect(find.text('Hamdi Bakkal'), findsAtLeastNWidgets(1));
    expect(find.text('Mehmet Market'), findsNothing);
  });
}
