// Gün Sonu V1 — DealerEndOfDayTabScreen widget testleri.
//
// Pasif günlük rapor ekranı: header tarihi + KPI grid + bayi bazlı liste
// + bugün son hareketleri + Share CTA. Bugün hareketi yoksa EmptyState
// (KPI/liste gizli).

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_end_of_day_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

// Test-deterministik referans zaman: 2026-05-24 10:00 (Pazar).
final _refNow = DateTime(2026, 5, 24, 10, 0);

Future<LocalDealerRepository> _seededRepoToday() async {
  final repo = LocalDealerRepository(seed: false);
  // 2 aktif bayi + 1 pasif (pasif tx'i overview'a düşse de Gün Sonu'nun
  // bayi bazlı listesinde görünmemeli — provider zaten pasif filter yapar).
  await repo.upsertDealer(Dealer(
    id: 'd-active-1',
    name: 'Hamdi Bakkal',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd-active-2',
    name: 'Mehmet Market',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd-passive',
    name: 'Şenel Büfe',
    isActive: false,
    createdAt: DateTime(2026, 1, 1),
  ));

  // Hamdi bugün: delivery 500 + payment 500 → netChange 0 ama tx=2
  // (filter txCount>0 ile listede kalmalı)
  await repo.addTransaction(DealerTransaction(
    id: 't-h1',
    dealerId: 'd-active-1',
    type: DealerTransactionType.delivery,
    amount: 500,
    createdAt: _refNow,
  ));
  await repo.addTransaction(DealerTransaction(
    id: 't-h2',
    dealerId: 'd-active-1',
    type: DealerTransactionType.payment,
    amount: 500,
    createdAt: _refNow,
  ));
  // Mehmet bugün: delivery 300 → net +300
  await repo.addTransaction(DealerTransaction(
    id: 't-m1',
    dealerId: 'd-active-2',
    type: DealerTransactionType.delivery,
    amount: 300,
    createdAt: _refNow,
  ));
  // Eski tx (dün) — Gün Sonu metriklerine girmemeli
  await repo.addTransaction(DealerTransaction(
    id: 't-old',
    dealerId: 'd-active-1',
    type: DealerTransactionType.delivery,
    amount: 9999,
    createdAt: _refNow.subtract(const Duration(days: 1)),
  ));
  return repo;
}

Future<LocalDealerRepository> _seededRepoEmpty() async {
  final repo = LocalDealerRepository(seed: false);
  await repo.upsertDealer(Dealer(
    id: 'd1',
    name: 'Boş Bayi',
    createdAt: DateTime(2026, 1, 1),
  ));
  // Sadece dün tx ekle; bugün boş.
  await repo.addTransaction(DealerTransaction(
    id: 't-yesterday',
    dealerId: 'd1',
    type: DealerTransactionType.delivery,
    amount: 100,
    createdAt: _refNow.subtract(const Duration(days: 1)),
  ));
  return repo;
}

GoRouter _testRouter() => GoRouter(
      initialLocation: '/dealers',
      routes: [
        GoRoute(
          path: '/dealers',
          builder: (_, __) => DealerEndOfDayTabScreen(now: _refNow),
        ),
        GoRoute(
          path: '/dealers/:id',
          builder: (_, state) => Scaffold(
            body: Center(
              child: Text('detail-stub:${state.pathParameters['id']}'),
            ),
          ),
        ),
      ],
    );

Widget _wrap(LocalDealerRepository repo, {ProviderContainer? container}) {
  if (container != null) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _testRouter()),
    );
  }
  return ProviderScope(
    overrides: [dealerRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: _testRouter()),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  group('DealerEndOfDayTabScreen — empty state', () {
    testWidgets('Bugün hareket yok → EmptyState görünür; KPI grid gizli',
        (tester) async {
      final repo = await _seededRepoEmpty();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // EmptyState title + body
      expect(
        find.text(AppStrings.dealerEndOfDayEmptyTitle),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerEndOfDayEmptyBody),
        findsOneWidget,
      );
      // KPI label'ları gizli (KPI grid render edilmedi)
      expect(
        find.text(AppStrings.dealerReportsKpiDelivery.toUpperCase()),
        findsNothing,
      );
      // Bayi bazlı bölüm de yok
      expect(
        find.text(AppStrings.dealerEndOfDayByDealerTitle.toUpperCase()),
        findsNothing,
      );
      // Header (Bugün) yine de görünür
      expect(
        find.text(AppStrings.dealerEndOfDayHeaderToday.toUpperCase()),
        findsOneWidget,
      );
      // Share CTA yine de görünür
      expect(
        find.text(AppStrings.dealerEndOfDayShareCta),
        findsOneWidget,
      );
    });
  });

  group('DealerEndOfDayTabScreen — KPI rendering', () {
    testWidgets('Bugün hareketi varsa KPI label\'ları + summary başlığı',
        (tester) async {
      final repo = await _seededRepoToday();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // 5 KPI label (uppercase)
      expect(
        find.text(AppStrings.dealerReportsKpiDelivery.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerReportsKpiReturn.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerReportsKpiPayment.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerReportsKpiTxCount.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerReportsKpiNetChange.toUpperCase()),
        findsOneWidget,
      );
      // Summary başlığı
      expect(
        find.text(AppStrings.dealerEndOfDaySummaryTitle.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('Bugün tx count = 3 (Hamdi 2 + Mehmet 1, dün hariç)',
        (tester) async {
      final repo = await _seededRepoToday();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // 3 tx (Hamdi delivery+payment, Mehmet delivery; dün tx hariç)
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('DealerEndOfDayTabScreen — Bayi Bazlı Bugün', () {
    testWidgets(
        'Yalnız bugün hareketi olan aktif bayiler listede; pasif ve '
        'dünden tx hariç', (tester) async {
      final repo = await _seededRepoToday();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Aktif + bugün hareket → Hamdi + Mehmet
      expect(find.text('Hamdi Bakkal'), findsAtLeastNWidgets(1));
      expect(find.text('Mehmet Market'), findsAtLeastNWidgets(1));
      // Pasif Şenel listede yok
      expect(find.text('Şenel Büfe'), findsNothing);
    });

    testWidgets(
        'txCount > 0 ama netChange = 0 senaryosu (Hamdi) yine listede',
        (tester) async {
      final repo = await _seededRepoToday();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Hamdi netChange = 0 ama 2 tx → listede + "2 işlem" satırı
      expect(
        find.text('2 ${AppStrings.dealerEndOfDayTxCountSuffix}'),
        findsOneWidget,
      );
    });

    testWidgets('Bayi satır tap → /dealers/:id detail route',
        (tester) async {
      final repo = await _seededRepoToday();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Mehmet adı iki yerde görünür: Bayi Bazlı row + Recent Hareketler
      // row. İlk match `_DealerTodayRow` (Bayi Bazlı) → onu tıkla.
      // SingleChildScrollView içinde offstage olabilir → skipOffstage:false.
      final row =
          find.text('Mehmet Market', skipOffstage: false).first;
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('detail-stub:d-active-2'), findsOneWidget);
    });
  });

  group('DealerEndOfDayTabScreen — Bugünün Hareketleri', () {
    testWidgets('"Tümünü Gör" tap → dealerShellTabIndexProvider = 2',
        (tester) async {
      final repo = await _seededRepoToday();
      final container = ProviderContainer(overrides: [
        dealerRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(repo, container: container));
      await tester.pumpAndSettle();

      expect(container.read(dealerShellTabIndexProvider), 0);

      final seeAll = find.text(AppStrings.dealerEndOfDaySeeAll);
      await tester.ensureVisible(seeAll);
      await tester.pumpAndSettle();
      await tester.tap(seeAll);
      await tester.pumpAndSettle();

      expect(container.read(dealerShellTabIndexProvider), 2);
    });
  });
}
