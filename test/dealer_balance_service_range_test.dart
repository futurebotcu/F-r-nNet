import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/services/dealer_balance_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const svc = DealerBalanceService();

  // Range: [2026-05-18 00:00, 2026-05-25 00:00) — 7 günlük "bu hafta"
  final rangeStart = DateTime(2026, 5, 18);
  final rangeEnd = DateTime(2026, 5, 25);

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

  group('DealerBalanceService.summarizeRange', () {
    test('boş liste → tüm metrikler 0', () {
      final m = svc.summarizeRange(
        dealerId: 'd1',
        transactions: const [],
        start: rangeStart,
        end: rangeEnd,
      );
      expect(m.dealerId, 'd1');
      expect(m.start, rangeStart);
      expect(m.end, rangeEnd);
      expect(m.totalDelivery, 0);
      expect(m.totalReturn, 0);
      expect(m.totalPayment, 0);
      expect(m.totalAdjustment, 0);
      expect(m.netChange, 0);
      expect(m.txCount, 0);
    });

    test('başka dealer\'ın hareketleri filtrelenir', () {
      final m = svc.summarizeRange(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 't1',
            dealerId: 'd2',
            type: DealerTransactionType.delivery,
            amount: 999,
            at: DateTime(2026, 5, 20),
          ),
        ],
        start: rangeStart,
        end: rangeEnd,
      );
      expect(m.totalDelivery, 0);
      expect(m.txCount, 0);
    });

    test('range dışındaki hareketler (before/after) filtrelenir', () {
      final m = svc.summarizeRange(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 'before',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 100,
            at: DateTime(2026, 5, 17, 23, 59), // range start öncesi
          ),
          tx(
            id: 'after',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 100,
            at: DateTime(2026, 5, 25, 0, 1), // range end sonrası
          ),
        ],
        start: rangeStart,
        end: rangeEnd,
      );
      expect(m.totalDelivery, 0);
      expect(m.txCount, 0);
    });

    test('range.start tam anına denk gelen tx INCLUSIVE (dahil)', () {
      final m = svc.summarizeRange(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 'at-start',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 50,
            at: rangeStart, // tam start
          ),
        ],
        start: rangeStart,
        end: rangeEnd,
      );
      expect(m.totalDelivery, 50);
      expect(m.txCount, 1);
    });

    test('range.end tam anına denk gelen tx EXCLUSIVE (hariç)', () {
      final m = svc.summarizeRange(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 'at-end',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 50,
            at: rangeEnd, // tam end
          ),
        ],
        start: rangeStart,
        end: rangeEnd,
      );
      expect(m.totalDelivery, 0);
      expect(m.txCount, 0);
    });

    test('end\'den 1 mikrosaniye önce → INCLUSIVE', () {
      final m = svc.summarizeRange(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 'just-before-end',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 50,
            at: rangeEnd.subtract(const Duration(microseconds: 1)),
          ),
        ],
        start: rangeStart,
        end: rangeEnd,
      );
      expect(m.totalDelivery, 50);
      expect(m.txCount, 1);
    });

    test('4 tip de doğru akümüle olur ve netChange formülü sağlanır', () {
      final m = svc.summarizeRange(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 'd',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 300,
            at: DateTime(2026, 5, 19),
          ),
          tx(
            id: 'r',
            dealerId: 'd1',
            type: DealerTransactionType.returned,
            amount: 40,
            at: DateTime(2026, 5, 20),
          ),
          tx(
            id: 'p',
            dealerId: 'd1',
            type: DealerTransactionType.payment,
            amount: 100,
            at: DateTime(2026, 5, 21),
          ),
          tx(
            id: 'a',
            dealerId: 'd1',
            type: DealerTransactionType.adjustment,
            amount: 25,
            at: DateTime(2026, 5, 22),
          ),
        ],
        start: rangeStart,
        end: rangeEnd,
      );
      expect(m.totalDelivery, 300);
      expect(m.totalReturn, 40);
      expect(m.totalPayment, 100);
      expect(m.totalAdjustment, 25);
      // netChange = 300 − 40 − 100 + 25 = 185
      expect(m.netChange, 185);
      expect(m.txCount, 4);
    });

    test('adjustment negatif amount\'u korur (işaretli sum)', () {
      final m = svc.summarizeRange(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 'a-neg',
            dealerId: 'd1',
            type: DealerTransactionType.adjustment,
            amount: -75,
            at: DateTime(2026, 5, 22),
          ),
        ],
        start: rangeStart,
        end: rangeEnd,
      );
      expect(m.totalAdjustment, -75);
      expect(m.netChange, -75);
      expect(m.txCount, 1);
    });
  });
}
