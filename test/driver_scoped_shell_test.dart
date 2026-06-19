// Faz 1 — Şoför-scoped mini Bayi Yönetimi (DriverScopedDealerShell) widget testi.
//
// Patron şoföre dokununca scoped mini defter açılır: başlık = şoför adı, 5
// segment, Bayiler segmentinde yalnız atanmış bayi görünür.

import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/driver_scoped_dealer_shell.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

const _commercial = BakeryProfile(
  displayName: 'Patron', accountType: AccountType.commercial,
  city: 'Konya', roleBadge: 'Fırıncı', email: 'p@e.com',
);

void main() {
  testWidgets('Patron scoped shell: başlık + segmentler + atanan bayi',
      (tester) async {
    final repo = LocalDealerRepository(seed: true);
    // Şoför + d_hamdi ataması.
    await repo.addDriver(driverUserId: 'u1', name: 'Ali Şoför');
    final driverId = (await repo.listDrivers()).first.id;
    await repo.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);

    final router = GoRouter(
      initialLocation: '/s',
      routes: [
        GoRoute(
          path: '/s',
          builder: (_, __) => DriverScopedDealerShell(driverId: driverId),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        dealerRepositoryProvider.overrideWithValue(repo),
        profileControllerProvider
            .overrideWith((ref) => _SeededProfileController(ref, _commercial)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    // Başlık = şoför adı + alt metin.
    expect(find.text('Ali Şoför'), findsOneWidget);
    expect(find.text('Şoför Bayi Defteri'), findsOneWidget);
    // Segmentler.
    expect(find.text('Genel Bakış'), findsOneWidget);
    expect(find.text('Bayiler'), findsOneWidget);
    expect(find.text('Yönetim'), findsOneWidget);

    // Bayiler segmentine geç → yalnız atanmış bayi (Hamdi Bakkal) görünür.
    await tester.tap(find.text('Bayiler'));
    await tester.pumpAndSettle();
    expect(find.text('Hamdi Bakkal'), findsOneWidget);
    // Atanmamış bayi (Mehmet Market) scoped listede YOK.
    expect(find.text('Mehmet Market'), findsNothing);
  });
}
