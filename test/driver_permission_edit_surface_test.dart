// fix/dealer-driver-permission-edit-surface — patron mevcut şoför yetki
// segmenti DOĞRU ekranda (DriverScopedDealerShell → "Yönetim"). Ölü
// DriverDetailScreen yerine gerçek yüzeyde görünür + updateDriver çağırır.
// Ayrıca: tam yetkili şofor bile kendi shell'inde Şoförler tabını görmez.

import 'package:firin_defter/core/widgets/premium/premium_bottom_nav.dart';
import 'package:firin_defter/features/dealers/models/dealer_driver.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/driver_scoped_dealer_repository.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_shell_screen.dart';
import 'package:firin_defter/features/dealers/screens/driver_scoped_dealer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<({LocalDealerRepository repo, String driverId})> _seedPatron() async {
  final repo = LocalDealerRepository(seed: true, currentUserId: 'owner1');
  await repo.addDriver(driverUserId: 'u1', name: 'Fatih');
  final driverId = (await repo.listDrivers()).first.id;
  await repo.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);
  return (repo: repo, driverId: driverId);
}

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  testWidgets(
      'Yönetim: Yarı/Tam segment görünür, half seçili, değişim updateDriver',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final (:repo, :driverId) = await _seedPatron();
    await tester.pumpWidget(ProviderScope(
      overrides: [dealerRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: DriverScopedDealerShell(driverId: driverId)),
    ));
    await tester.pumpAndSettle();

    // "Yönetim" segmentine geç.
    await tester.tap(find.text('Yönetim'));
    await tester.pumpAndSettle();

    // Yetki segmenti görünür.
    expect(find.byType(SegmentedButton<DriverPermission>), findsOneWidget);
    expect(find.text('Yarı'), findsWidgets);
    expect(find.text('Tam'), findsWidgets);

    // Mevcut driver half → repo half.
    expect((await repo.getDriver(driverId))!.permissionLevel,
        DriverPermission.half);

    // Tam seç → updateDriver(full).
    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();
    expect((await repo.getDriver(driverId))!.permissionLevel,
        DriverPermission.full);

    // Yarı seç → updateDriver(half).
    await tester.tap(find.text('Yarı'));
    await tester.pumpAndSettle();
    expect((await repo.getDriver(driverId))!.permissionLevel,
        DriverPermission.half);
  });

  testWidgets('TAM yetkili şofor kendi shell\'inde Şoförler tabını görmez',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final inner = LocalDealerRepository(seed: true, currentUserId: 'u1');
    await inner.addDriver(
        driverUserId: 'u1',
        name: 'Fatih',
        permissionLevel: DriverPermission.full);
    final driverId = (await inner.listDrivers()).first.id;
    await inner.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);
    final scoped = DriverScopedDealerRepository(inner: inner);

    final router = GoRouter(
      initialLocation: '/dealers',
      routes: [
        GoRoute(path: '/dealers', builder: (_, __) => const DealerShellScreen()),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dealerRepositoryProvider.overrideWithValue(scoped),
        dealerShellModeProvider.overrideWithValue(DealerShellMode.driverScoped),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(PremiumBottomNav), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PremiumBottomNav),
        matching: find.text('Şoförler'),
      ),
      findsNothing,
    );
  });
}
