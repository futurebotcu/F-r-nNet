// Gün Sonu V1 — DealerShareBuilder.buildDailySummary unit testleri.
//
// Cross-dealer günlük özet plain text builder. Bugün hareketi yoksa
// net empty-line yazar; hareket varsa header + KPI + bayi bazlı blok
// üretir (yalnız perDealerTxCount > 0 olan kayıtlar).

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_range_metrics.dart';
import 'package:firin_defter/features/dealers/services/dealer_share_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  const builder = DealerShareBuilder();
  final today = DateTime(2026, 5, 24, 10);
  final tomorrow = today.add(const Duration(days: 1));

  Dealer dealer({
    required String id,
    required String name,
    bool isActive = true,
  }) {
    return Dealer(
      id: id,
      name: name,
      isActive: isActive,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  group('buildDailySummary', () {
    test('Bugün hareket yok → header + empty-line', () {
      final text = builder.buildDailySummary(
        metrics: DealerAggregateRangeMetrics.empty(
          start: today,
          end: tomorrow,
        ),
        dealers: const [],
        now: today,
      );
      expect(
        text.contains(AppStrings.dealerEndOfDayPlainTextHeader),
        isTrue,
      );
      expect(
        text.contains(AppStrings.dealerEndOfDayShareEmptyLine),
        isTrue,
      );
      // Hareket yokken bayi bazlı bölüm yazılmaz.
      expect(
        text.contains(AppStrings.dealerEndOfDayByDealerTitle),
        isFalse,
      );
    });

    test('Tek bayi tek tx → KPI satırları + bayi bloğu görünür', () {
      final metrics = DealerAggregateRangeMetrics(
        start: today,
        end: tomorrow,
        totalDelivery: 500,
        totalReturn: 0,
        totalPayment: 0,
        totalAdjustment: 0,
        netChange: 500,
        txCount: 1,
        activeDealerCount: 1,
        perDealerNet: const {'d1': 500},
        perDealerTxCount: const {'d1': 1},
      );
      final text = builder.buildDailySummary(
        metrics: metrics,
        dealers: [dealer(id: 'd1', name: 'Hamdi Bakkal')],
        now: today,
      );

      // KPI satırları
      expect(text.contains('Teslimat:'), isTrue);
      expect(text.contains('Net:'), isTrue);
      expect(text.contains('İşlem:     1'), isTrue);
      // Bayi bazlı bölüm
      expect(
        text.contains(AppStrings.dealerEndOfDayByDealerTitle),
        isTrue,
      );
      expect(text.contains('Hamdi Bakkal'), isTrue);
      expect(
        text.contains('1 ${AppStrings.dealerEndOfDayTxCountSuffix}'),
        isTrue,
      );
    });

    test('Birden çok bayi → netChange descending sıralı', () {
      final metrics = DealerAggregateRangeMetrics(
        start: today,
        end: tomorrow,
        totalDelivery: 800,
        totalReturn: 0,
        totalPayment: 200,
        totalAdjustment: 0,
        netChange: 600,
        txCount: 3,
        activeDealerCount: 2,
        perDealerNet: const {'d1': 500, 'd2': 100},
        perDealerTxCount: const {'d1': 2, 'd2': 1},
      );
      final text = builder.buildDailySummary(
        metrics: metrics,
        dealers: [
          dealer(id: 'd1', name: 'Hamdi Bakkal'),
          dealer(id: 'd2', name: 'Mehmet Market'),
        ],
        now: today,
      );

      final hamdiIndex = text.indexOf('Hamdi Bakkal');
      final mehmetIndex = text.indexOf('Mehmet Market');
      expect(hamdiIndex, isNonNegative);
      expect(mehmetIndex, isNonNegative);
      // Net 500 > 100 → Hamdi önce
      expect(hamdiIndex, lessThan(mehmetIndex));
    });

    test('Düzeltme tutarı 0 değilse Düzeltme satırı yazılır', () {
      final metrics = DealerAggregateRangeMetrics(
        start: today,
        end: tomorrow,
        totalDelivery: 100,
        totalReturn: 0,
        totalPayment: 0,
        totalAdjustment: -25,
        netChange: 75,
        txCount: 2,
        activeDealerCount: 1,
        perDealerNet: const {'d1': 75},
        perDealerTxCount: const {'d1': 2},
      );
      final text = builder.buildDailySummary(
        metrics: metrics,
        dealers: [dealer(id: 'd1', name: 'Hamdi Bakkal')],
        now: today,
      );
      expect(text.contains('Düzeltme:'), isTrue);
    });

    test('Pasif bayi map kaydı varsa bile listelenir mi? (provider zaten '
        'filter yapar — burada saf API kontrolü)', () {
      // Builder kendi başına dealers map'i + perDealerTxCount intersect
      // eder; pasif filter sorumluluğu provider'ın. Burada sadece map'te
      // olmayan bir id'nin atlanması test edilir.
      final metrics = DealerAggregateRangeMetrics(
        start: today,
        end: tomorrow,
        totalDelivery: 100,
        totalReturn: 0,
        totalPayment: 0,
        totalAdjustment: 0,
        netChange: 100,
        txCount: 1,
        activeDealerCount: 1,
        perDealerNet: const {'d1': 100, 'd-unknown': 50},
        perDealerTxCount: const {'d1': 1, 'd-unknown': 1},
      );
      final text = builder.buildDailySummary(
        metrics: metrics,
        dealers: [dealer(id: 'd1', name: 'Hamdi Bakkal')],
        now: today,
      );
      // d-unknown dealers listesinde yok → atlanır.
      expect(text.contains('d-unknown'), isFalse);
      expect(text.contains('Hamdi Bakkal'), isTrue);
    });
  });
}
