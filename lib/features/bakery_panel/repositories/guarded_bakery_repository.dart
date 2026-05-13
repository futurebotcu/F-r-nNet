import '../../auth/services/auth_required_guard.dart';
import '../models/daily_summary.dart';
import '../models/dealer_delivery_entry.dart';
import '../models/production_entry.dart';
import '../models/waste_entry.dart';
import 'bakery_repository.dart';

/// V1.3.3 — guest write korumalı [BakeryRepository] dekoratörü.
class GuardedBakeryRepository implements BakeryRepository {
  GuardedBakeryRepository({required this.inner, required this.canWriteCheck});

  final BakeryRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  // ── Read ────────────────────────────────────────────

  @override
  Future<List<ProductionEntry>> listProduction({DateTime? day}) =>
      inner.listProduction(day: day);

  @override
  Future<List<DealerDeliveryEntry>> listDeliveries({DateTime? day}) =>
      inner.listDeliveries(day: day);

  @override
  Future<List<WasteEntry>> listWastes({DateTime? day}) =>
      inner.listWastes(day: day);

  @override
  Future<DailySummary> dailySummary(DateTime day) => inner.dailySummary(day);

  @override
  Stream<void> watch() => inner.watch();

  // ── Write (guarded) ────────────────────────────────

  @override
  Future<void> addProduction(ProductionEntry entry) {
    _requireWrite('üretim kaydı girmek');
    return inner.addProduction(entry);
  }

  @override
  Future<void> addDelivery(DealerDeliveryEntry entry) {
    _requireWrite('bayiye teslimat girmek');
    return inner.addDelivery(entry);
  }

  @override
  Future<void> addWaste(WasteEntry entry) {
    _requireWrite('fire kaydı girmek');
    return inner.addWaste(entry);
  }
}
