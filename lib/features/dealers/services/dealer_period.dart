/// Bayi defteri zaman aralığı yardımcısı.
///
/// Tüm aralıklar `[start, end)` konvansiyonu kullanır — start dahil,
/// end hariç. Hafta Pazartesi başlar (`DealerBalanceService.summarize`
/// ile aynı konvansiyon).
///
/// Saf Dart, dependency-free. UI tarafı `DateTimeRange`'e dönüştürmek
/// isterse: `DateTimeRange(start: r.start, end: r.end)`.
///
/// Concept inspired by evan361425/flutter-pos-system Period helper
/// (Apache-2.0); written from scratch for FırınNet, no code copied.
class DealerPeriod {
  const DealerPeriod._();

  /// Bugün: `[bugün 00:00, yarın 00:00)`.
  static ({DateTime start, DateTime end}) today({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final start = DateTime(ref.year, ref.month, ref.day);
    final end = start.add(const Duration(days: 1));
    return (start: start, end: end);
  }

  /// Bu hafta (Pazartesi–Pazar): `[bu Pazartesi 00:00, sonraki Pazartesi 00:00)`.
  static ({DateTime start, DateTime end}) thisWeek({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final start = today.subtract(Duration(days: today.weekday - 1));
    final end = start.add(const Duration(days: 7));
    return (start: start, end: end);
  }

  /// Bu ay: `[ayın 1'i 00:00, gelecek ayın 1'i 00:00)`.
  static ({DateTime start, DateTime end}) thisMonth({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final start = DateTime(ref.year, ref.month, 1);
    final end = DateTime(ref.year, ref.month + 1, 1);
    return (start: start, end: end);
  }

  /// Son [days] takvim günü, bugün dahil:
  /// `[bugün 00:00 − (days−1) gün, yarın 00:00)`.
  ///
  /// `days < 1` ise 1 olarak kabul edilir (today davranışı).
  static ({DateTime start, DateTime end}) lastNDays(int days, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final n = days < 1 ? 1 : days;
    final start = today.subtract(Duration(days: n - 1));
    final end = today.add(const Duration(days: 1));
    return (start: start, end: end);
  }

  /// Geçen hafta: `[önceki Pazartesi 00:00, bu Pazartesi 00:00)`.
  static ({DateTime start, DateTime end}) previousWeek({DateTime? now}) {
    final current = thisWeek(now: now);
    return (
      start: current.start.subtract(const Duration(days: 7)),
      end: current.start,
    );
  }

  /// Geçen ay: `[geçen ayın 1'i, bu ayın 1'i)`.
  static ({DateTime start, DateTime end}) previousMonth({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final start = DateTime(ref.year, ref.month - 1, 1);
    final end = DateTime(ref.year, ref.month, 1);
    return (start: start, end: end);
  }
}
