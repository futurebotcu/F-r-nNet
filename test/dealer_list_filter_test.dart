// Sprint 6B.x — DealerListScreen filter chip testleri.
//
// 4 chip: Tümü / Aktif / Pasif / Borçlu. "Borçlu" = aktif &&
// currentBalance > 0 (pasif borçlular bilinçli olarak hariç). Genel
// Bakış "Borçlu Bayiler" CTA `dealerShellPrefilterDebtOnlyProvider`'ı
// set ederse list one-shot debtOnly filtre'siyle açılır.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_list_screen.dart';
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

const _commercialProfile = BakeryProfile(
  displayName: 'Hasan Usta',
  accountType: AccountType.commercial,
  city: 'Konya',
  roleBadge: 'Fırıncı',
  email: 'hasan@example.com',
);

Future<LocalDealerRepository> _seededRepo() async {
  // 4 dealer: 2 aktif borçlu (Hamdi, Mehmet), 1 aktif kapalı (Köşe),
  // 1 pasif borçlu (Şenel — borç var ama isActive=false).
  final repo = LocalDealerRepository(seed: false);
  await repo.upsertDealer(Dealer(
    id: 'd-debt-active-1',
    name: 'Hamdi Bakkal',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd-debt-active-2',
    name: 'Mehmet Market',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd-closed-active',
    name: 'Köşe Pide',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd-debt-passive',
    name: 'Şenel Büfe',
    isActive: false,
    createdAt: DateTime(2026, 1, 1),
  ));
  // Hamdi 500 borçlu
  await repo.addTransaction(DealerTransaction(
    id: 't1',
    dealerId: 'd-debt-active-1',
    type: DealerTransactionType.delivery,
    amount: 500,
    createdAt: DateTime(2026, 5, 1),
  ));
  // Mehmet 300 borçlu
  await repo.addTransaction(DealerTransaction(
    id: 't2',
    dealerId: 'd-debt-active-2',
    type: DealerTransactionType.delivery,
    amount: 300,
    createdAt: DateTime(2026, 5, 1),
  ));
  // Köşe kapalı (delivery=100, payment=100)
  await repo.addTransaction(DealerTransaction(
    id: 't3-d',
    dealerId: 'd-closed-active',
    type: DealerTransactionType.delivery,
    amount: 100,
    createdAt: DateTime(2026, 5, 1),
  ));
  await repo.addTransaction(DealerTransaction(
    id: 't3-p',
    dealerId: 'd-closed-active',
    type: DealerTransactionType.payment,
    amount: 100,
    createdAt: DateTime(2026, 5, 2),
  ));
  // Şenel pasif ama borçlu (delivery=200)
  await repo.addTransaction(DealerTransaction(
    id: 't4',
    dealerId: 'd-debt-passive',
    type: DealerTransactionType.delivery,
    amount: 200,
    createdAt: DateTime(2026, 5, 1),
  ));
  return repo;
}

GoRouter _testRouter() => GoRouter(
      initialLocation: '/dealers',
      routes: [
        GoRoute(
          path: '/dealers',
          builder: (_, __) => const DealerListScreen(),
        ),
        GoRoute(
          path: '/wholesale/customers',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('w-stub'))),
        ),
      ],
    );

Widget _wrap(LocalDealerRepository repo, {ProviderContainer? container}) {
  final overrides = [
    dealerRepositoryProvider.overrideWithValue(repo),
    profileControllerProvider.overrideWith(
      (ref) => _SeededProfileController(ref, _commercialProfile),
    ),
  ];
  if (container != null) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _testRouter()),
    );
  }
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: _testRouter()),
  );
}

void main() {
  group('DealerListScreen — filter chips', () {
    testWidgets('4 chip count\'larıyla render edilir', (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Tümü (4) / Aktif (3) / Pasif (1) / Borçlu (2)
      expect(find.text('${AppStrings.dealerFilterAll} (4)'), findsOneWidget);
      expect(find.text('${AppStrings.dealerFilterActive} (3)'),
          findsOneWidget);
      expect(find.text('${AppStrings.dealerFilterPassive} (1)'),
          findsOneWidget);
      expect(find.text('${AppStrings.dealerFilterDebtOnly} (2)'),
          findsOneWidget);
    });

    testWidgets('"Borçlu" chip tap → yalnız aktif+borçlu',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester
          .tap(find.text('${AppStrings.dealerFilterDebtOnly} (2)'));
      await tester.pumpAndSettle();

      // Aktif+borçlu: Hamdi, Mehmet
      expect(find.text('Hamdi Bakkal'), findsOneWidget);
      expect(find.text('Mehmet Market'), findsOneWidget);
      // Aktif kapalı: Köşe — hariç
      expect(find.text('Köşe Pide'), findsNothing);
      // Pasif borçlu: Şenel — hariç (kural: pasif borçlu sayılmaz)
      expect(find.text('Şenel Büfe'), findsNothing);
    });

    testWidgets('"Aktif" chip tap → aktif 3 bayi (borçlu+kapalı)',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${AppStrings.dealerFilterActive} (3)'));
      await tester.pumpAndSettle();

      expect(find.text('Hamdi Bakkal'), findsOneWidget);
      expect(find.text('Mehmet Market'), findsOneWidget);
      expect(find.text('Köşe Pide'), findsOneWidget);
      expect(find.text('Şenel Büfe'), findsNothing);
    });

    testWidgets('"Pasif" chip tap → yalnız Şenel', (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${AppStrings.dealerFilterPassive} (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Şenel Büfe'), findsOneWidget);
      expect(find.text('Hamdi Bakkal'), findsNothing);
      expect(find.text('Köşe Pide'), findsNothing);
    });

    testWidgets('"Tümü" chip default → 4 bayi listede (scroll dahil)',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // ListView scroll altındaki kartlar offstage olabilir; skipOffstage:
      // false ile widget tree'de varlığını doğrula.
      expect(
        find.text('Hamdi Bakkal', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Mehmet Market', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Köşe Pide', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Şenel Büfe', skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  group('DealerListScreen — prefilter consume', () {
    testWidgets(
        'dealerShellPrefilterDebtOnlyProvider true ile açılış → debtOnly active + provider false reset',
        (tester) async {
      final repo = await _seededRepo();
      final container = ProviderContainer(overrides: [
        dealerRepositoryProvider.overrideWithValue(repo),
        profileControllerProvider.overrideWith(
          (ref) => _SeededProfileController(ref, _commercialProfile),
        ),
      ]);
      addTearDown(container.dispose);

      // Prefilter set ederek ekran aç
      container.read(dealerShellPrefilterDebtOnlyProvider.notifier).state =
          true;

      await tester.pumpWidget(_wrap(repo, container: container));
      await tester.pumpAndSettle();

      // List Hamdi + Mehmet (aktif borçlu) ile başlamalı; Şenel/Köşe hariç
      expect(find.text('Hamdi Bakkal'), findsOneWidget);
      expect(find.text('Mehmet Market'), findsOneWidget);
      expect(find.text('Köşe Pide'), findsNothing);
      expect(find.text('Şenel Büfe'), findsNothing);

      // Prefilter provider one-shot: false'a reset olmuş
      expect(
        container.read(dealerShellPrefilterDebtOnlyProvider),
        isFalse,
      );
    });
  });
}
