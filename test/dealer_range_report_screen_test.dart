// Sprint 3 — DealerRangeReportScreen widget testleri.
//
// Sabit `now = 2026-05-24 14:00` (Pazar) ile period chip seçimi,
// metrik gösterimi ve empty state davranışını doğrular.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/utils/number_formatter.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_range_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  // Sabit ref noktası — 2026-05-24 Pazar 14:00.
  final fixedNow = DateTime(2026, 5, 24, 14);

  // DealerPeriod ile aynı boundary'ler:
  // today:         [2026-05-24, 2026-05-25)
  // thisWeek:      [2026-05-18, 2026-05-25)
  // thisMonth:     [2026-05-01, 2026-06-01)
  // last30Days:    [2026-04-25, 2026-05-25)
  // previousWeek:  [2026-05-11, 2026-05-18)
  // previousMonth: [2026-04-01, 2026-05-01)

  // Test verisi — her tx farklı periyot kümesine düşer.
  // t1 (5/24, today)    ∈ today, thisWeek, thisMonth, last30
  // t2 (5/22, payment)  ∈ thisWeek, thisMonth, last30
  // t3 (5/15)           ∈ thisMonth, last30, previousWeek (5/15 < 5/18 thisWeek hariç)
  // t4 (4/15)           ∈ previousMonth (4/15 < 4/25 last30 hariç)
  Future<LocalDealerRepository> seededRepo() async {
    final repo = LocalDealerRepository(seed: false);
    await repo.upsertDealer(Dealer(
      id: 'd1',
      name: 'Test Bayisi',
      createdAt: DateTime(2026, 1, 1),
    ));
    await repo.upsertDealer(Dealer(
      id: 'd2-empty',
      name: 'Boş Bayi',
      createdAt: DateTime(2026, 1, 1),
    ));
    await repo.addTransaction(DealerTransaction(
      id: 't1-today',
      dealerId: 'd1',
      type: DealerTransactionType.delivery,
      amount: 100,
      createdAt: DateTime(2026, 5, 24, 10),
    ));
    await repo.addTransaction(DealerTransaction(
      id: 't2-thisweek',
      dealerId: 'd1',
      type: DealerTransactionType.payment,
      amount: 50,
      createdAt: DateTime(2026, 5, 22, 14),
    ));
    await repo.addTransaction(DealerTransaction(
      id: 't3-prevweek',
      dealerId: 'd1',
      type: DealerTransactionType.delivery,
      amount: 200,
      createdAt: DateTime(2026, 5, 15, 9),
    ));
    await repo.addTransaction(DealerTransaction(
      id: 't4-prevmonth',
      dealerId: 'd1',
      type: DealerTransactionType.delivery,
      amount: 300,
      createdAt: DateTime(2026, 4, 15, 9),
    ));
    return repo;
  }

  Widget wrap(LocalDealerRepository repo, String dealerId) {
    return ProviderScope(
      overrides: [
        dealerRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: DealerRangeReportScreen(dealerId: dealerId, now: fixedNow),
      ),
    );
  }

  group('DealerRangeReportScreen', () {
    testWidgets('default period (Son 30 gün) — t1+t2+t3 (t4 hariç)',
        (tester) async {
      final repo = await seededRepo();
      await tester.pumpWidget(wrap(repo, 'd1'));
      await tester.pumpAndSettle();

      // AppBar bayi adıyla
      expect(find.textContaining('Test Bayisi'), findsOneWidget);

      // 6 chip görünür
      expect(find.text(AppStrings.dealerTxFilterRangeToday), findsOneWidget);
      expect(find.text(AppStrings.dealerTxFilterRangeWeek), findsOneWidget);
      expect(find.text(AppStrings.dealerTxFilterRangeMonth), findsOneWidget);
      expect(find.text(AppStrings.dealerReportPeriodLast30), findsOneWidget);
      expect(find.text(AppStrings.dealerReportPeriodPrevWeek), findsOneWidget);
      expect(find.text(AppStrings.dealerReportPeriodPrevMonth), findsOneWidget);

      // last30 → t1+t2+t3: delivery 100+200=300, payment 50,
      // netChange 300-50=250, txCount 3
      expect(find.text(NumberFormatter.currency(300)), findsOneWidget);
      expect(find.text(NumberFormatter.currency(50)), findsOneWidget);
      expect(find.text(NumberFormatter.currency(250)), findsOneWidget);
      expect(find.text(NumberFormatter.integer(3)), findsOneWidget);
    });

    testWidgets('"Bugün" chip → yalnız t1 (delivery 100)', (tester) async {
      final repo = await seededRepo();
      await tester.pumpWidget(wrap(repo, 'd1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.dealerTxFilterRangeToday));
      await tester.pumpAndSettle();

      // delivery=100, netChange=100 → ₺100,00 iki tile'da görünür
      expect(find.text(NumberFormatter.currency(100)), findsNWidgets(2));
      expect(find.text(NumberFormatter.integer(1)), findsOneWidget);
    });

    testWidgets('"Geçen ay" chip → yalnız t4 (delivery 300)', (tester) async {
      final repo = await seededRepo();
      await tester.pumpWidget(wrap(repo, 'd1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.dealerReportPeriodPrevMonth));
      await tester.pumpAndSettle();

      // delivery=300, netChange=300 → ₺300,00 iki tile'da görünür
      expect(find.text(NumberFormatter.currency(300)), findsNWidgets(2));
      expect(find.text(NumberFormatter.integer(1)), findsOneWidget);
    });

    testWidgets('"Geçen hafta" chip → t3 (delivery 200)', (tester) async {
      final repo = await seededRepo();
      await tester.pumpWidget(wrap(repo, 'd1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.dealerReportPeriodPrevWeek));
      await tester.pumpAndSettle();

      // delivery=200, netChange=200
      expect(find.text(NumberFormatter.currency(200)), findsNWidgets(2));
      expect(find.text(NumberFormatter.integer(1)), findsOneWidget);
    });

    testWidgets('Hareketsiz bayi → empty state', (tester) async {
      final repo = await seededRepo();
      await tester.pumpWidget(wrap(repo, 'd2-empty'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.dealerReportEmptyTitle), findsOneWidget);
      expect(find.text(AppStrings.dealerReportEmptyBody), findsOneWidget);
      // Empty durumda metric kart yok
      expect(find.text(AppStrings.dealerReportMetricNet), findsNothing);
      expect(find.text(AppStrings.dealerReportMetricTxCount), findsNothing);
    });

    testWidgets('Chip seçimi state değiştirir (last30 → Bu hafta)',
        (tester) async {
      final repo = await seededRepo();
      await tester.pumpWidget(wrap(repo, 'd1'));
      await tester.pumpAndSettle();

      // last30 (default): netChange=250, txCount=3
      expect(find.text(NumberFormatter.currency(250)), findsOneWidget);
      expect(find.text(NumberFormatter.integer(3)), findsOneWidget);

      // "Bu hafta" tıkla — thisWeek [5/18, 5/25): t1+t2 (t3 5/15 hariç)
      // delivery=100, payment=50, netChange=50, txCount=2
      await tester.tap(find.text(AppStrings.dealerTxFilterRangeWeek));
      await tester.pumpAndSettle();

      expect(find.text(NumberFormatter.currency(50)), findsNWidgets(2));
      expect(find.text(NumberFormatter.integer(2)), findsOneWidget);
    });
  });
}
