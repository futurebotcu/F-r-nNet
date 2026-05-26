import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/daily_summary.dart';
import '../models/dealer_delivery_entry.dart';
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
          'name': (name == null || name.trim().isEmpty) ? 'Fırınım' : name.trim(),
          if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        })
        .select('id')
        .single();
    _notify();
    return _cachedBakeryId = created['id'] as String;
  }

  String _date(DateTime d) {
    final dd = d.toUtc();
    final mm = dd.month.toString().padLeft(2, '0');
    final day = dd.day.toString().padLeft(2, '0');
    return '${dd.year}-$mm-$day';
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
    );
  }

  @override
  Future<List<WasteEntry>> listWastes({DateTime? day}) async {
    final ownerId = _requireUserId();
    var q = _client
        .from('waste_entries')
        .select(
            'id, product_name, quantity, unit_cost, estimated_loss, waste_type, waste_date, note, created_at')
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
      'waste_type': 'waste',
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
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final delivery = row['delivery'] as Map<String, dynamic>?;
      final dealer = delivery?['dealer'] as Map<String, dynamic>?;
      final dateStr = delivery?['delivery_date'] as String?;
      return DealerDeliveryEntry(
        id: row['id'] as String,
        dealerName: (dealer?['name'] as String?) ?? '',
        product: (row['product_name'] as String?) ?? '',
        quantity: (row['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: ((row['unit_price'] as num?) ?? 0).toDouble(),
        deliveryDate:
            dateStr != null ? DateTime.parse(dateStr) : DateTime.now(),
      );
    }).toList(growable: false);
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

  @override
  Stream<void> watch() => _changes.stream;
}
