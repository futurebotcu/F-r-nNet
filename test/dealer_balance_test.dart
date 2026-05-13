import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/services/dealer_balance_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const svc = DealerBalanceService();
  final fixedNow = DateTime(2026, 5, 9, 12);

  DealerTransaction tx({
    required String id,
    required String dealerId,
    required DealerTransactionType type,
    required double amount,
    DateTime? at,
    DealerPaymentMethod? method,
  }) =>
      DealerTransaction(
        id: id,
        dealerId: dealerId,
        type: type,
        amount: amount,
        paymentMethod: method,
        createdAt: at ?? fixedNow,
      );

  group('DealerBalanceService', () {
    test('teslimat bakiyeyi artırır', () {
      final s = svc.summarize(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 't1',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 200,
          ),
        ],
        now: fixedNow,
      );
      expect(s.totalDelivery, 200);
      expect(s.currentBalance, 200);
    });

    test('iade bakiyeyi düşürür', () {
      final s = svc.summarize(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 't1',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 500,
          ),
          tx(
            id: 't2',
            dealerId: 'd1',
            type: DealerTransactionType.returned,
            amount: 80,
          ),
        ],
        now: fixedNow,
      );
      expect(s.totalReturn, 80);
      expect(s.currentBalance, 420);
    });

    test('ödeme bakiyeyi düşürür', () {
      final s = svc.summarize(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 't1',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 800,
          ),
          tx(
            id: 't2',
            dealerId: 'd1',
            type: DealerTransactionType.payment,
            amount: 300,
            method: DealerPaymentMethod.cash,
          ),
        ],
        now: fixedNow,
      );
      expect(s.totalPayment, 300);
      expect(s.currentBalance, 500);
      expect(s.lastPayment, isNotNull);
    });

    test('kısmi ödeme sonrası bakiye doğru kalır', () {
      // 2 teslimat (1000), 1 iade (100), 2 kısmi ödeme (300 + 250) → 350 borç.
      final s = svc.summarize(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 't1',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 600,
            at: fixedNow.subtract(const Duration(days: 3)),
          ),
          tx(
            id: 't2',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 400,
            at: fixedNow.subtract(const Duration(days: 1)),
          ),
          tx(
            id: 't3',
            dealerId: 'd1',
            type: DealerTransactionType.returned,
            amount: 100,
            at: fixedNow.subtract(const Duration(days: 1)),
          ),
          tx(
            id: 't4',
            dealerId: 'd1',
            type: DealerTransactionType.payment,
            amount: 300,
            method: DealerPaymentMethod.transfer,
            at: fixedNow.subtract(const Duration(hours: 12)),
          ),
          tx(
            id: 't5',
            dealerId: 'd1',
            type: DealerTransactionType.payment,
            amount: 250,
            method: DealerPaymentMethod.cash,
            at: fixedNow.subtract(const Duration(hours: 1)),
          ),
        ],
        now: fixedNow,
      );
      expect(s.totalDelivery, 1000);
      expect(s.totalReturn, 100);
      expect(s.totalPayment, 550);
      expect(s.currentBalance, 350);
      // Son ödeme en yakın 1 saat öncesi
      expect(s.lastPayment, fixedNow.subtract(const Duration(hours: 1)));
    });

    test('adjustment + ve − yönde uygulanır', () {
      final s = svc.summarize(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 't1',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 200,
          ),
          tx(
            id: 't2',
            dealerId: 'd1',
            type: DealerTransactionType.adjustment,
            amount: -50,
          ),
        ],
        now: fixedNow,
      );
      expect(s.totalAdjustment, -50);
      expect(s.currentBalance, 150);
    });

    test('başka bayinin işlemleri özete sızmaz', () {
      final s = svc.summarize(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 't1',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 100,
          ),
          tx(
            id: 't2',
            dealerId: 'd2',
            type: DealerTransactionType.delivery,
            amount: 999,
          ),
        ],
        now: fixedNow,
      );
      expect(s.currentBalance, 100);
    });

    test('bugünkü hareketler todayDebt\'e doğru düşer', () {
      final today = DateTime(2026, 5, 9, 8);
      final yesterday = today.subtract(const Duration(days: 1));
      final s = svc.summarize(
        dealerId: 'd1',
        transactions: [
          tx(
            id: 't1',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 500,
            at: yesterday,
          ),
          tx(
            id: 't2',
            dealerId: 'd1',
            type: DealerTransactionType.delivery,
            amount: 200,
            at: today.add(const Duration(hours: 2)),
          ),
          tx(
            id: 't3',
            dealerId: 'd1',
            type: DealerTransactionType.payment,
            amount: 100,
            at: today.add(const Duration(hours: 3)),
          ),
        ],
        now: today.add(const Duration(hours: 5)),
      );
      // todayDebt = 200 - 100 = 100
      expect(s.todayDebt, 100);
      // currentBalance = 500 + 200 - 100 = 600
      expect(s.currentBalance, 600);
    });
  });
}
