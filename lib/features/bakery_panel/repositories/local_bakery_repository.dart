import 'dart:async';

import '../models/daily_summary.dart';
import '../models/dealer_delivery_entry.dart';
import '../models/production_entry.dart';
import '../models/waste_entry.dart';
import 'bakery_repository.dart';

/// Bellek içi (in-memory) repository.
/// Uygulama yeniden açıldığında veriler sıfırlanır — V1 mock için yeterli.
///
/// TODO(v2): Sadece okuma/yazma metotlarının gövdesi değişecek şekilde
/// SupabaseBakeryRepository eklenebilir. UI ve provider katmanı bu sınıfa
/// değil, [BakeryRepository] arayüzüne bağlı.
class LocalBakeryRepository implements BakeryRepository {
  LocalBakeryRepository();

  final List<ProductionEntry> _production = <ProductionEntry>[];
  final List<DealerDeliveryEntry> _deliveries = <DealerDeliveryEntry>[];
  final List<WasteEntry> _wastes = <WasteEntry>[];

  final StreamController<void> _changes = StreamController<void>.broadcast();

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _notify() => _changes.add(null);

  @override
  Future<List<ProductionEntry>> listProduction({DateTime? day}) async {
    if (day == null) return List.unmodifiable(_production);
    return List.unmodifiable(
      _production.where((e) => _sameDay(e.createdAt, day)),
    );
  }

  @override
  Future<void> addProduction(ProductionEntry entry) async {
    _production.add(entry);
    _notify();
  }

  @override
  Future<List<DealerDeliveryEntry>> listDeliveries({DateTime? day}) async {
    if (day == null) return List.unmodifiable(_deliveries);
    return List.unmodifiable(
      _deliveries.where((e) => _sameDay(e.deliveryDate, day)),
    );
  }

  @override
  Future<void> addDelivery(DealerDeliveryEntry entry) async {
    _deliveries.add(entry);
    _notify();
  }

  @override
  Future<List<WasteEntry>> listWastes({DateTime? day}) async {
    if (day == null) return List.unmodifiable(_wastes);
    return List.unmodifiable(
      _wastes.where((e) => _sameDay(e.createdAt, day)),
    );
  }

  @override
  Future<void> addWaste(WasteEntry entry) async {
    _wastes.add(entry);
    _notify();
  }

  @override
  Future<DailySummary> dailySummary(DateTime day) async {
    return DailySummary(
      day: day,
      production: await listProduction(day: day),
      deliveries: await listDeliveries(day: day),
      wastes: await listWastes(day: day),
    );
  }

  @override
  Stream<void> watch() => _changes.stream;
}
