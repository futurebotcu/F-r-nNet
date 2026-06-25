import 'calc_safety.dart';

/// Stok yeterlilik / sipariş zamanı yorumu.
///
/// Öncelik sırası: tüketim yoksa hesap yapılamaz → siparişin geçti → kritik
/// (3 günden az) → yakında sipariş ver → güvenli.
enum StockRunwayVerdict { noUsage, orderNow, critical, orderSoon, ok }

/// "Stok Bu Hafta Biter mi?" sonucu.
class StockRunwayResult {
  const StockRunwayResult({
    required this.daysOfCover,
    required this.orderInDays,
    required this.verdict,
  });

  /// Eldeki stok günlük tüketime göre kaç gün yeter.
  final double daysOfCover;

  /// Sipariş için kalan gün = yeterlilik − teslim süresi − güvenli stok.
  /// Negatifse sipariş zamanı geçmiştir (ekranda 0'a kırpılır).
  final double orderInDays;

  final StockRunwayVerdict verdict;
}

/// Eldeki malzemenin kaç gün yeteceğini ve ne zaman sipariş verileceğini
/// hesaplar (saf Dart).
///
/// Tüketim 0 ise yeterlilik tanımsızdır; [StockRunwayVerdict.noUsage] döner.
/// NaN / Infinity / sıfıra bölme üretmez; negatifler 0'a normalize edilir.
class StockRunwayCalculator {
  const StockRunwayCalculator({this.criticalDays = 3, this.orderSoonDays = 1});

  /// Bu günden az yeterlilik "kritik" sayılır.
  final double criticalDays;

  /// Sipariş için kalan gün buna eşit/altıysa "yakında sipariş ver".
  final double orderSoonDays;

  StockRunwayResult calculate({
    required double currentStock,
    required double dailyUsage,
    required double leadTimeDays,
    required double safetyStockDays,
  }) {
    final stock = nonNeg(currentStock);
    final usage = nonNeg(dailyUsage);
    final lead = nonNeg(leadTimeDays);
    final safety = nonNeg(safetyStockDays);

    if (usage <= 0) {
      return const StockRunwayResult(
        daysOfCover: 0,
        orderInDays: 0,
        verdict: StockRunwayVerdict.noUsage,
      );
    }

    final daysOfCover = safeDiv(stock, usage);
    final orderInDays = daysOfCover - lead - safety;

    final StockRunwayVerdict verdict;
    if (orderInDays <= 0) {
      verdict = StockRunwayVerdict.orderNow;
    } else if (daysOfCover < criticalDays) {
      verdict = StockRunwayVerdict.critical;
    } else if (orderInDays <= orderSoonDays) {
      verdict = StockRunwayVerdict.orderSoon;
    } else {
      verdict = StockRunwayVerdict.ok;
    }

    return StockRunwayResult(
      daysOfCover: finiteOrZero(daysOfCover),
      orderInDays: finiteOrZero(orderInDays),
      verdict: verdict,
    );
  }
}
