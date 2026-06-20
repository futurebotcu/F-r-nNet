// fix/driver-normal-dealer-shell — bireysel şoför, NORMAL Bayi Yönetimi
// shell'ini görür: aynı nav (Şoförler hariç), normal Bayiler ekranı, bayi
// kartına basınca NORMAL DealerDetailScreen (DriverDealerDetailScreen DEĞİL).

import 'package:firin_defter/core/widgets/premium/premium_bottom_nav.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/driver_scoped_dealer_repository.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_detail_screen.dart';
import 'package:firin_defter/features/dealers/screens/dealer_shell_screen.dart';
import 'package:firin_defter/features/dealers/screens/driver_dealer_detail_screen.dart';
import 'package:firin_defter/features/dealers/widgets/dealer_filter_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<DriverScopedDealerRepository> _seed() async {
  final inner = LocalDealerRepository(seed: true, currentUserId: 'u1');
  await inner.addDriver(driverUserId: 'u1', name: 'Ali Şoför');
  final driverId = (await inner.listDrivers()).first.id;
  await inner.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);
  return DriverScopedDealerRepository(inner: inner);
}

GoRouter _router() => GoRouter(
      initialLocation: '/dealers',
      routes: [
        GoRoute(
            path: '/dealers', builder: (_, __) => const DealerShellScreen()),
        GoRoute(
          path: '/dealers/:id',
          builder: (_, s) =>
              DealerDetailScreen(dealerId: s.pathParameters['id']!),
        ),
      ],
    );

Widget _wrap(DriverScopedDealerRepository repo) => ProviderScope(
      overrides: [
        dealerRepositoryProvider.overrideWithValue(repo),
        dealerShellModeProvider
            .overrideWithValue(DealerShellMode.driverScoped),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    );

Finder _navLabel(String l) => find.descendant(
    of: find.byType(PremiumBottomNav), matching: find.text(l));

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(await _seed()));
    await tester.pumpAndSettle();
  }

  testWidgets('Normal shell + nav var, Şoförler tabı yok', (tester) async {
    await pump(tester);
    expect(find.byType(PremiumBottomNav), findsOneWidget);
    expect(_navLabel('Genel Bakış'), findsOneWidget);
    expect(_navLabel('Bayiler'), findsOneWidget);
    expect(_navLabel('Hareketler'), findsOneWidget);
    expect(_navLabel('Raporlar'), findsOneWidget);
    expect(_navLabel('Şoförler'), findsNothing);
  });

  testWidgets('Bayiler: normal arama/filtre + yalnız atanmış bayi',
      (tester) async {
    await pump(tester);
    await tester.tap(_navLabel('Bayiler'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets); // arama
    expect(find.byType(DealerFilterChip), findsWidgets); // filtre chip
    expect(find.text('Hamdi Bakkal'), findsOneWidget); // atanmış
    expect(find.text('Mehmet Market'), findsNothing); // atanmamış yok
  });

  testWidgets('Bayi kartı → NORMAL DealerDetailScreen (driver detail DEĞİL)',
      (tester) async {
    await pump(tester);
    await tester.tap(_navLabel('Bayiler'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hamdi Bakkal'));
    await tester.pumpAndSettle();

    expect(find.byType(DealerDetailScreen), findsOneWidget);
    expect(find.byType(DriverDealerDetailScreen), findsNothing);
  });
}
