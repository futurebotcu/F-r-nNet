import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/dealer.dart';
import '../models/dealer_driver.dart';
import '../models/dealer_note.dart';
import '../models/dealer_price.dart';
import '../models/dealer_transaction.dart';
import 'dealer_repository.dart';

/// Supabase V1.2 implementasyonu — tüm bayi/müşteri verileri kalıcı tablolarda.
///
/// **Tablo eşlemesi:**
/// - `dealers` (V1 + V1.2): name, contact_name, working_type, customer_type,
///   phone, district (area), is_active, note
/// - `dealer_deliveries` + `dealer_delivery_items`: type=delivery satırları için
///   (V1'den korundu; line_total trigger'ı çalışıyor)
/// - `dealer_transactions` (V1.2): type=payment/return/adjustment satırları
/// - `dealer_prices` (V1.2): bayi+ürün+valid_from
/// - `dealer_notes` (V1.2): bayi başına çoklu not
///
/// RLS owner-only — bypass yok. Hibrit local kullanım kaldırıldı.
class SupabaseDealerRepository implements DealerRepository {
  SupabaseDealerRepository(this._client);

  final sb.SupabaseClient _client;
  // Yapısal tick: bayi ekle/düzenle/aktif-pasif → liste/detay metadata.
  final StreamController<void> _changes = StreamController<void>.broadcast();
  // İçerik tick'i: hareket/fiyat/not → yalnız ilgili bayinin tx/bakiye slice'ı.
  // Bir hareket eklendiğinde TÜM bayi listesi + diğer bayilerin bakiyesi
  // recompute olmasın diye yapısaldan ayrıldı (grup modülü kalıbı).
  final StreamController<void> _contentChanges =
      StreamController<void>.broadcast();

  String? _cachedBakeryId;

  void _notify() => _changes.add(null);
  void _notifyContent() => _contentChanges.add(null);

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

  /// V1.3.5 — Client-side ID'ler (örn. `'d_<microseconds>'`) Supabase
  /// `uuid` sütunlarına `eq` query ile gönderildiğinde Postgres
  /// `22P02 invalid input syntax for type uuid` atıyor. Eq/lookup öncesi
  /// `looksLikeUuid` ile kontrol et; non-uuid → INSERT path (server
  /// `gen_random_uuid()` üretir, payload'a id koyma).
  ///
  /// Pattern RecipeRepository'deki `id.startsWith('r_')` ve
  /// WorkerRepository'deki `id.startsWith('l_')` ile aynı kategoride;
  /// dealer için genelleştirilmiş uuid kontrolü daha sağlam.
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// `value` Postgres uuid formatına uyuyorsa true.
  /// Public + static — test'lerden çağrılabilir.
  static bool looksLikeUuid(String value) => _uuidPattern.hasMatch(value);

  // ───────────────────────────────────────────────── Dealer mapping

  static const String _dealerColumns =
      'id, name, contact_name, phone, district, city, '
      'city_code, district_code, working_type, '
      'customer_type, is_active, note, created_at';

  Dealer _dealerFromRow(Map<String, dynamic> row) {
    final wtKey = row['working_type'] as String?;
    return Dealer(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? '',
      contactName: (row['contact_name'] as String?) ?? '',
      phone: (row['phone'] as String?) ?? '',
      area: (row['district'] as String?) ?? '',
      city: (row['city'] as String?) ?? '',
      cityCode: row['city_code'] as String?,
      districtCode: row['district_code'] as String?,
      workingType: wtKey != null
          ? DealerWorkingTypeLabel.fromPersistKey(wtKey)
          : DealerWorkingType.mixed,
      isActive: (row['is_active'] as bool?) ?? true,
      note: (row['note'] as String?) ?? '',
      customerType: DealerCustomerTypeLabel.fromPersistKey(
          row['customer_type'] as String?),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  // ───────────────────────────────────────────────── Dealers

  @override
  Future<List<Dealer>> listDealers({
    bool? activeOnly,
    DealerCustomerType? customerType,
  }) async {
    _requireUserId();
    var q = _client.from('dealers').select(_dealerColumns);
    if (activeOnly == true) {
      q = q.eq('is_active', true);
    }
    if (customerType != null) {
      q = q.eq('customer_type', customerType.persistKey);
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
        .select(_dealerColumns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _dealerFromRow(row);
  }

  @override
  Future<void> upsertDealer(Dealer dealer) async {
    final ownerId = _requireUserId();
    final bakeryId = await _ensureDefaultBakeryId();
    // M6B — dual-write: city/district label + city_code/district_code.
    final payload = <String, dynamic>{
      'owner_id': ownerId,
      'bakery_id': bakeryId,
      'name': dealer.name,
      if (dealer.contactName.isNotEmpty) 'contact_name': dealer.contactName,
      if (dealer.phone.isNotEmpty) 'phone': dealer.phone,
      if (dealer.area.isNotEmpty) 'district': dealer.area,
      if (dealer.city.isNotEmpty) 'city': dealer.city,
      if (dealer.cityCode != null && dealer.cityCode!.isNotEmpty)
        'city_code': dealer.cityCode,
      if (dealer.districtCode != null && dealer.districtCode!.isNotEmpty)
        'district_code': dealer.districtCode,
      'working_type': dealer.workingType.persistKey,
      'customer_type': dealer.customerType.persistKey,
      if (dealer.note.isNotEmpty) 'note': dealer.note,
      'is_active': dealer.isActive,
    };

    // V1.3.5 — Client `'d_<ts>'` ID'si uuid değil; doğrudan eq sorgusu
    // 22P02 atıyor. Önce uuid kontrolü yap; non-uuid ise INSERT direkt.
    if (!looksLikeUuid(dealer.id)) {
      // Yeni satır — server `gen_random_uuid()` üretir, payload'a id eklenmedi.
      await _client.from('dealers').insert(payload);
      _notify();
      return;
    }

    final existing = await _client
        .from('dealers')
        .select('id')
        .eq('id', dealer.id)
        .maybeSingle();
    if (existing == null) {
      // uuid format ama satır yok — yine insert (örn. id elle silinmiş).
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

  // ───────────────────────────────────────────────── Prices (V1.2 Supabase)

  static const String _priceColumns =
      'id, dealer_id, product_name, unit_price, valid_from, note, created_at';

  DealerPrice _priceFromRow(Map<String, dynamic> row) {
    return DealerPrice(
      id: row['id'] as String,
      dealerId: row['dealer_id'] as String,
      productName: (row['product_name'] as String?) ?? '',
      unitPrice: ((row['unit_price'] as num?) ?? 0).toDouble(),
      validFrom: DateTime.parse(row['valid_from'] as String),
      note: (row['note'] as String?) ?? '',
    );
  }

  @override
  Future<List<DealerPrice>> listPrices(String dealerId) async {
    _requireUserId();
    final rows = await _client
        .from('dealer_prices')
        .select(_priceColumns)
        .eq('dealer_id', dealerId)
        .order('valid_from', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_priceFromRow)
        .toList(growable: false);
  }

  @override
  Future<DealerPrice?> currentPriceFor({
    required String dealerId,
    required String productName,
  }) async {
    _requireUserId();
    final row = await _client
        .from('dealer_prices')
        .select(_priceColumns)
        .eq('dealer_id', dealerId)
        .eq('product_name', productName)
        .order('valid_from', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return _priceFromRow(row);
  }

  @override
  Future<void> addPrice(DealerPrice price) async {
    final ownerId = _requireUserId();
    await _client.from('dealer_prices').insert(<String, dynamic>{
      'owner_id': ownerId,
      'dealer_id': price.dealerId,
      'product_name': price.productName,
      'unit_price': price.unitPrice,
      'valid_from': _date(price.validFrom),
      if (price.note.isNotEmpty) 'note': price.note,
    });
    _notifyContent();
  }

  // ───────────────────────────────────────────────── Transactions

  /// dealer_deliveries+items → DealerTransaction(type=delivery)
  Future<List<DealerTransaction>> _fetchDeliveriesAsTransactions(
      {String? dealerId}) async {
    _requireUserId();
    var q = _client.from('dealer_delivery_items').select('''
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
        createdAt:
            dateStr != null ? DateTime.parse(dateStr) : DateTime.now(),
      );
    }).toList(growable: false);
  }

  /// dealer_transactions → DealerTransaction (payment/return/adjustment)
  Future<List<DealerTransaction>> _fetchExtrasAsTransactions(
      {String? dealerId}) async {
    _requireUserId();
    var q = _client.from('dealer_transactions').select(
          'id, dealer_id, type, product_name, quantity, unit_price, '
          'amount, payment_method, note, created_at',
        );
    if (dealerId != null) {
      q = q.eq('dealer_id', dealerId);
    }
    // delivery satırları parallel dealer_deliveries'ten okunduğu için
    // dealer_transactions sorgusunda delivery'i hariç tut.
    q = q.neq('type', 'delivery');
    final rows = await q.order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final typeKey = (row['type'] as String?) ?? 'adjustment';
      final pmKey = row['payment_method'] as String?;
      return DealerTransaction(
        id: row['id'] as String,
        dealerId: row['dealer_id'] as String,
        type: DealerTransactionTypeLabel.fromPersistKey(typeKey),
        productName: row['product_name'] as String?,
        quantity: (row['quantity'] as num?)?.toInt(),
        unitPrice: (row['unit_price'] as num?)?.toDouble(),
        amount: ((row['amount'] as num?) ?? 0).toDouble(),
        paymentMethod: pmKey != null
            ? DealerPaymentMethodLabel.fromPersistKey(pmKey)
            : null,
        note: (row['note'] as String?) ?? '',
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList(growable: false);
  }

  @override
  Future<List<DealerTransaction>> listTransactions(String dealerId) async {
    final results = await Future.wait<List<DealerTransaction>>(<Future<List<DealerTransaction>>>[
      _fetchDeliveriesAsTransactions(dealerId: dealerId),
      _fetchExtrasAsTransactions(dealerId: dealerId),
    ]);
    final out = <DealerTransaction>[...results[0], ...results[1]]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(out);
  }

  @override
  Future<List<DealerTransaction>> listAllTransactions() async {
    final results = await Future.wait<List<DealerTransaction>>(<Future<List<DealerTransaction>>>[
      _fetchDeliveriesAsTransactions(),
      _fetchExtrasAsTransactions(),
    ]);
    final out = <DealerTransaction>[...results[0], ...results[1]]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(out);
  }

  @override
  Future<void> addTransaction(DealerTransaction tx) async {
    if (tx.type == DealerTransactionType.delivery) {
      await _addDeliveryToSupabase(tx);
    } else {
      await _addExtraToSupabase(tx);
    }
    _notifyContent();
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

  Future<void> _addExtraToSupabase(DealerTransaction tx) async {
    final ownerId = _requireUserId();
    await _client.from('dealer_transactions').insert(<String, dynamic>{
      'owner_id': ownerId,
      'dealer_id': tx.dealerId,
      'type': tx.type.persistKey,
      if (tx.productName != null) 'product_name': tx.productName,
      if (tx.quantity != null) 'quantity': tx.quantity,
      if (tx.unitPrice != null) 'unit_price': tx.unitPrice,
      'amount': tx.amount,
      if (tx.paymentMethod != null)
        'payment_method': tx.paymentMethod!.persistKey,
      if (tx.note.isNotEmpty) 'note': tx.note,
    });
  }

  // ───────────────────────────────────────────────── Notes (V1.2 Supabase)

  static const String _noteColumns =
      'id, dealer_id, note, created_at';

  DealerNote _noteFromRow(Map<String, dynamic> row) {
    return DealerNote(
      id: row['id'] as String,
      dealerId: row['dealer_id'] as String,
      note: (row['note'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  Future<List<DealerNote>> listNotes(String dealerId) async {
    _requireUserId();
    final rows = await _client
        .from('dealer_notes')
        .select(_noteColumns)
        .eq('dealer_id', dealerId)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_noteFromRow)
        .toList(growable: false);
  }

  @override
  Future<void> addNote(DealerNote note) async {
    final ownerId = _requireUserId();
    await _client.from('dealer_notes').insert(<String, dynamic>{
      'owner_id': ownerId,
      'dealer_id': note.dealerId,
      'note': note.note,
    });
    _notifyContent();
  }

  // ───────────────────────────────────────────────── Şoförler (Sprint 2)

  static const String _driverColumns =
      'id, driver_user_id, name, phone, note, is_active, created_at';

  DealerDriver _driverFromRow(Map<String, dynamic> row, {int count = 0}) {
    return DealerDriver(
      id: row['id'] as String,
      driverUserId: (row['driver_user_id'] as String?) ?? '',
      name: (row['name'] as String?) ?? '',
      phone: (row['phone'] as String?) ?? '',
      note: (row['note'] as String?) ?? '',
      isActive: (row['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(row['created_at'] as String),
      assignedDealerCount: count,
    );
  }

  @override
  Future<List<DealerDriver>> listDrivers() async {
    _requireUserId();
    final rows = await _client
        .from('dealer_drivers')
        .select(_driverColumns)
        .order('name');
    final assigns = await _client
        .from('dealer_driver_assignments')
        .select('driver_id');
    final counts = <String, int>{};
    for (final a in (assigns as List).cast<Map<String, dynamic>>()) {
      final id = a['driver_id'] as String?;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => _driverFromRow(r, count: counts[r['id']] ?? 0))
        .toList(growable: false);
  }

  @override
  Future<DealerDriver?> getDriver(String driverId) async {
    _requireUserId();
    final row = await _client
        .from('dealer_drivers')
        .select(_driverColumns)
        .eq('id', driverId)
        .maybeSingle();
    if (row == null) return null;
    final ids = await assignedDealerIds(driverId);
    return _driverFromRow(row, count: ids.length);
  }

  @override
  Future<void> addDriver({
    required String driverUserId,
    required String name,
    String phone = '',
    String note = '',
  }) async {
    final ownerId = _requireUserId();
    try {
      await _client.from('dealer_drivers').insert(<String, dynamic>{
        'owner_id': ownerId,
        'driver_user_id': driverUserId,
        'name': name,
        if (phone.isNotEmpty) 'phone': phone,
        if (note.isNotEmpty) 'note': note,
      });
    } on sb.PostgrestException catch (e) {
      // 23503 FK ihlali → geçersiz profile id; 23505 unique → zaten ekli.
      if (e.code == '23503') {
        throw StateError('Geçerli bir FırınNet kullanıcı ID girin.');
      }
      if (e.code == '23505') {
        throw StateError('Bu kullanıcı zaten şoför olarak eklenmiş.');
      }
      rethrow;
    }
    _notify();
  }

  @override
  Future<void> updateDriver(DealerDriver driver) async {
    _requireUserId();
    await _client.from('dealer_drivers').update(<String, dynamic>{
      'name': driver.name,
      'phone': driver.phone,
      'note': driver.note,
      'is_active': driver.isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', driver.id);
    _notify();
  }

  @override
  Future<List<String>> assignedDealerIds(String driverId) async {
    _requireUserId();
    final rows = await _client
        .from('dealer_driver_assignments')
        .select('dealer_id')
        .eq('driver_id', driverId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['dealer_id'] as String)
        .toList(growable: false);
  }

  @override
  Future<void> setDriverAssignments({
    required String driverId,
    required List<String> dealerIds,
  }) async {
    final ownerId = _requireUserId();
    // Tam eşitleme: mevcut atamaları sil, yeni kümeyi ekle. DB trigger
    // cross-owner atamayı reddeder (ek güvenlik).
    await _client
        .from('dealer_driver_assignments')
        .delete()
        .eq('driver_id', driverId);
    if (dealerIds.isNotEmpty) {
      final unique = dealerIds.toSet().toList();
      await _client.from('dealer_driver_assignments').insert([
        for (final dealerId in unique)
          <String, dynamic>{
            'owner_id': ownerId,
            'driver_id': driverId,
            'dealer_id': dealerId,
          },
      ]);
    }
    _notify();
  }

  // ───────────────────────────────────────────────── Şoför read-only (Sprint 3)

  @override
  Future<bool> isAssignedDriver() async {
    final uid = _requireUserId();
    final row = await _client
        .from('dealer_drivers')
        .select('id')
        .eq('driver_user_id', uid)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<List<Dealer>> dealersAssignedToMe() async {
    final uid = _requireUserId();
    // Yalnız BENİM şoför kayıtlarımın atamaları (owner-only assignment'larla
    // karışmasın diye driver_id ile filtrele). RLS ek koruma sağlar.
    final driverRows = await _client
        .from('dealer_drivers')
        .select('id')
        .eq('driver_user_id', uid)
        .eq('is_active', true);
    final driverIds = (driverRows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['id'] as String)
        .toList();
    if (driverIds.isEmpty) return const [];
    final rows = await _client
        .from('dealer_driver_assignments')
        .select('dealer:dealers!inner($_dealerColumns)')
        .inFilter('driver_id', driverIds);
    final seen = <String>{};
    final out = <Dealer>[];
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final d = r['dealer'] as Map<String, dynamic>?;
      if (d == null) continue;
      final dealer = _dealerFromRow(d);
      if (seen.add(dealer.id)) out.add(dealer);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(out);
  }

  @override
  Stream<void> watch() => _changes.stream;

  @override
  Stream<void> watchContent() => _contentChanges.stream;

  /// Provider rebuild'inde (ör. login/logout → userId değişir) eski repo
  /// instance'ı atılır; broadcast controller'ları kapat (küçük leak önlenir).
  @override
  void dispose() {
    _changes.close();
    _contentChanges.close();
  }
}
