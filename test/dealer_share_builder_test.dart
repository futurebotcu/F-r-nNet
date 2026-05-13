import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/services/dealer_balance_service.dart';
import 'package:firin_defter/features/dealers/services/dealer_share_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  group('DealerShareBuilder', () {
    test('hesap özeti metni doğru bakiye üretir', () {
      const builder = DealerShareBuilder();
      const balanceSvc = DealerBalanceService();
      final now = DateTime(2026, 5, 9, 12);

      final dealer = Dealer(
        id: 'd1',
        name: 'Hamdi Bakkal',
        area: 'Konya',
        workingType: DealerWorkingType.term,
        createdAt: now.subtract(const Duration(days: 30)),
      );

      final txs = [
        DealerTransaction(
          id: 't1',
          dealerId: 'd1',
          type: DealerTransactionType.delivery,
          productName: 'Ekmek',
          quantity: 100,
          unitPrice: 8.5,
          amount: 850,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        DealerTransaction(
          id: 't2',
          dealerId: 'd1',
          type: DealerTransactionType.payment,
          amount: 200,
          paymentMethod: DealerPaymentMethod.cash,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      final summary =
          balanceSvc.summarize(dealerId: 'd1', transactions: txs, now: now);

      final text = builder.buildPlainText(
        dealer: dealer,
        summary: summary,
        recentTransactions: txs,
        now: now,
      );

      // bayi adı, tarih, başlık beklenir
      expect(text, contains('Hamdi Bakkal'));
      expect(text, contains('FırınNet — Bayi Hesap Özeti'));

      // 850 - 200 = 650 → "650,00" beklenir (tr_TR currency).
      expect(text, contains('650'));

      // Borç durumu
      expect(text, contains('borç'));

      // Son ödeme satırı
      expect(text, contains('Son ödeme'));
    });

    test('alacak durumunda "(alacak)" yazar', () {
      const builder = DealerShareBuilder();
      const balanceSvc = DealerBalanceService();
      final now = DateTime(2026, 5, 9, 12);

      final dealer = Dealer(
        id: 'd1',
        name: 'Test',
        createdAt: now,
      );

      final txs = [
        // Bayi fazla ödeme yapmış: bakiye negatif
        DealerTransaction(
          id: 't1',
          dealerId: 'd1',
          type: DealerTransactionType.delivery,
          amount: 100,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        DealerTransaction(
          id: 't2',
          dealerId: 'd1',
          type: DealerTransactionType.payment,
          amount: 250,
          paymentMethod: DealerPaymentMethod.transfer,
          createdAt: now,
        ),
      ];

      final summary = balanceSvc.summarize(
        dealerId: 'd1',
        transactions: txs,
        now: now,
      );

      final text = builder.buildPlainText(
        dealer: dealer,
        summary: summary,
        recentTransactions: txs,
        now: now,
      );

      expect(summary.currentBalance, -150);
      expect(text, contains('alacak'));
    });
  });
}
