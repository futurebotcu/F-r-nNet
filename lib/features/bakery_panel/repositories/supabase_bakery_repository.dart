import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/bakery_day_book.dart';
import '../models/bakery_task.dart';
import '../models/daily_summary.dart';
import '../models/dealer_delivery_entry.dart';
import '../models/ledger_range_report.dart';
import '../models/production_entry.dart';
import '../models/waste_entry.dart';
import 'bakery_repository.dart';

/// Supabase implementasyonu — Ticari kullanıcının fırın panel kayıtlarını
/// `production_entries`, `waste_entries`, `dealer_deliveries`+items tablolarına
/// yazar/okur.
///
/// **Sözleşme:**
/// - Tüm INSERT'lerde `owner_id = auth.uid()`, `bakery_id = ensureDefaultBakery()`.
/// - RLS policy'leri authenticated rolünde owner_id = auth.uid() filtresiyle
///   uygular — bu sınıf RLS'i bypass etmez.
/// - `addDelivery(DealerDeliveryEntry)` legacy V1 ekranı içindir; modern akış
///   `SupabaseDealerRepository.addTransaction(type=delivery)` üzerinden gider.
///   Çağrılırsa StateError fırlatır (UI Türkçe mesaja çevirir).
class SupabaseBakeryRepository implements BakeryRepository {
  SupabaseBakeryRepository(this._client);

  final sb.SupabaseClient _client;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  String? _cachedBakeryId;

  void _notify() => _changes.add(null);

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    return id;
  }

  /// Kullanıcı için varsayılan fırın işletmesini garanti eder.
  /// İlk operasyonda fetch+create yapar; sonraki çağrılarda cache döner.
  Future<String> ensureDefaultBakery({String? name, String? city}) async {
    if (_cachedBakeryId != null) return _cachedBakeryId!;
    final ownerId = _requireUserId();

    final existing = await _client
        .from('bakeries')
        .select('id')
        .eq('owner_id', ownerId)
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      return _cachedBakeryId = existing['id'] as String;
    }

    final created = await _client
        .from('bakeries')
        .insert(<String, dynamic>{
          'owner_id': ownerId,
          'name': (name == null || name.trim().isEmpty)
              ? 'Fırınım'
              : name.trim(),
          if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        })
        .select('id')
        .single();
    _notify();
    return _cachedBakeryId = created['id'] as String;
  }

  /// Kullanıcının YEREL günü (date-only). Eski sürüm toUtc() kullanıyordu —
  /// TR'de gece 00:00–03:00 arası girilen kayıt bir önceki güne yazılıyordu;
  /// Fırın Defteri V1 ile yerel güne sabitlendi.
  String _date(DateTime d) {
    final local = d.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$day';
  }

  // ───────────────────────── ProductionEntry mapping

  ProductionEntry _prodFromRow(Map<String, dynamic> row) {
    return ProductionEntry(
      id: row['id'] as String,
      product: (row['product_name'] as String?) ?? '',
      quantity: (row['quantity'] as num?)?.toInt() ?? 0,
      note: (row['note'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  Future<List<ProductionEntry>> listProduction({DateTime? day}) async {
    final ownerId = _requireUserId();
    var q = _client
        .from('production_entries')
        .select('id, product_name, quantity, note, production_date, created_at')
        .eq('owner_id', ownerId);
    if (day != null) {
      q = q.eq('production_date', _date(day));
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_prodFromRow)
        .toList(growable: false);
  }

  @override
  Future<void> addProduction(ProductionEntry entry) async {
    final ownerId = _requireUserId();
    final bakeryId = await ensureDefaultBakery();
    await _client.from('production_entries').insert(<String, dynamic>{
      'owner_id': ownerId,
      'bakery_id': bakeryId,
      'product_name': entry.product,
      'quantity': entry.quantity,
      'production_date': _date(entry.createdAt),
      if (entry.note.isNotEmpty) 'note': entry.note,
    });
    _notify();
  }

  // ───────────────────────── WasteEntry mapping

  WasteEntry _wasteFromRow(Map<String, dynamic> row) {
    return WasteEntry(
      id: row['id'] as String,
      product: (row['product_name'] as String?) ?? '',
      quantity: (row['quantity'] as num?)?.toInt() ?? 0,
      unitValue: ((row['unit_cost'] as num?) ?? 0).toDouble(),
      note: (row['note'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
      reason: WasteReasonMeta.fromKey(row['waste_type'] as String?),
    );
  }

  @override
  Future<List<WasteEntry>> listWastes({DateTime? day}) async {
    final ownerId = _requireUserId();
    var q = _client
        .from('waste_entries')
        .select(
          'id, product_name, quantity, unit_cost, estimated_loss, waste_type, waste_date, note, created_at',
        )
        .eq('owner_id', ownerId);
    if (day != null) {
      q = q.eq('waste_date', _date(day));
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_wasteFromRow)
        .toList(growable: false);
  }

  @override
  Future<void> addWaste(WasteEntry entry) async {
    final ownerId = _requireUserId();
    final bakeryId = await ensureDefaultBakery();
    await _client.from('waste_entries').insert(<String, dynamic>{
      'owner_id': ownerId,
      'bakery_id': bakeryId,
      'product_name': entry.product,
      'quantity': entry.quantity,
      'unit_cost': entry.unitValue,
      'waste_type': entry.reason.persistKey,
      'waste_date': _date(entry.createdAt),
      if (entry.note.isNotEmpty) 'note': entry.note,
    });
    _notify();
  }

  // ───────────────────────── DealerDelivery mapping (read-only)

  @override
  Future<List<DealerDeliveryEntry>> listDeliveries({DateTime? day}) async {
    final ownerId = _requireUserId();
    // Items + parent join: parent date + dealer adı için dealers join.
    var q = _client
        .from('dealer_delivery_items')
        .select('''
          id, product_name, quantity, unit_price, line_total, created_at,
          delivery:dealer_deliveries!inner(id, delivery_date, dealer:dealers(id, name))
        ''')
        .eq('owner_id', ownerId);
    if (day != null) {
      q = q.eq('delivery.delivery_date', _date(day));
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((row) {
          final delivery = row['delivery'] as Map<String, dynamic>?;
          final dealer = delivery?['dealer'] as Map<String, dynamic>?;
          final dateStr = delivery?['delivery_date'] as String?;
          return DealerDeliveryEntry(
            id: row['id'] as String,
            dealerName: (dealer?['name'] as String?) ?? '',
            product: (row['product_name'] as String?) ?? '',
            quantity: (row['quantity'] as num?)?.toInt() ?? 0,
            unitPrice: ((row['unit_price'] as num?) ?? 0).toDouble(),
            deliveryDate: dateStr != null
                ? DateTime.parse(dateStr)
                : DateTime.now(),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> addDelivery(DealerDeliveryEntry entry) async {
    // Bakery panel'in legacy V1 "Bayiye Ver" akışı. Modern akış Bayi Paneli
    // üzerinden gider (SupabaseDealerRepository.addTransaction(delivery=…)),
    // dealer_id ve dealer kaydı orada yönetilir. Bu çağrı yapılırsa kullanıcıyı
    // doğru ekrana yönlendir.
    throw StateError(
      'Bu ekran artık kullanılmıyor. Bayi Yönetimi → bayi seç → "Ürün Ver" üzerinden teslimat ekleyin.',
    );
  }

  // ───────────────────────── DailySummary builder

  @override
  Future<DailySummary> dailySummary(DateTime day) async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      listProduction(day: day),
      listDeliveries(day: day),
      listWastes(day: day),
    ]);
    return DailySummary(
      day: day,
      production: results[0] as List<ProductionEntry>,
      deliveries: results[1] as List<DealerDeliveryEntry>,
      wastes: results[2] as List<WasteEntry>,
    );
  }

  // ───────────────────────── Fırın Defteri V1 — günlük defter + görevler
  //
  // Yazma yolları SECURITY DEFINER RPC'lerdir: owner_id + bakery_id
  // SERVER-SIDE auth.uid() üzerinden set edilir (client bakery_id gönderemez).

  @override
  Future<BakeryDayBook?> dayBook(DateTime day) async {
    final ownerId = _requireUserId();
    final rows = await _client
        .from('bakery_day_books')
        .select(
          'id, business_date, revenue_amount, cash_note, day_note, status, '
          'closed_at',
        )
        .eq('owner_id', ownerId)
        .eq('business_date', _date(day))
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return BakeryDayBook.fromRow(list.first);
  }

  @override
  Future<void> upsertDayBook({
    required DateTime day,
    double? revenue,
    String? dayNote,
    String? cashNote,
  }) async {
    _requireUserId();
    try {
      await _client.rpc(
        'upsert_bakery_day_book',
        params: <String, dynamic>{
          'p_business_date': _date(day),
          if (revenue != null) 'p_revenue_amount': revenue,
          if (dayNote != null && dayNote.trim().isNotEmpty)
            'p_day_note': dayNote.trim(),
          if (cashNote != null && cashNote.trim().isNotEmpty)
            'p_cash_note': cashNote.trim(),
        },
      );
      _notify();
    } on sb.PostgrestException catch (e) {
      if (e.message.contains('day closed')) {
        throw StateError(
          'Bu gün kapatıldı. Değişiklik için önce günü yeniden aç.',
        );
      }
      throw StateError('Kayıt yapılamadı. Tekrar dene.');
    }
  }

  @override
  Future<void> closeDay(DateTime day) async {
    _requireUserId();
    await _client.rpc(
      'close_bakery_day',
      params: <String, dynamic>{'p_business_date': _date(day)},
    );
    _notify();
  }

  @override
  Future<void> reopenDay(DateTime day) async {
    _requireUserId();
    await _client.rpc(
      'reopen_bakery_day',
      params: <String, dynamic>{'p_business_date': _date(day)},
    );
    _notify();
  }

  @override
  Future<List<BakeryTask>> tasks(DateTime day) async {
    final ownerId = _requireUserId();
    final rows = await _client
        .from('bakery_tasks')
        .select('id, business_date, title, category, note, is_done, sort_order')
        .eq('owner_id', ownerId)
        .eq('business_date', _date(day))
        .order('is_done')
        .order('sort_order')
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(BakeryTask.fromRow)
        .toList(growable: false);
  }

  @override
  Future<String> addTask({
    required DateTime day,
    required String title,
    String? category,
  }) async {
    _requireUserId();
    final id = await _client.rpc(
      'create_bakery_task',
      params: <String, dynamic>{
        'p_business_date': _date(day),
        'p_title': title.trim(),
        if (category != null && category.trim().isNotEmpty)
          'p_category': category.trim(),
      },
    );
    _notify();
    return id as String;
  }

  @override
  Future<void> setTaskDone(String taskId, bool done) async {
    _requireUserId();
    await _client.rpc(
      'update_bakery_task',
      params: <String, dynamic>{'p_task_id': taskId, 'p_is_done': done},
    );
    _notify();
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _requireUserId();
    await _client.rpc(
      'delete_bakery_task',
      params: <String, dynamic>{'p_task_id': taskId},
    );
    _notify();
  }

  @override
  Future<LedgerRangeReport> rangeReport(DateTime from, DateTime to) async {
    final ownerId = _requireUserId();
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _client
          .from('production_entries')
          .select('id, product_name, quantity, note, created_at')
          .eq('owner_id', ownerId)
          .gte('production_date', _date(from))
          .lte('production_date', _date(to)),
      _client
          .from('waste_entries')
          .select(
            'id, product_name, quantity, unit_cost, waste_type, note, '
            'created_at',
          )
          .eq('owner_id', ownerId)
          .gte('waste_date', _date(from))
          .lte('waste_date', _date(to)),
      _client
          .from('bakery_day_books')
          .select(
            'id, business_date, revenue_amount, cash_note, day_note, status, '
            'closed_at',
          )
          .eq('owner_id', ownerId)
          .gte('business_date', _date(from))
          .lte('business_date', _date(to)),
    ]);
    return LedgerRangeReport.build(
      from: from,
      to: to,
      production: (results[0] as List)
          .cast<Map<String, dynamic>>()
          .map(_prodFromRow)
          .toList(growable: false),
      wastes: (results[1] as List)
          .cast<Map<String, dynamic>>()
          .map(_wasteFromRow)
          .toList(growable: false),
      dayBooks: (results[2] as List)
          .cast<Map<String, dynamic>>()
          .map(BakeryDayBook.fromRow)
          .toList(growable: false),
    );
  }

  @override
  Stream<void> watch() => _changes.stream;
}
