// Sprint 3.5 — DealerPulseService unit tests.
//
// Donor concept-lift: EMA-over-20-non-empty-days baseline. Bugünün
// gross delivery/payment + netChange'i + geçmiş günlerin EMA baseline'ı
// hesaplanır. Boş günler atlanır (donor pattern); bugün baseline'a
// dahil edilmez.

import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/services/dealer_pulse_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Sabit "bugün" referansı — 2026-05-24 14:00
  final fixedNow = DateTime(2026, 5, 24, 14);

  DealerTransaction tx({
    required String id,
    required String dealerId,
    required DealerTransactionType type,
    required double amount,
    required DateTime at,
  }) =>
      DealerTransaction(
        id: id,
        dealerId: dealerId,
        type: type,
        amount: amount,
        createdAt: at,
      );

  group('DealerPulseService.compute', () {
    test('boş liste → empty snapshot, baselineDays = 0', () {
      const svc = DealerPulseService();
      final snap =
          svc.compute(transactions: const [], now: fixedNow);
      expect(snap.todayDelivery, 0);
      expect(snap.todayPayment, 0);
      expect(snap.todayNetChange, 0);
      expect(snap.baselineDelivery, 0);
      expect(snap.baselinePayment, 0);
      expect(snap.baselineNetChange, 0);
      expect(snap.baselineDays, 0);
      expect(snap.hasSufficientBaseline, isFalse);
    });

    test('sadece bugünün hareketi → today değerleri dolu, baselineDays=0',
        () {
      const svc = DealerPulseService();
      final snap = svc.compute(
        transactions: [
          tx(
            id: 'd1',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 100,
            at: DateTime(2026, 5, 24, 10),
          ),
          tx(
            id: 'p1',
            dealerId: 'd1',
            type: DealerTransactionType.payment,
            amount: 50,
            at: DateTime(2026, 5, 24, 11),
          ),
        ],
        now: fixedNow,
      );
      expect(snap.todayDelivery, 100);
      expect(snap.todayPayment, 50);
      expect(snap.todayNetChange, 100 - 50);
      // Baseline yok — yalnız bugün vardı
      expect(snap.baselineDays, 0);
      expect(snap.hasSufficientBaseline, isFalse);
    });

    test('bugün hariç tek geçmiş gün → baseline = o günün değeri', () {
      const svc = DealerPulseService();
      final snap = svc.compute(
        transactions: [
          tx(
            id: 'past',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 200,
            at: DateTime(2026, 5, 23, 10),
          ),
        ],
        now: fixedNow,
      );
      // EMA carry=0 → ilk değer kendisi
      expect(snap.baselineDelivery, 200);
      expect(snap.baselineDays, 1);
      // baselineDays < 3 → insufficient
      expect(snap.hasSufficientBaseline, isFalse);
    });

    test('5 günlük geçmiş + bugün → baseline EMA hesaplanır', () {
      const svc = DealerPulseService();
      final snap = svc.compute(
        transactions: [
          // Geçmiş günler — 100, 200, 300, 400, 500 (5 gün)
          for (int day = 1; day <= 5; day++)
            tx(
              id: 'past-$day',
              dealerId: 'd1',
              type: DealerTransactionType.delivery,
              amount: day * 100,
              at: DateTime(2026, 5, 24 - (6 - day), 9),
            ),
          // Bugün
          tx(
            id: 'today',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 600,
            at: DateTime(2026, 5, 24, 9),
          ),
        ],
        now: fixedNow,
      );
      expect(snap.todayDelivery, 600);
      expect(snap.baselineDays, 5);
      expect(snap.hasSufficientBaseline, isTrue);
      // EMA(20) on [100, 200, 300, 400, 500] oldest→newest
      // wf = 2/21
      // c0 = 100
      // c1 = 200 * 2/21 + 100 * 19/21 ≈ 109.52
      // c2 = 300 * 2/21 + 109.52 * 19/21 ≈ 127.62
      // c3 ≈ 153.56
      // c4 ≈ 186.55
      expect(snap.baselineDelivery, greaterThan(180));
      expect(snap.baselineDelivery, lessThan(195));
    });

    test('boş günler atlanır (donor ignoreEmpty pattern)', () {
      const svc = DealerPulseService();
      // 5/23 hareket var, 5/22 boş, 5/21 hareket var
      final snap = svc.compute(
        transactions: [
          tx(
            id: 'a',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 100,
            at: DateTime(2026, 5, 23, 10),
          ),
          tx(
            id: 'b',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 200,
            at: DateTime(2026, 5, 21, 10),
          ),
        ],
        now: fixedNow,
      );
      // 2 non-empty geçmiş gün
      expect(snap.baselineDays, 2);
    });

    test('netChange formülü: delivery + adjustment − return − payment', () {
      const svc = DealerPulseService();
      final pastDay = DateTime(2026, 5, 23, 9);
      final snap = svc.compute(
        transactions: [
          tx(
            id: '1',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 1000,
            at: pastDay,
          ),
          tx(
            id: '2',
            dealerId: 'd1',
            type: DealerTransactionType.returned,
            amount: 100,
            at: pastDay,
          ),
          tx(
            id: '3',
            dealerId: 'd1',
            type: DealerTransactionType.payment,
            amount: 300,
            at: pastDay,
          ),
          tx(
            id: '4',
            dealerId: 'd1',
            type: DealerTransactionType.adjustment,
            amount: 50,
            at: pastDay,
          ),
        ],
        now: fixedNow,
      );
      // netChange = 1000 - 100 - 300 + 50 = 650
      expect(snap.baselineNetChange, 650);
      expect(snap.baselineDelivery, 1000);
      expect(snap.baselinePayment, 300);
    });

    test('20+ geçmiş gün → yalnız son 20 EMA serisi', () {
      const svc = DealerPulseService();
      final txs = <DealerTransaction>[];
      // 25 günlük arka geçmiş, hep amount=100
      for (int i = 1; i <= 25; i++) {
        txs.add(tx(
          id: 'd-$i',
          dealerId: 'd1',
          type: DealerTransactionType.delivery,
          amount: 100,
          at: DateTime(2026, 5, 24 - i, 10),
        ));
      }
      final snap = svc.compute(transactions: txs, now: fixedNow);
      // Tüm değerler 100 → EMA converges ~100
      expect(snap.baselineDays, 20);
      expect(snap.baselineDelivery, closeTo(100, 0.01));
    });
  });
}
