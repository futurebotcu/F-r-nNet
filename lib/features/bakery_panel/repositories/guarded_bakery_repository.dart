import '../../auth/services/auth_required_guard.dart';
import '../models/bakery_day_book.dart';
import '../models/bakery_task.dart';
import '../models/daily_summary.dart';
import '../models/dealer_delivery_entry.dart';
import '../models/ledger_range_report.dart';
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

  // ── Fırın Defteri V1 ──

  @override
  Future<BakeryDayBook?> dayBook(DateTime day) => inner.dayBook(day);

  @override
  Future<List<BakeryTask>> tasks(DateTime day) => inner.tasks(day);

  @override
  Future<LedgerRangeReport> rangeReport(DateTime from, DateTime to) =>
      inner.rangeReport(from, to);

  @override
  Future<void> upsertDayBook({
    required DateTime day,
    double? revenue,
    String? dayNote,
    String? cashNote,
  }) {
    _requireWrite('günlük defter kaydı girmek');
    return inner.upsertDayBook(
      day: day,
      revenue: revenue,
      dayNote: dayNote,
      cashNote: cashNote,
    );
  }

  @override
  Future<void> closeDay(DateTime day) {
    _requireWrite('günü kapatmak');
    return inner.closeDay(day);
  }

  @override
  Future<void> reopenDay(DateTime day) {
    _requireWrite('günü yeniden açmak');
    return inner.reopenDay(day);
  }

  @override
  Future<String> addTask({
    required DateTime day,
    required String title,
    String? category,
  }) {
    _requireWrite('görev eklemek');
    return inner.addTask(day: day, title: title, category: category);
  }

  @override
  Future<void> setTaskDone(String taskId, bool done) {
    _requireWrite('görev güncellemek');
    return inner.setTaskDone(taskId, done);
  }

  @override
  Future<void> deleteTask(String taskId) {
    _requireWrite('görev silmek');
    return inner.deleteTask(taskId);
  }
}
