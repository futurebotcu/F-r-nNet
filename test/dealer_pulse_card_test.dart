// Sprint 3.5 — DealerPulseCard widget tests.
//
// Card render senaryoları: yeterli baseline (3+ non-empty gün) → 3 satır
// metric + delta% + arrow; yetersiz baseline → placeholder card.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/widgets/dealer_pulse_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<LocalDealerRepository> _seededRepo({required _Seed seed}) async {
  final repo = LocalDealerRepository(seed: false);
  await repo.upsertDealer(Dealer(
    id: 'd1',
    name: 'Hamdi',
    createdAt: DateTime(2026, 1, 1),
  ));
  final now = DateTime.now();
  switch (seed) {
    case _Seed.empty:
      break;
    case _Seed.onlyToday:
      await repo.addTransaction(DealerTransaction(
        id: 'today',
        dealerId: 'd1',
        type: DealerTransactionType.delivery,
        amount: 100,
        createdAt: now,
      ));
      break;
    case _Seed.fivePastDaysPlusToday:
      // 5 geçmiş gün delivery 100/200/300/400/500 + bugün 600
      for (int day = 1; day <= 5; day++) {
        await repo.addTransaction(DealerTransaction(
          id: 'past-$day',
          dealerId: 'd1',
          type: DealerTransactionType.delivery,
          amount: day * 100.0,
          createdAt: now.subtract(Duration(days: 6 - day)),
        ));
      }
      await repo.addTransaction(DealerTransaction(
        id: 'today',
        dealerId: 'd1',
        type: DealerTransactionType.delivery,
        amount: 600,
        createdAt: now,
      ));
      break;
  }
  return repo;
}

enum _Seed { empty, onlyToday, fivePastDaysPlusToday }

Widget _wrap(LocalDealerRepository repo) {
  return ProviderScope(
    overrides: [
      dealerRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: DealerPulseCard(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('DealerPulseCard — rendering', () {
    testWidgets('boş data → insufficient placeholder', (tester) async {
      final repo = await _seededRepo(seed: _Seed.empty);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.dealerPulseInsufficientTitle),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerPulseInsufficientBody),
        findsOneWidget,
      );
      // 3 metric satırı görünmemeli
      expect(
        find.text(AppStrings.dealerPulseMetricDelivery),
        findsNothing,
      );
    });

    testWidgets('sadece bugünün hareketi → insufficient (baseline yok)',
        (tester) async {
      final repo = await _seededRepo(seed: _Seed.onlyToday);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.dealerPulseInsufficientTitle),
        findsOneWidget,
      );
    });

    testWidgets('5 geçmiş gün + bugün → 3 metric satırı render edilir',
        (tester) async {
      final repo = await _seededRepo(seed: _Seed.fivePastDaysPlusToday);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Insufficient placeholder GİTMELİ
      expect(
        find.text(AppStrings.dealerPulseInsufficientTitle),
        findsNothing,
      );

      // 3 metric satırı görünür
      expect(
        find.text(AppStrings.dealerPulseMetricDelivery),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerPulseMetricPayment),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerPulseMetricNetChange),
        findsOneWidget,
      );

      // NABIZ başlığı
      expect(find.text(AppStrings.dealerPulseTitle), findsOneWidget);

      // "5 günlük baseline" satırı
      expect(find.text('5 günlük baseline'), findsOneWidget);
    });

    testWidgets('today > baseline → yukarı arrow + pozitif yüzde',
        (tester) async {
      final repo = await _seededRepo(seed: _Seed.fivePastDaysPlusToday);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // delivery EMA(5 day series, 100..500) ≈ 186.55
      // today = 600 → delta pozitif çok yüksek
      // En az bir arrow_upward ikon görünmeli
      expect(find.byIcon(Icons.arrow_upward_rounded), findsWidgets);
    });
  });
}
