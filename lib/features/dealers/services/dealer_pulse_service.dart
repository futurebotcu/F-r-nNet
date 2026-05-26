import '../../../core/util/ema_calculator.dart';
import '../models/dealer_pulse_snapshot.dart';
import '../models/dealer_transaction.dart';

/// Bayi Defteri Nabız hesaplayıcı (Sprint 3.5).
///
/// Tüm bayilerin tx listesinden bugünün gross teslimat/tahsilat ve
/// netChange'i + son 20 non-empty gün'ün EMA baseline'ı hesaplanır.
/// Saf Dart, dependency-free; UI ve repository'den bağımsız.
///
/// Concept inspired by evan361425/flutter-pos-system GoalsCardView
/// (Apache-2.0): EMA-over-20-non-empty-days baseline + bugünü hariç
/// tutma pattern'i. Donor widget kodu kopyalanmadı; FırınNet domain
/// (delivery/payment/netChange) için sıfırdan yazıldı. See
/// THIRD_PARTY_LICENSES.md.
class DealerPulseService {
  const DealerPulseService({this.emaLength = 20});

  /// EMA periyodu (donor pattern: 20 gün).
  final int emaLength;

  DealerPulseSnapshot compute({
    required List<DealerTransaction> transactions,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);

    // Tx'leri gün başına gruplama anahtarı (epoch days).
    final byDay = <DateTime, _DayAgg>{};
    for (final t in transactions) {
      final dayKey =
          DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      final agg = byDay.putIfAbsent(dayKey, _DayAgg.zero);
      switch (t.type) {
        case DealerTransactionType.delivery:
          agg.delivery += t.amount;
          agg.netChange += t.amount;
          break;
        case DealerTransactionType.returned:
          agg.returned += t.amount;
          agg.netChange -= t.amount;
          break;
        case DealerTransactionType.payment:
          agg.payment += t.amount;
          agg.netChange -= t.amount;
          break;
        case DealerTransactionType.adjustment:
          agg.adjustment += t.amount;
          agg.netChange += t.amount;
          break;
      }
    }

    // Bugünün toplamları
    final todayAgg = byDay[today] ?? _DayAgg.zero();
    final todayDelivery = todayAgg.delivery;
    final todayPayment = todayAgg.payment;
    final todayNetChange = todayAgg.netChange;

    // Bugün hariç, geçmiş günleri tarihçe descending sırala
    final pastDays = byDay.entries
        .where((e) => e.key.isBefore(today))
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    // Donor pattern: son N non-empty gün'ü al, oldest → newest sırasına
    // çevirip EMA feed et. byDay map'ı zaten yalnız hareket olan
    // günleri tutar (boş gün otomatik atlanır).
    final lastNonEmpty = pastDays.take(emaLength).toList().reversed.toList();
    final baselineDays = lastNonEmpty.length;

    final calc = EMACalculator(emaLength);
    final baselineDelivery =
        calc.calculate(lastNonEmpty.map((e) => e.value.delivery));
    final baselinePayment =
        calc.calculate(lastNonEmpty.map((e) => e.value.payment));
    final baselineNetChange =
        calc.calculate(lastNonEmpty.map((e) => e.value.netChange));

    return DealerPulseSnapshot(
      todayDelivery: todayDelivery,
      todayPayment: todayPayment,
      todayNetChange: todayNetChange,
      baselineDelivery: baselineDelivery,
      baselinePayment: baselinePayment,
      baselineNetChange: baselineNetChange,
      baselineDays: baselineDays,
    );
  }
}

/// Gün başına aggregate scratch (sadece service iç hesaplama; UI'a
/// sızmaz).
class _DayAgg {
  _DayAgg();

  factory _DayAgg.zero() => _DayAgg();

  double delivery = 0;
  double returned = 0;
  double payment = 0;
  double adjustment = 0;
  double netChange = 0;
}
