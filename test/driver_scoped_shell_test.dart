// UI Hizalama (Yol B+) — Şoför-scoped mini Bayi Yönetimi widget testi.
//
// Patron şoföre dokununca scoped mini defter açılır. Yeni yapı: üst mekanik
// segment YOK, normal Bayi Yönetimi gibi alt PremiumBottomNav (4 tab) + sağ
// üst owner menü. Bayiler tab'ında yalnız atanmış bayi görünür.

import 'package:firin_defter/core/widgets/premium/premium_bottom_nav.dart';
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

Future<String> _seedDriver(LocalDealerRepository repo) async {
  await repo.addDriver(driverUserId: 'u1', name: 'Ali Şoför');
  final driverId = (await repo.listDrivers()).first.id;
  await repo.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);
  return driverId;
}

Widget _wrap(LocalDealerRepository repo, String driverId) {
  final router = GoRouter(
    initialLocation: '/s',
    routes: [
      GoRoute(
        path: '/s',
        builder: (_, __) => DriverScopedDealerShell(driverId: driverId),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      dealerRepositoryProvider.overrideWithValue(repo),
      profileControllerProvider
          .overrideWith((ref) => _SeededProfileController(ref, _commercial)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('Scoped shell: bottom nav + üst mekanik segment yok + başlık',
      (tester) async {
    final repo = LocalDealerRepository(seed: true);
    final driverId = await _seedDriver(repo);

    await tester.pumpWidget(_wrap(repo, driverId));
    await tester.pumpAndSettle();

    // Başlık = şoför adı + alt metin.
    expect(find.text('Ali Şoför'), findsOneWidget);
    expect(find.text('Şoför Bayi Defteri'), findsOneWidget);

    // Normal Bayi Yönetimi dili: alt PremiumBottomNav var.
    expect(find.byType(PremiumBottomNav), findsOneWidget);

    // 4 tab; eski mekanik "Yönetim" segmenti YOK.
    expect(find.text('Genel Bakış'), findsOneWidget);
    expect(find.text('Bayiler'), findsOneWidget);
    expect(find.text('Hareketler'), findsOneWidget);
    expect(find.text('Raporlar'), findsOneWidget);
    expect(find.text('Yönetim'), findsNothing);
  });

  testWidgets('Scoped shell: owner menü aksiyonları patron tarafında var',
      (tester) async {
    final repo = LocalDealerRepository(seed: true);
    final driverId = await _seedDriver(repo);

    await tester.pumpWidget(_wrap(repo, driverId));
    await tester.pumpAndSettle();

    // Sağ üst owner menü.
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Bayi ata / atamaları yönet'), findsOneWidget);
    expect(find.text('Şoförü pasife al'), findsOneWidget);
    expect(find.text('Şoför bilgisi'), findsOneWidget);
  });

  testWidgets('Scoped Bayiler: yalnız atanmış bayi (assignment filtresi)',
      (tester) async {
    final repo = LocalDealerRepository(seed: true);
    final driverId = await _seedDriver(repo);

    await tester.pumpWidget(_wrap(repo, driverId));
    await tester.pumpAndSettle();

    // Bottom nav ile Bayiler tab'ına geç.
    await tester.tap(find.text('Bayiler'));
    await tester.pumpAndSettle();

    // Atanmış bayi görünür, atanmamış bayi scoped listede YOK.
    expect(find.text('Hamdi Bakkal'), findsOneWidget);
    expect(find.text('Mehmet Market'), findsNothing);
  });
}
