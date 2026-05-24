import 'package:firin_defter/features/dealers/services/dealer_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-05-24, Pazar (weekday=7), 14:30 — sınır testleri için sabit ref.
  final sundayAfternoon = DateTime(2026, 5, 24, 14, 30);

  group('DealerPeriod.today', () {
    test('start = bugünün gece yarısı, end = yarının gece yarısı', () {
      final r = DealerPeriod.today(now: sundayAfternoon);
      expect(r.start, DateTime(2026, 5, 24));
      expect(r.end, DateTime(2026, 5, 25));
      expect(r.end.difference(r.start), const Duration(days: 1));
    });

    test('saat farkı (00:01 vs 23:59) sınırları değiştirmez', () {
      final early = DealerPeriod.today(now: DateTime(2026, 5, 24, 0, 1));
      final late = DealerPeriod.today(now: DateTime(2026, 5, 24, 23, 59));
      expect(early.start, late.start);
      expect(early.end, late.end);
    });
  });

  group('DealerPeriod.thisWeek', () {
    test('Pazar (weekday=7) → start önceki Pazartesi, end sonraki Pazartesi',
        () {
      final r = DealerPeriod.thisWeek(now: sundayAfternoon);
      expect(r.start, DateTime(2026, 5, 18)); // Pazartesi
      expect(r.end, DateTime(2026, 5, 25)); // sonraki Pazartesi (exclusive)
      expect(r.end.difference(r.start), const Duration(days: 7));
    });

    test('Pazartesi (weekday=1) → start o gün, end +7 gün', () {
      final monday = DateTime(2026, 5, 18, 10);
      final r = DealerPeriod.thisWeek(now: monday);
      expect(r.start, DateTime(2026, 5, 18));
      expect(r.end, DateTime(2026, 5, 25));
    });

    test('Çarşamba (weekday=3) → start o haftanın Pazartesi', () {
      final wednesday = DateTime(2026, 5, 20, 10);
      final r = DealerPeriod.thisWeek(now: wednesday);
      expect(r.start, DateTime(2026, 5, 18));
      expect(r.end, DateTime(2026, 5, 25));
    });
  });

  group('DealerPeriod.thisMonth', () {
    test('ay ortası → start ayın 1\'i, end gelecek ayın 1\'i', () {
      final r = DealerPeriod.thisMonth(now: sundayAfternoon);
      expect(r.start, DateTime(2026, 5, 1));
      expect(r.end, DateTime(2026, 6, 1));
    });

    test('Aralık → Ocak geçişi doğru sarmalanır', () {
      final dec = DateTime(2026, 12, 15);
      final r = DealerPeriod.thisMonth(now: dec);
      expect(r.start, DateTime(2026, 12, 1));
      expect(r.end, DateTime(2027, 1, 1));
    });
  });

  group('DealerPeriod.lastNDays', () {
    test('lastNDays(1) bugünle eşdeğer', () {
      final r1 = DealerPeriod.lastNDays(1, now: sundayAfternoon);
      final today = DealerPeriod.today(now: sundayAfternoon);
      expect(r1.start, today.start);
      expect(r1.end, today.end);
    });

    test('lastNDays(7) bugün dahil 7 takvim günü', () {
      final r = DealerPeriod.lastNDays(7, now: sundayAfternoon);
      expect(r.start, DateTime(2026, 5, 18));
      expect(r.end, DateTime(2026, 5, 25));
      expect(r.end.difference(r.start), const Duration(days: 7));
    });

    test('lastNDays(0) ve lastNDays(-5) → 1 güne clamp', () {
      final zero = DealerPeriod.lastNDays(0, now: sundayAfternoon);
      final negative = DealerPeriod.lastNDays(-5, now: sundayAfternoon);
      expect(zero.end.difference(zero.start), const Duration(days: 1));
      expect(negative.end.difference(negative.start), const Duration(days: 1));
    });
  });

  group('DealerPeriod.previousWeek', () {
    test('thisWeek.start − 7 gün → previousWeek.start; previousWeek.end = thisWeek.start',
        () {
      final tw = DealerPeriod.thisWeek(now: sundayAfternoon);
      final pw = DealerPeriod.previousWeek(now: sundayAfternoon);
      expect(pw.end, tw.start);
      expect(pw.start, tw.start.subtract(const Duration(days: 7)));
      expect(pw.end.difference(pw.start), const Duration(days: 7));
    });
  });

  group('DealerPeriod.previousMonth', () {
    test('Mayıs → Nisan', () {
      final r = DealerPeriod.previousMonth(now: sundayAfternoon);
      expect(r.start, DateTime(2026, 4, 1));
      expect(r.end, DateTime(2026, 5, 1));
    });

    test('Ocak → bir önceki yılın Aralık ayı', () {
      final jan = DateTime(2026, 1, 15);
      final r = DealerPeriod.previousMonth(now: jan);
      expect(r.start, DateTime(2025, 12, 1));
      expect(r.end, DateTime(2026, 1, 1));
    });
  });
}
