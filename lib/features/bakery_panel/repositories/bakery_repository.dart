import '../models/bakery_day_book.dart';
import '../models/bakery_task.dart';
import '../models/daily_summary.dart';
import '../models/dealer_delivery_entry.dart';
import '../models/ledger_range_report.dart';
import '../models/production_entry.dart';
import '../models/waste_entry.dart';

/// Fırın Defteri verilerine soyut erişim.
///
/// Üretim/fire mevcut tablolara direct (owner-only RLS) yazar; günlük
/// defter (ciro/not/kapanış) ve görevler SECURITY DEFINER RPC'lerle yazılır
/// (owner_id + bakery_id server-side auth.uid()).
abstract class BakeryRepository {
  // Production
  Future<List<ProductionEntry>> listProduction({DateTime? day});
  Future<void> addProduction(ProductionEntry entry);

  // Dealer (legacy panel görünümü)
  Future<List<DealerDeliveryEntry>> listDeliveries({DateTime? day});
  Future<void> addDelivery(DealerDeliveryEntry entry);

  // Waste
  Future<List<WasteEntry>> listWastes({DateTime? day});
  Future<void> addWaste(WasteEntry entry);

  // Aggregated
  Future<DailySummary> dailySummary(DateTime day);

  // ── Fırın Defteri V1 — günlük defter (ciro/not/kapanış) ──
  Future<BakeryDayBook?> dayBook(DateTime day);
  Future<void> upsertDayBook({
    required DateTime day,
    double? revenue,
    String? dayNote,
    String? cashNote,
  });
  Future<void> closeDay(DateTime day);
  Future<void> reopenDay(DateTime day);

  // ── Fırın Defteri V1 — bugünün işleri ──
  Future<List<BakeryTask>> tasks(DateTime day);
  Future<String> addTask({
    required DateTime day,
    required String title,
    String? category,
  });
  Future<void> setTaskDone(String taskId, bool done);
  Future<void> deleteTask(String taskId);

  // ── Fırın Defteri V1 — dönem raporu ──
  Future<LedgerRangeReport> rangeReport(DateTime from, DateTime to);

  /// Repository içeriği değiştiğinde yayın.
  /// Provider seviyesinde stream'lemek için.
  Stream<void> watch();
}
