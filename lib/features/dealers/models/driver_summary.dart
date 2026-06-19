import '../services/dealer_period.dart';

/// Genel Hesap / şoför özeti tarih filtresi (stabil family key — DateTime
/// yerine enum, böylece provider her build'de recompute olmaz).
enum DriverSummaryRange { today, last7Days, thisMonth }

extension DriverSummaryRangeX on DriverSummaryRange {
  String get label {
    switch (this) {
      case DriverSummaryRange.today:
        return 'Bugün';
      case DriverSummaryRange.last7Days:
        return 'Son 7 gün';
      case DriverSummaryRange.thisMonth:
        return 'Bu ay';
    }
  }

  ({DateTime start, DateTime end}) range({DateTime? now}) {
    switch (this) {
      case DriverSummaryRange.today:
        return DealerPeriod.today(now: now);
      case DriverSummaryRange.last7Days:
        return DealerPeriod.lastNDays(7, now: now);
      case DriverSummaryRange.thisMonth:
        return DealerPeriod.thisMonth(now: now);
    }
  }
}

/// Bir şoförün `[start, end)` aralığındaki işlem özeti (tek defter, driver_id
/// filtrelenmiş görünüm). Kaynak: dealer_transactions (+delivery satırları),
/// DealerBalanceService.aggregateRange ile hesaplanır — yeni hesap kuralı yok.
class DriverRangeSummary {
  const DriverRangeSummary({
    required this.driverId,
    required this.name,
    required this.isActive,
    required this.assignedDealerCount,
    required this.totalDelivery,
    required this.totalReturn,
    required this.totalPayment,
    required this.totalAdjustment,
    required this.netChange,
    required this.txCount,
  });

  final String driverId;
  final String name;
  final bool isActive;
  final int assignedDealerCount;
  final double totalDelivery;
  final double totalReturn;
  final double totalPayment;
  final double totalAdjustment;

  /// delivery+adjustment − return − payment (DealerBalanceService konvansiyonu).
  final double netChange;
  final int txCount;
}

/// Tüm şoförlerin birleşik Genel Hesap özeti + şoför bazlı kırılım.
class DriversGeneralSummary {
  const DriversGeneralSummary({
    required this.totalDrivers,
    required this.activeDrivers,
    required this.totalDelivery,
    required this.totalReturn,
    required this.totalPayment,
    required this.netChange,
    required this.txCount,
    required this.perDriver,
  });

  final int totalDrivers;
  final int activeDrivers;
  final double totalDelivery;
  final double totalReturn;
  final double totalPayment;
  final double netChange;
  final int txCount;
  final List<DriverRangeSummary> perDriver;
}
