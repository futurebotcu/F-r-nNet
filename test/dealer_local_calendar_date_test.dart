// FN-AUDIT-004 — Bayi date-only alanları yerel takvim gününü kullanmalı.
//
// Önceki `_date()` `.toUtc()` ile yazıyordu; UTC+ saat diliminde gece
// yarısından hemen sonraki (gece vardiyası) bir teslimat önceki güne kayıyor,
// gün sonu/aralık raporu yanlış güne düşüyordu. Bu testler yerel-gün
// kontratını ve gün sonu sınır davranışını kilitler. Saf Dart, DB'siz.

import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/repositories/supabase_dealer_repository.dart';
import 'package:firin_defter/features/dealers/services/dealer_balance_service.dart';
import 'package:firin_defter/features/dealers/services/dealer_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dealerLocalCalendarDate — yerel takvim günü', () {
    test('gece vardiyası: yerel 00:30 aynı yerel güne yazılır', () {
      expect(
        dealerLocalCalendarDate(DateTime(2026, 6, 23, 0, 30)),
        '2026-06-23',
      );
    });

    test('geç akşam: yerel 23:45 aynı yerel güne yazılır', () {
      expect(
        dealerLocalCalendarDate(DateTime(2026, 6, 22, 23, 45)),
        '2026-06-22',
      );
    });

    test('ay/gün sıfır dolgulu', () {
      expect(dealerLocalCalendarDate(DateTime(2026, 1, 5, 9)), '2026-01-05');
    });

    test('UTC dönüşümü YAPMAZ — yerel bileşenleri kullanır', () {
      final d = DateTime(2026, 6, 23, 0, 30); // yerel gece yarısı sonrası
      // UTC+ ortamda eski `.toUtc()` davranışı günü geriye kaydırırdı.
      final utc = d.toUtc();
      if (utc.day != d.day) {
        final utcStr = '${utc.year}-'
            '${utc.month.toString().padLeft(2, '0')}-'
            '${utc.day.toString().padLeft(2, '0')}';
        // Sonucumuz UTC-kaymış günden FARKLI olmalı (yani yerel günü taşır).
        expect(dealerLocalCalendarDate(d), isNot(utcStr));
      }
      expect(dealerLocalCalendarDate(d), '2026-06-23');
    });
  });

  group('DealerPeriod.today — yerel gün sınırı (regresyon)', () {
    test('[start, end) yerel gece yarısı', () {
      final r = DealerPeriod.today(now: DateTime(2026, 6, 23, 8));
      expect(r.start, DateTime(2026, 6, 23));
      expect(r.end, DateTime(2026, 6, 24));
    });
  });

  group('DealerBalanceService — gece vardiyası bugüne sayılır', () {
    test('yerel 00:30 teslimat todayDebt içinde', () {
      final now = DateTime(2026, 6, 23, 8); // bugün = 23
      final tx = DealerTransaction(
        id: 't1',
        dealerId: 'd1',
        type: DealerTransactionType.delivery,
        amount: 100,
        createdAt: DateTime(2026, 6, 23, 0, 30),
      );
      final s = DealerBalanceService()
          .summarize(dealerId: 'd1', transactions: [tx], now: now);
      expect(s.todayDebt, 100);
    });

    test('date-string round-trip yerel günü korur (parse→bugün)', () {
      final delivery = DateTime(2026, 6, 23, 0, 30);
      final stored = dealerLocalCalendarDate(delivery); // '2026-06-23'
      final parsed = DateTime.parse(stored); // yerel 2026-06-23 00:00
      final today = DateTime(2026, 6, 23);
      // Bugünden ÖNCE değil → gün sonu raporunda bugüne düşer.
      expect(parsed.isBefore(today), isFalse);
    });
  });
}
