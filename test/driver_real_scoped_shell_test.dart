// feat/driver-real-scoped-shell — bireysel şoför, normal Bayi Yönetimi
// shell'ini scoped modda reuse eder. Başlık "Bayi Yönetimi", alt nav normal,
// arama/filtre korunur, owner-only CTA'lar gizli, data atanmış-bayi/driver_id
// scope'unda.

import 'package:firin_defter/core/widgets/premium/premium_bottom_nav.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/driver_scoped_dealer_repository.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_shell_screen.dart';
import 'package:firin_defter/features/dealers/widgets/dealer_filter_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<DriverScopedDealerRepository> _seed() async {
  final local = LocalDealerRepository(seed: true, currentUserId: 'u1');
  await local.addDriver(driverUserId: 'u1', name: 'Ali Şoför');
  final driverId = (await local.listDrivers()).first.id;
  await local.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);
  // Bu şoförün kendi driver_id'li hareketi (Hareketler tab'ında görünmeli).
  await local.addDriverTransaction(
    dealerId: 'd_hamdi',
    type: DealerTransactionType.delivery,
    quantity: 5,
    unitPrice: 12,
  );
  return DriverScopedDealerRepository(inner: local);
}

Widget _wrap(DriverScopedDealerRepository repo) => ProviderScope(
      overrides: [
        dealerRepositoryProvider.overrideWithValue(repo),
        dealerShellModeProvider
            .overrideWithValue(DealerShellMode.driverScoped),
      ],
      child: const MaterialApp(home: DealerShellScreen()),
    );

Finder _navLabel(String label) => find.descendant(
      of: find.byType(PremiumBottomNav),
      matching: find.text(label),
    );

Future<void> _tapNav(WidgetTester tester, String label) async {
  await tester.tap(_navLabel(label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(await _seed()));
    await tester.pumpAndSettle();
  }

  testWidgets('Başlık Bayi Yönetimi + normal alt nav + Şoför Paneli yok',
      (tester) async {
    await pumpShell(tester);

    expect(find.text('Bayi Yönetimi'), findsOneWidget);
    expect(find.text('Şoför Paneli'), findsNothing);

    expect(find.byType(PremiumBottomNav), findsOneWidget);
    expect(_navLabel('Genel Bakış'), findsOneWidget);
    expect(_navLabel('Bayiler'), findsOneWidget);
    expect(_navLabel('Hareketler'), findsOneWidget);
    expect(_navLabel('Raporlar'), findsOneWidget);
    // Şoförler tabı driver shell'de yok.
    expect(_navLabel('Şoförler'), findsNothing);
  });

  testWidgets('Owner-only aksiyonlar driver modda görünmez', (tester) async {
    await pumpShell(tester);
    // Genel Bakış (default tab): Bayi Ekle owner CTA yok, Şoförler yok;
    // driver "İşlem Ekle" var.
    expect(find.byIcon(Icons.person_add_alt_1_rounded), findsNothing);
    expect(find.text('Şoförler'), findsNothing);
    expect(find.text('İşlem Ekle'), findsOneWidget);
  });

  testWidgets('Bayiler tab: arama + filtre + yalnız atanmış bayi',
      (tester) async {
    await pumpShell(tester);
    await _tapNav(tester, 'Bayiler');

    // Normal Bayiler ekranı dili: arama alanı + filtre chip korunur.
    expect(find.byType(TextField), findsWidgets);
    expect(find.byType(DealerFilterChip), findsWidgets);
    // Yalnız atanmış bayi.
    expect(find.text('Hamdi Bakkal'), findsOneWidget);
    expect(find.text('Mehmet Market'), findsNothing);
  });

  testWidgets('Hareketler tab: arama + tip filtre + yalnız driver_id',
      (tester) async {
    await pumpShell(tester);
    await _tapNav(tester, 'Hareketler');

    expect(find.byType(TextField), findsWidgets);
    expect(find.byType(DealerFilterChip), findsWidgets);
    // Bu şoförün d_hamdi hareketi görünür.
    expect(find.text('Hamdi Bakkal'), findsWidgets);
    // Mehmet'in seed (driver_id null) hareketleri driver_id filtresiyle gizli.
    expect(find.text('Mehmet Market'), findsNothing);
  });

  testWidgets('Raporlar tab: dönem chipleri var, Gün Sonu owner aksiyonu yok',
      (tester) async {
    await pumpShell(tester);
    await _tapNav(tester, 'Raporlar');

    expect(find.byType(DealerFilterChip), findsWidgets);
    expect(find.text('Gün Sonu'), findsNothing);
  });
}
