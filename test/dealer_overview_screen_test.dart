// Sprint 6B — DealerOverviewScreen widget testleri.
//
// KPI grid (5 tile + aktif bayi chip), son hareketler list, hızlı işlem
// CTA'ları (Bayi Ekle / Borçlu Bayiler / Raporlar). Picker'a giden CTA'lar
// ayrı testte; burada sadece var olduğunu ve doğru provider state'i
// değiştirdiğini doğrula.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

GoRouter _testRouter() => GoRouter(
      initialLocation: '/dealers',
      routes: [
        GoRoute(
          path: '/dealers',
          builder: (_, __) => const DealerOverviewScreen(),
        ),
        GoRoute(
          path: '/dealers/new',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('AddDealerScreen — stub')),
          ),
        ),
      ],
    );

Widget _wrap(LocalDealerRepository repo) {
  return ProviderScope(
    overrides: [
      dealerRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: _testRouter()),
  );
}

Future<LocalDealerRepository> _seededRepo({bool withTx = true}) async {
  final repo = LocalDealerRepository(seed: false);
  // 2 bayi: biri borçlu, biri kapalı
  await repo.upsertDealer(Dealer(
    id: 'd1',
    name: 'Hamdi Bakkal',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd2',
    name: 'Köşe Pide',
    createdAt: DateTime(2026, 1, 1),
  ));
  if (withTx) {
    final now = DateTime.now();
    // d1: ₺500 borçlu, bugün ₺200 teslim + ₺100 ödeme
    await repo.addTransaction(DealerTransaction(
      id: 't-old1',
      dealerId: 'd1',
      type: DealerTransactionType.delivery,
      amount: 600,
      // Bu ay içinde ama eski (örn. ayın başı)
      createdAt: DateTime(now.year, now.month, 1, 10),
    ));
    await repo.addTransaction(DealerTransaction(
      id: 't-today-deliv',
      dealerId: 'd1',
      type: DealerTransactionType.delivery,
      amount: 200,
      createdAt: now,
    ));
    await repo.addTransaction(DealerTransaction(
      id: 't-today-payment',
      dealerId: 'd1',
      type: DealerTransactionType.payment,
      amount: 300,
      createdAt: now,
    ));
    // d1 currentBalance = 600 + 200 - 300 = 500
  }
  return repo;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  group('DealerOverviewScreen — KPI rendering', () {
    testWidgets('default açılış — KPI labels + aktif bayi chip görünür',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Aktif bayi chip (UPPERCASE rendered)
      expect(
        find.text(AppStrings.dealerOverviewActiveDealersLabel),
        findsOneWidget,
      );
      // 5 KPI tile label görünür (uppercase)
      expect(
        find.text(AppStrings.dealerOverviewKpiOpenBalance.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerOverviewKpiTodayDelivery.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerOverviewKpiTodayPayment.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerOverviewKpiMonthTxCount.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerOverviewKpiMonthNetChange.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('aktif bayi sayısı "2 / 2" — seed verisiyle',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // 2 aktif / 2 toplam
      expect(find.text('2 / 2'), findsOneWidget);
    });
  });

  group('DealerOverviewScreen — Son Hareketler', () {
    testWidgets('hareket varsa list satır(lar)ı render edilir',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Son Hareketler section başlığı (uppercase)
      expect(
        find.text(AppStrings.dealerOverviewRecentActivityTitle.toUpperCase()),
        findsOneWidget,
      );
      // En az 1 satır bayi adıyla — Hamdi Bakkal son tx'lere ait
      expect(find.text('Hamdi Bakkal'), findsAtLeastNWidgets(1));
    });

    testWidgets('hareket yoksa empty state', (tester) async {
      final repo = await _seededRepo(withTx: false);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.dealerOverviewEmptyActivity),
        findsOneWidget,
      );
    });
  });

  group('DealerOverviewScreen — Hızlı İşlem CTA tab switch', () {
    testWidgets('"Borçlu Bayiler" CTA → tab provider = 1', (tester) async {
      final repo = await _seededRepo();
      // ProviderContainer ile state'i de okuyalım — direkt provider override yerine
      // bir container kullanmamız gerekirse... aslında ProviderScope içinde overrideler
      // var. Test'te tab provider'ı doğrudan oku.
      final container = ProviderContainer(overrides: [
        dealerRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _testRouter()),
        ),
      );
      await tester.pumpAndSettle();

      // Default tab index = 0
      expect(container.read(dealerShellTabIndexProvider), 0);

      // CTA Wrap'i altta — viewport dışına çıkmış olabilir, önce visible'a getir.
      final cta = find.text(AppStrings.dealerOverviewQuickDebtDealers);
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(container.read(dealerShellTabIndexProvider), 1);
    });

    testWidgets('"Raporlar" CTA → tab provider = 3', (tester) async {
      final repo = await _seededRepo();
      final container = ProviderContainer(overrides: [
        dealerRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _testRouter()),
        ),
      );
      await tester.pumpAndSettle();

      final cta = find.text(AppStrings.dealerOverviewQuickReports);
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(container.read(dealerShellTabIndexProvider), 3);
    });

    testWidgets('"Bayi Ekle" CTA → /dealers/new route push', (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      final cta = find.text(AppStrings.dealerOverviewQuickAddDealer);
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();

      // Stub AddDealerScreen render edilir
      expect(find.text('AddDealerScreen — stub'), findsOneWidget);
    });
  });
}
