// Quality Patch v1 P0-2 — DealerBalanceService.aggregateRange unit testleri.
//
// Cross-dealer agregat helper'ı: tx-type → signed katkı kuralının
// [summarizeRange] ile aynı kaynaktan beslendiğini doğrular. Range
// filter [start, end), signed konvansiyon: delivery/adjustment → +,
// return/payment → −.

import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/services/dealer_balance_service.dart';
import 'package:flutter_test/flutter_test.dart';

DealerTransaction _tx({
  required String id,
  required String dealerId,
  required DealerTransactionType type,
  required double amount,
  required DateTime createdAt,
}) {
  return DealerTransaction(
    id: id,
    dealerId: dealerId,
    type: type,
    amount: amount,
    createdAt: createdAt,
  );
}

void main() {
  const svc = DealerBalanceService();
  final start = DateTime(2026, 5, 1);
  final end = DateTime(2026, 6, 1);

  group('aggregateRange — cross-dealer', () {
    test('boş tx listesi → sıfır metrik', () {
      final r = svc.aggregateRange(
        transactions: const [],
        start: start,
        end: end,
      );
      expect(r.totalDelivery, 0);
      expect(r.totalReturn, 0);
      expect(r.totalPayment, 0);
      expect(r.totalAdjustment, 0);
      expect(r.netChange, 0);
      expect(r.txCount, 0);
    });

    test('range dışı txler atlanır (start dahil, end hariç)', () {
      final txs = [
        // start'tan önce — atla
        _tx(
          id: 't1',
          dealerId: 'd1',
          type: DealerTransactionType.delivery,
          amount: 100,
          createdAt: DateTime(2026, 4, 30, 23, 59),
        ),
        // start tam üstü — dahil
        _tx(
          id: 't2',
          dealerId: 'd1',
          type: DealerTransactionType.delivery,
          amount: 200,
          createdAt: start,
        ),
        // end tam üstü — hariç
        _tx(
          id: 't3',
          dealerId: 'd1',
          type: DealerTransactionType.delivery,
          amount: 400,
          createdAt: end,
        ),
        // end'den önce — dahil
        _tx(
          id: 't4',
          dealerId: 'd1',
          type: DealerTransactionType.delivery,
          amount: 300,
          createdAt: end.subtract(const Duration(seconds: 1)),
        ),
      ];
      final r = svc.aggregateRange(
        transactions: txs,
        start: start,
        end: end,
      );
      expect(r.totalDelivery, 500); // 200 + 300
      expect(r.txCount, 2);
    });

    test('signed katkı kuralı: delivery/adjustment +, return/payment −',
        () {
      final txs = [
        _tx(
          id: 't1',
          dealerId: 'd1',
          type: DealerTransactionType.delivery,
          amount: 1000,
          createdAt: DateTime(2026, 5, 10),
        ),
        _tx(
          id: 't2',
          dealerId: 'd1',
          type: DealerTransactionType.returned,
          amount: 100,
          createdAt: DateTime(2026, 5, 11),
        ),
        _tx(
          id: 't3',
          dealerId: 'd2',
          type: DealerTransactionType.payment,
          amount: 400,
          createdAt: DateTime(2026, 5, 12),
        ),
        _tx(
          id: 't4',
          dealerId: 'd2',
          type: DealerTransactionType.adjustment,
          amount: 50,
          createdAt: DateTime(2026, 5, 13),
        ),
      ];
      final r = svc.aggregateRange(
        transactions: txs,
        start: start,
        end: end,
      );
      expect(r.totalDelivery, 1000);
      expect(r.totalReturn, 100);
      expect(r.totalPayment, 400);
      expect(r.totalAdjustment, 50);
      // netChange = 1000 − 100 − 400 + 50 = 550
      expect(r.netChange, 550);
      expect(r.txCount, 4);
    });

    test('cross-dealer: dealerId filtresi yok; tüm bayilerin toplamı',
        () {
      final txs = [
        for (var i = 0; i < 5; i++)
          _tx(
            id: 'd1-$i',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 100,
            createdAt: DateTime(2026, 5, i + 1),
          ),
        for (var i = 0; i < 3; i++)
          _tx(
            id: 'd2-$i',
            dealerId: 'd2',
            type: DealerTransactionType.delivery,
            amount: 200,
            createdAt: DateTime(2026, 5, i + 1),
          ),
      ];
      final r = svc.aggregateRange(
        transactions: txs,
        start: start,
        end: end,
      );
      // d1: 5 × 100 = 500, d2: 3 × 200 = 600 → toplam 1100
      expect(r.totalDelivery, 1100);
      expect(r.txCount, 8);
    });
  });

  group('summarizeRange artık aggregateRange üzerinden çalışır', () {
    test('per-dealer filter sonrası agregat aynı sonucu verir', () {
      final txs = [
        _tx(
          id: 'd1-deliv',
          dealerId: 'd1',
          type: DealerTransactionType.delivery,
          amount: 500,
          createdAt: DateTime(2026, 5, 5),
        ),
        _tx(
          id: 'd1-pay',
          dealerId: 'd1',
          type: DealerTransactionType.payment,
          amount: 200,
          createdAt: DateTime(2026, 5, 10),
        ),
        // d2 tx'leri filtre'lenmeli
        _tx(
          id: 'd2-deliv',
          dealerId: 'd2',
          type: DealerTransactionType.delivery,
          amount: 999,
          createdAt: DateTime(2026, 5, 6),
        ),
      ];

      final m = svc.summarizeRange(
        dealerId: 'd1',
        transactions: txs,
        start: start,
        end: end,
      );
      expect(m.dealerId, 'd1');
      expect(m.totalDelivery, 500);
      expect(m.totalPayment, 200);
      // netChange = 500 − 200 = 300; d2'nin 999'u dahil DEĞİL
      expect(m.netChange, 300);
      expect(m.txCount, 2);
    });
  });
}
