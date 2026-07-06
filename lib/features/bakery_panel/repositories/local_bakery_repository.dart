import 'dart:async';

import '../models/bakery_day_book.dart';
import '../models/bakery_task.dart';
import '../models/daily_summary.dart';
import '../models/dealer_delivery_entry.dart';
import '../models/ledger_range_report.dart';
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
    return List.unmodifiable(_wastes.where((e) => _sameDay(e.createdAt, day)));
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

  // ── Fırın Defteri V1 — günlük defter + görevler (server aynası) ──

  final Map<String, BakeryDayBook> _dayBooks = <String, BakeryDayBook>{};
  final List<BakeryTask> _tasks = <BakeryTask>[];
  int _idSeq = 0;

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Future<BakeryDayBook?> dayBook(DateTime day) async => _dayBooks[_dayKey(day)];

  @override
  Future<void> upsertDayBook({
    required DateTime day,
    double? revenue,
    String? dayNote,
    String? cashNote,
  }) async {
    final key = _dayKey(day);
    final existing = _dayBooks[key];
    // Server kuralının aynası: kapalı günde güncelleme reddedilir.
    if (existing != null && existing.isClosed) {
      throw StateError(
        'Bu gün kapatıldı. Değişiklik için önce günü yeniden aç.',
      );
    }
    _dayBooks[key] = BakeryDayBook(
      id: existing?.id ?? 'daybook-${++_idSeq}',
      businessDate: _dateOnly(day),
      revenueAmount: revenue ?? existing?.revenueAmount,
      dayNote: (dayNote != null && dayNote.trim().isNotEmpty)
          ? dayNote.trim()
          : (existing?.dayNote ?? ''),
      cashNote: (cashNote != null && cashNote.trim().isNotEmpty)
          ? cashNote.trim()
          : (existing?.cashNote ?? ''),
    );
    _notify();
  }

  @override
  Future<void> closeDay(DateTime day) async {
    final key = _dayKey(day);
    final existing = _dayBooks[key];
    _dayBooks[key] = BakeryDayBook(
      id: existing?.id ?? 'daybook-${++_idSeq}',
      businessDate: _dateOnly(day),
      revenueAmount: existing?.revenueAmount,
      dayNote: existing?.dayNote ?? '',
      cashNote: existing?.cashNote ?? '',
      isClosed: true,
      closedAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Future<void> reopenDay(DateTime day) async {
    final key = _dayKey(day);
    final existing = _dayBooks[key];
    if (existing == null) return;
    _dayBooks[key] = BakeryDayBook(
      id: existing.id,
      businessDate: existing.businessDate,
      revenueAmount: existing.revenueAmount,
      dayNote: existing.dayNote,
      cashNote: existing.cashNote,
    );
    _notify();
  }

  @override
  Future<List<BakeryTask>> tasks(DateTime day) async {
    final list =
        _tasks
            .where((t) => _sameDay(t.businessDate, day))
            .toList(growable: true)
          ..sort((a, b) {
            if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
            return a.sortOrder.compareTo(b.sortOrder);
          });
    return List.unmodifiable(list);
  }

  @override
  Future<String> addTask({
    required DateTime day,
    required String title,
    String? category,
  }) async {
    if (title.trim().isEmpty) throw StateError('Görev başlığını yaz.');
    final id = 'task-${++_idSeq}';
    _tasks.add(
      BakeryTask(
        id: id,
        businessDate: _dateOnly(day),
        title: title.trim(),
        category: category?.trim() ?? '',
        sortOrder: _tasks.length,
      ),
    );
    _notify();
    return id;
  }

  @override
  Future<void> setTaskDone(String taskId, bool done) async {
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i < 0) throw StateError('task not found');
    final t = _tasks[i];
    _tasks[i] = BakeryTask(
      id: t.id,
      businessDate: t.businessDate,
      title: t.title,
      category: t.category,
      note: t.note,
      isDone: done,
      sortOrder: t.sortOrder,
    );
    _notify();
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    _notify();
  }

  @override
  Future<LedgerRangeReport> rangeReport(DateTime from, DateTime to) async {
    bool inRange(DateTime d) {
      final x = _dateOnly(d);
      return !x.isBefore(_dateOnly(from)) && !x.isAfter(_dateOnly(to));
    }

    return LedgerRangeReport.build(
      from: from,
      to: to,
      production: _production.where((e) => inRange(e.createdAt)).toList(),
      wastes: _wastes.where((e) => inRange(e.createdAt)).toList(),
      dayBooks: _dayBooks.values.where((b) => inRange(b.businessDate)).toList(),
    );
  }

  @override
  Stream<void> watch() => _changes.stream;
}
