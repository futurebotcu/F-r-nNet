import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/dealer.dart';
import '../models/dealer_note.dart';
import '../models/dealer_price.dart';
import '../models/dealer_transaction.dart';
import 'dealer_repository.dart';
import 'local_dealer_repository.dart';

/// Hibrit V1 Supabase implementasyonu.
///
/// **Supabase'e gider:**
/// - dealers tablosu (CRUD)
/// - dealer_deliveries + dealer_delivery_items (yalnız `type=delivery` transaction'lar)
///
/// **Hâlâ in-memory (local-only, V1 kısıtı):**
/// - DealerPrice — Supabase'de tablo yok (V1.1 önerisi: `dealer_prices`).
/// - DealerNote (multi-note) — Supabase'de yalnız `dealers.note` tek text alanı.
/// - DealerTransaction(type=return/payment/adjustment) — Supabase'de ayrı
///   transaction tablosu yok; `dealer_deliveries.paid_amount` + items.returned_quantity
///   farklı bir modeli temsil eder.
///
/// **Uyarı:** local-only kayıtlar app restart'ında kaybolur. Üretim öncesi
/// V1.1 schema genişletmesi şart.
///
/// **Dealer modeli eşlemesi:**
/// - Flutter `Dealer.contactName / area / workingType` Supabase'de yok →
///   upsert sırasında atılır. Fetch sırasında default değerlerle doldurulur.
/// - `Dealer.area` → Supabase `district` alanına yazılır (en yakın eşleşme).
class SupabaseDealerRepository implements DealerRepository {
  SupabaseDealerRepository(this._client)
      : _localExtras = LocalDealerRepository(seed: false);

  final sb.SupabaseClient _client;
  final LocalDealerRepository _localExtras;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  String? _cachedBakeryId;
  StreamSubscription<void>? _extrasSub;

  void _notify() => _changes.add(null);

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    return id;
  }

  Future<String> _ensureDefaultBakeryId() async {
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
        .insert(<String, dynamic>{'owner_id': ownerId, 'name': 'Fırınım'})
        .select('id')
        .single();
    return _cachedBakeryId = created['id'] as String;
  }

  String _date(DateTime d) {
    final dd = d.toUtc();
    final mm = dd.month.toString().padLeft(2, '0');
    final day = dd.day.toString().padLeft(2, '0');
    return '${dd.year}-$mm-$day';
  }

  // ───────────────────────────────────────────────── Dealer mapping

  Dealer _dealerFromRow(Map<String, dynamic> row) {
    return Dealer(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? '',
      contactName: '', // Supabase'de yok
      phone: (row['phone'] as String?) ?? '',
      area: (row['district'] as String?) ?? (row['city'] as String?) ?? '',
      workingType: DealerWorkingType.mixed, // Supabase'de yok, default
      isActive: (row['is_active'] as bool?) ?? true,
      note: (row['note'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  // ───────────────────────────────────────────────── Dealers

  @override
  Future<List<Dealer>> listDealers({bool? activeOnly}) async {
    _requireUserId();
    var q = _client
        .from('dealers')
        .select('id, name, city, district, phone, note, is_active, created_at');
    if (activeOnly == true) {
      q = q.eq('is_active', true);
    }
    final rows = await q.order('name');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_dealerFromRow)
        .toList(growable: false);
  }

  @override
  Future<Dealer?> getDealer(String id) async {
    _requireUserId();
    final row = await _client
        .from('dealers')
        .select('id, name, city, district, phone, note, is_active, created_at')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _dealerFromRow(row);
  }

  @override
  Future<void> upsertDealer(Dealer dealer) async {
    final ownerId = _requireUserId();
    final bakeryId = await _ensureDefaultBakeryId();
    final payload = <String, dynamic>{
      'owner_id': ownerId,
      'bakery_id': bakeryId,
      'name': dealer.name,
      if (dealer.phone.isNotEmpty) 'phone': dealer.phone,
      if (dealer.area.isNotEmpty) 'district': dealer.area,
      if (dealer.note.isNotEmpty) 'note': dealer.note,
      'is_active': dealer.isActive,
    };

    final existing = await _client
        .from('dealers')
        .select('id')
        .eq('id', dealer.id)
        .maybeSingle();
    if (existing == null) {
      // Client tarafında üretilen 'd_{ts}' id'sini Supabase UUID'siyle değiştir.
      // ID atlanırsa Supabase gen_random_uuid() üretir; sadece yeni satırlar için.
      payload.remove('owner_id');
      payload['owner_id'] = ownerId;
      await _client.from('dealers').insert(payload);
    } else {
      await _client
          .from('dealers')
          .update(payload)
          .eq('id', dealer.id);
    }
    _notify();
  }

  @override
  Future<void> setActive(String dealerId, {required bool active}) async {
    _requireUserId();
    await _client
        .from('dealers')
        .update(<String, dynamic>{'is_active': active})
        .eq('id', dealerId);
    _notify();
  }

  // ───────────────────────────────────────────────── Prices (local-only)
  //
  // Supabase V1 schema'sında dealer_prices tablosu yok. V1.1 önerisi açık.

  @override
  Future<List<DealerPrice>> listPrices(String dealerId) =>
      _localExtras.listPrices(dealerId);

  @override
  Future<DealerPrice?> currentPriceFor({
    required String dealerId,
    required String productName,
  }) =>
      _localExtras.currentPriceFor(
        dealerId: dealerId,
        productName: productName,
      );

  @override
  Future<void> addPrice(DealerPrice price) async {
    await _localExtras.addPrice(price);
    _notify();
  }

  // ───────────────────────────────────────────────── Transactions

  /// Supabase `dealer_deliveries`+items satırlarını Flutter DealerTransaction
  /// (type=delivery) listesine map eder.
  Future<List<DealerTransaction>> _fetchDeliveriesAsTransactions(
      {String? dealerId}) async {
    _requireUserId();
    var q = _client
        .from('dealer_delivery_items')
        .select('''
          id, product_name, quantity, unit_price, line_total, created_at,
          delivery:dealer_deliveries!inner(id, dealer_id, delivery_date, note)
        ''');
    if (dealerId != null) {
      q = q.eq('delivery.dealer_id', dealerId);
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final delivery = row['delivery'] as Map<String, dynamic>?;
      final did = (delivery?['dealer_id'] as String?) ?? '';
      final dateStr = (delivery?['delivery_date'] as String?) ??
          (row['created_at'] as String?);
      return DealerTransaction(
        id: row['id'] as String,
        dealerId: did,
        type: DealerTransactionType.delivery,
        productName: row['product_name'] as String?,
        quantity: (row['quantity'] as num?)?.toInt(),
        unitPrice: (row['unit_price'] as num?)?.toDouble(),
        amount: ((row['line_total'] as num?) ?? 0).toDouble(),
        note: (delivery?['note'] as String?) ?? '',
        createdAt: dateStr != null ? DateTime.parse(dateStr) : DateTime.now(),
      );
    }).toList(growable: false);
  }

  @override
  Future<List<DealerTransaction>> listTransactions(String dealerId) async {
    final deliveries = await _fetchDeliveriesAsTransactions(dealerId: dealerId);
    final extras = await _localExtras.listTransactions(dealerId);
    final out = <DealerTransaction>[...deliveries, ...extras]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(out);
  }

  @override
  Future<List<DealerTransaction>> listAllTransactions() async {
    final deliveries = await _fetchDeliveriesAsTransactions();
    final extras = await _localExtras.listAllTransactions();
    final out = <DealerTransaction>[...deliveries, ...extras]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(out);
  }

  @override
  Future<void> addTransaction(DealerTransaction tx) async {
    if (tx.type == DealerTransactionType.delivery) {
      await _addDeliveryToSupabase(tx);
    } else {
      // payment / return / adjustment → şimdilik local-only (V1 kısıtı).
      // Üretim öncesi V1.1 schema önerisi: dealer_transactions tablosu.
      await _localExtras.addTransaction(tx);
    }
    _notify();
  }

  Future<void> _addDeliveryToSupabase(DealerTransaction tx) async {
    final ownerId = _requireUserId();
    final bakeryId = await _ensureDefaultBakeryId();

    final parent = await _client
        .from('dealer_deliveries')
        .insert(<String, dynamic>{
          'owner_id': ownerId,
          'bakery_id': bakeryId,
          'dealer_id': tx.dealerId,
          'delivery_date': _date(tx.createdAt),
          'paid_amount': 0,
          if (tx.note.isNotEmpty) 'note': tx.note,
        })
        .select('id')
        .single();
    final deliveryId = parent['id'] as String;

    await _client.from('dealer_delivery_items').insert(<String, dynamic>{
      'delivery_id': deliveryId,
      'owner_id': ownerId,
      'product_name': tx.productName ?? '',
      'quantity': tx.quantity ?? 0,
      'unit_price': tx.unitPrice ?? 0,
    });
  }

  // ───────────────────────────────────────────────── Notes (local-only)

  @override
  Future<List<DealerNote>> listNotes(String dealerId) =>
      _localExtras.listNotes(dealerId);

  @override
  Future<void> addNote(DealerNote note) async {
    await _localExtras.addNote(note);
    _notify();
  }

  // ───────────────────────────────────────────────── Stream

  @override
  Stream<void> watch() {
    // Local extras değişimlerini de Supabase notify'ına aktarmak için
    // tek seferlik subscription kurulur.
    _extrasSub ??= _localExtras.watch().listen((_) => _notify());
    return _changes.stream;
  }
}
