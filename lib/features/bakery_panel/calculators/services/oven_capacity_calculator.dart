import 'calc_safety.dart';

/// Fırın kapasite yorumu: girdiler eksikse hesap yapılamaz, tek tur bile
/// sığmıyorsa noCycle, aksi hâlde ok.
enum OvenCapacityVerdict { invalid, noCycle, ok }

/// "Fırın Kapasite Hesabı" sonucu.
class OvenCapacityResult {
  const OvenCapacityResult({
    required this.cyclesPerDay,
    required this.maxDailyPieces,
    required this.hourlyCapacity,
    required this.cycleMinutes,
    required this.verdict,
  });

  /// Günlük tam tur sayısı (aşağı yuvarlanır).
  final int cyclesPerDay;

  /// Azami günlük ürün = tur × tepsi × tepsi başı ürün.
  final int maxDailyPieces;

  /// Saatlik kapasite = azami günlük ürün / çalışma saati.
  final double hourlyCapacity;

  /// Bir tur süresi = pişirme + yükleme/boşaltma (dakika).
  final double cycleMinutes;

  final OvenCapacityVerdict verdict;
}

/// Tepsi sayısı, pişirme süresi ve günlük çalışma saatine göre fırının
/// günlük üretim tavanını hesaplar (saf Dart).
///
/// Tepsi, tepsi başı ürün, tur süresi veya çalışma saati 0 ise
/// [OvenCapacityVerdict.invalid]; gün içine tek tam tur sığmıyorsa
/// [OvenCapacityVerdict.noCycle] döner. NaN / Infinity / sıfıra bölme
/// üretmez; negatifler 0'a normalize edilir.
class OvenCapacityCalculator {
  const OvenCapacityCalculator();

  OvenCapacityResult calculate({
    required double trayCount,
    required double piecesPerTray,
    required double bakeMinutes,
    required double dailyHours,
    double loadUnloadMinutes = 0,
  }) {
    final trays = nonNeg(trayCount);
    final pieces = nonNeg(piecesPerTray);
    final bake = nonNeg(bakeMinutes);
    final hours = nonNeg(dailyHours);
    final loadUnload = nonNeg(loadUnloadMinutes);

    final cycleMinutes = bake + loadUnload;

    if (trays <= 0 || pieces <= 0 || cycleMinutes <= 0 || hours <= 0) {
      return const OvenCapacityResult(
        cyclesPerDay: 0,
        maxDailyPieces: 0,
        hourlyCapacity: 0,
        cycleMinutes: 0,
        verdict: OvenCapacityVerdict.invalid,
      );
    }

    final cycles = safeDiv(hours * 60, cycleMinutes).floor();
    if (cycles <= 0) {
      return OvenCapacityResult(
        cyclesPerDay: 0,
        maxDailyPieces: 0,
        hourlyCapacity: 0,
        cycleMinutes: finiteOrZero(cycleMinutes),
        verdict: OvenCapacityVerdict.noCycle,
      );
    }

    final maxDaily = finiteOrZero(cycles * trays * pieces).floor();
    final hourly = safeDiv(maxDaily.toDouble(), hours);

    return OvenCapacityResult(
      cyclesPerDay: cycles,
      maxDailyPieces: maxDaily,
      hourlyCapacity: finiteOrZero(hourly),
      cycleMinutes: finiteOrZero(cycleMinutes),
      verdict: OvenCapacityVerdict.ok,
    );
  }
}
