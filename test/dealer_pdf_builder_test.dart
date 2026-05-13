import 'dart:io';

import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/services/dealer_balance_service.dart';
import 'package:firin_defter/features/dealers/services/dealer_pdf_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  group('DealerPdfBuilder', () {
    test('Helvetica fallback ile PDF üretir (V1 davranışı)', () async {
      final repo = LocalDealerRepository(seed: true);
      final dealer = await repo.getDealer('d_hamdi');
      final txs = await repo.listTransactions('d_hamdi');
      final summary = const DealerBalanceService()
          .summarize(dealerId: 'd_hamdi', transactions: txs);

      final bytes = await const DealerPdfBuilder().build(
        dealer: dealer!,
        summary: summary,
        recentTransactions: txs.take(8).toList(),
      );

      expect(bytes.lengthInBytes, greaterThan(2000));
      expect(_looksLikePdf(bytes), isTrue);
    });

    test('Roboto ttf font ile PDF üretir (V1.1 default)', () async {
      final regular =
          await File('assets/fonts/Roboto-Regular.ttf').readAsBytes();
      final bold =
          await File('assets/fonts/Roboto-Bold.ttf').readAsBytes();

      expect(regular.length, greaterThan(50000),
          reason: 'Regular font asset bulunamadı veya boş');
      expect(bold.length, greaterThan(50000),
          reason: 'Bold font asset bulunamadı veya boş');

      final repo = LocalDealerRepository(seed: true);
      final dealer = await repo.getDealer('d_hamdi');
      final txs = await repo.listTransactions('d_hamdi');
      final summary = const DealerBalanceService()
          .summarize(dealerId: 'd_hamdi', transactions: txs);

      final bytes = await const DealerPdfBuilder().build(
        dealer: dealer!,
        summary: summary,
        recentTransactions: txs.take(8).toList(),
        regularFont: regular,
        boldFont: bold,
      );

      // Font subset embed edildiğinde PDF Helvetica fallback (~5 KB) yerine
      // ~10–25 KB civarında olmalı.
      expect(bytes.lengthInBytes, greaterThan(8000),
          reason: 'Font subset embed edilmedi mi?');
      expect(_looksLikePdf(bytes), isTrue);

      // Çıktıyı qa klasörüne kaydet — V1.1 PDF kanıtı.
      final out = File(
        'qa-screenshots/dealer-management-v1/08_pdf_created_v1_1.pdf',
      );
      await out.create(recursive: true);
      await out.writeAsBytes(bytes);
    });
  });
}

bool _looksLikePdf(List<int> bytes) {
  if (bytes.length < 4) return false;
  // PDF magic: %PDF
  return bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;
}
