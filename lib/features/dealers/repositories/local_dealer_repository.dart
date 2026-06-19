import 'dart:async';

import '../models/dealer.dart';
import '../models/dealer_driver.dart';
import '../models/dealer_note.dart';
import '../models/dealer_price.dart';
import '../models/dealer_transaction.dart';
import 'dealer_repository.dart';

/// Bellek içi dealer repository. Demo seed ile gelir; uygulama yeniden
/// açıldığında veriler sıfırlanır — V1 için yeterli.
///
/// TODO(v2): SupabaseDealerRepository eklenecek.
/// UI ve service katmanı bu sınıfa değil, [DealerRepository] arayüzüne bağlı.
class LocalDealerRepository implements DealerRepository {
  LocalDealerRepository({bool seed = true, this.currentUserId}) {
    if (seed) _seed();
  }

  /// Test/demo: "ben kimim" — şoför read-only senaryosunu Local'de simüle eder.
  /// Production guest yolunda null (gerçek auth Supabase'de) → şoför değil.
  final String? currentUserId;

  final List<Dealer> _dealers = <Dealer>[];
  final List<DealerPrice> _prices = <DealerPrice>[];
  final List<DealerTransaction> _transactions = <DealerTransaction>[];
  final List<DealerNote> _notes = <DealerNote>[];
  final List<DealerDriver> _drivers = <DealerDriver>[];
  // driverId → atanmış dealerId kümesi.
  final Map<String, Set<String>> _assignments = <String, Set<String>>{};
  int _driverSeq = 0;

  final StreamController<void> _changes =
      StreamController<void>.broadcast();

  void _notify() => _changes.add(null);

  // ─────────────────────────────────────── Dealers

  @override
  Future<List<Dealer>> listDealers({
    bool? activeOnly,
    DealerCustomerType? customerType,
  }) async {
    Iterable<Dealer> src = _dealers;
    if (activeOnly == true) src = src.where((d) => d.isActive);
    if (customerType != null) {
      src = src.where((d) => d.customerType == customerType);
    }
    final out = src.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(out);
  }

  @override
  Future<Dealer?> getDealer(String id) async {
    for (final d in _dealers) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<void> upsertDealer(Dealer dealer) async {
    final i = _dealers.indexWhere((d) => d.id == dealer.id);
    if (i == -1) {
      _dealers.add(dealer);
    } else {
      _dealers[i] = dealer;
    }
    _notify();
  }

  @override
  Future<void> setActive(String dealerId, {required bool active}) async {
    final i = _dealers.indexWhere((d) => d.id == dealerId);
    if (i == -1) return;
    _dealers[i] = _dealers[i].copyWith(isActive: active);
    _notify();
  }

  // ─────────────────────────────────────── Prices

  @override
  Future<List<DealerPrice>> listPrices(String dealerId) async {
    final out = _prices.where((p) => p.dealerId == dealerId).toList()
      ..sort((a, b) => b.validFrom.compareTo(a.validFrom));
    return List.unmodifiable(out);
  }

  @override
  Future<DealerPrice?> currentPriceFor({
    required String dealerId,
    required String productName,
  }) async {
    DealerPrice? winner;
    for (final p in _prices) {
      if (p.dealerId != dealerId) continue;
      if (p.productName != productName) continue;
      if (winner == null || p.validFrom.isAfter(winner.validFrom)) {
        winner = p;
      }
    }
    return winner;
  }

  @override
  Future<void> addPrice(DealerPrice price) async {
    _prices.add(price);
    _notify();
  }

  // ─────────────────────────────────────── Transactions

  @override
  Future<List<DealerTransaction>> listTransactions(String dealerId) async {
    final out =
        _transactions.where((t) => t.dealerId == dealerId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(out);
  }

  @override
  Future<List<DealerTransaction>> listAllTransactions() async {
    final out = List<DealerTransaction>.from(_transactions)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(out);
  }

  @override
  Future<void> addTransaction(DealerTransaction tx) async {
    _transactions.add(tx);
    _notify();
  }

  // ─────────────────────────────────────── Notes

  @override
  Future<List<DealerNote>> listNotes(String dealerId) async {
    final out = _notes.where((n) => n.dealerId == dealerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(out);
  }

  @override
  Future<void> addNote(DealerNote note) async {
    _notes.add(note);
    _notify();
  }

  // ─────────────────────────────────────── Şoförler

  @override
  Future<List<DealerDriver>> listDrivers() async {
    final out = _drivers
        .map((d) => d.copyWith(
            assignedDealerCount: (_assignments[d.id] ?? const {}).length))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(out);
  }

  @override
  Future<DealerDriver?> getDriver(String driverId) async {
    for (final d in _drivers) {
      if (d.id == driverId) {
        return d.copyWith(
            assignedDealerCount: (_assignments[d.id] ?? const {}).length);
      }
    }
    return null;
  }

  @override
  Future<void> addDriver({
    required String driverUserId,
    required String name,
    String phone = '',
    String note = '',
  }) async {
    if (_drivers.any((d) => d.driverUserId == driverUserId)) {
      throw StateError('Bu kullanıcı zaten şoför olarak eklenmiş.');
    }
    _drivers.add(DealerDriver(
      id: 'drv_${++_driverSeq}',
      driverUserId: driverUserId,
      name: name,
      phone: phone,
      note: note,
      createdAt: DateTime.now(),
    ));
    _notify();
  }

  @override
  Future<void> updateDriver(DealerDriver driver) async {
    final i = _drivers.indexWhere((d) => d.id == driver.id);
    if (i == -1) return;
    _drivers[i] = _drivers[i].copyWith(
      name: driver.name,
      phone: driver.phone,
      note: driver.note,
      isActive: driver.isActive,
    );
    _notify();
  }

  @override
  Future<List<String>> assignedDealerIds(String driverId) async {
    return List.unmodifiable(_assignments[driverId] ?? const <String>{});
  }

  @override
  Future<void> setDriverAssignments({
    required String driverId,
    required List<String> dealerIds,
  }) async {
    // Yalnız mevcut (patronun kendi) bayileri kabul et.
    final valid = dealerIds.where((id) => _dealers.any((d) => d.id == id));
    _assignments[driverId] = valid.toSet();
    _notify();
  }

  @override
  Future<bool> isAssignedDriver() async {
    if (currentUserId == null) return false;
    return _drivers
        .any((d) => d.driverUserId == currentUserId && d.isActive);
  }

  @override
  Future<List<Dealer>> dealersAssignedToMe() async {
    if (currentUserId == null) return const [];
    final myDriverIds = _drivers
        .where((d) => d.driverUserId == currentUserId && d.isActive)
        .map((d) => d.id)
        .toSet();
    final dealerIds = <String>{};
    for (final id in myDriverIds) {
      dealerIds.addAll(_assignments[id] ?? const <String>{});
    }
    final out = _dealers.where((d) => dealerIds.contains(d.id)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(out);
  }

  @override
  Stream<void> watch() => _changes.stream;

  // Local in-memory'de storm yok; içerik tick'i yapısalla aynı stream'i
  // paylaşır (guest/demo). Provider'lar yine ayrı izler, davranış korunur.
  @override
  Stream<void> watchContent() => _changes.stream;

  @override
  void dispose() => _changes.close();

  // ─────────────────────────────────────── Demo seed

  void _seed() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9, 30);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDays = today.subtract(const Duration(days: 2));
    final fiveDays = today.subtract(const Duration(days: 5));

    final hamdi = Dealer(
      id: 'd_hamdi',
      name: 'Hamdi Bakkal',
      contactName: 'Hamdi Yıldız',
      phone: '0532 555 14 22',
      area: 'Konya · Selçuklu',
      workingType: DealerWorkingType.term,
      note: 'Sabah erken teslim — 06:30',
      createdAt: now.subtract(const Duration(days: 120)),
    );
    final mehmet = Dealer(
      id: 'd_mehmet',
      name: 'Mehmet Market',
      contactName: 'Mehmet Aktaş',
      phone: '0533 444 18 90',
      area: 'Konya · Meram',
      workingType: DealerWorkingType.mixed,
      note: 'Cuma günleri tahsilat',
      createdAt: now.subtract(const Duration(days: 200)),
    );
    final pideEvi = Dealer(
      id: 'd_pide',
      name: 'Köşe Pide Evi',
      contactName: 'Recep Usta',
      phone: '0534 322 09 11',
      area: 'Konya · Karatay',
      workingType: DealerWorkingType.cash,
      createdAt: now.subtract(const Duration(days: 75)),
    );
    final pasifBakkal = Dealer(
      id: 'd_pasif',
      name: 'Şenel Büfe',
      contactName: 'Ahmet Şenel',
      phone: '',
      area: 'Konya · Selçuklu',
      workingType: DealerWorkingType.term,
      isActive: false,
      note: 'İşi bıraktı, geçmiş kayıt arşivde',
      createdAt: now.subtract(const Duration(days: 400)),
    );
    _dealers.addAll([hamdi, mehmet, pideEvi, pasifBakkal]);

    // Bayilere özel fiyatlar
    _prices.addAll([
      DealerPrice(
        id: 'p1',
        dealerId: hamdi.id,
        productName: 'Ekmek',
        unitPrice: 8.5,
        validFrom: now.subtract(const Duration(days: 30)),
      ),
      DealerPrice(
        id: 'p2',
        dealerId: hamdi.id,
        productName: 'Simit',
        unitPrice: 9,
        validFrom: now.subtract(const Duration(days: 30)),
      ),
      DealerPrice(
        id: 'p3',
        dealerId: mehmet.id,
        productName: 'Ekmek',
        unitPrice: 8,
        validFrom: now.subtract(const Duration(days: 60)),
      ),
      DealerPrice(
        id: 'p4',
        dealerId: mehmet.id,
        productName: 'Pide',
        unitPrice: 18,
        validFrom: now.subtract(const Duration(days: 14)),
      ),
      DealerPrice(
        id: 'p5',
        dealerId: pideEvi.id,
        productName: 'Pide',
        unitPrice: 20,
        validFrom: now.subtract(const Duration(days: 7)),
      ),
    ]);

    // Geçmiş işlemler
    _transactions.addAll([
      // Hamdi: birkaç gün boyunca teslim, kısmi ödeme
      DealerTransaction(
        id: 't1',
        dealerId: hamdi.id,
        type: DealerTransactionType.delivery,
        productName: 'Ekmek',
        quantity: 80,
        unitPrice: 8.5,
        amount: 80 * 8.5,
        note: 'Sabah teslim',
        createdAt: fiveDays,
      ),
      DealerTransaction(
        id: 't2',
        dealerId: hamdi.id,
        type: DealerTransactionType.delivery,
        productName: 'Simit',
        quantity: 40,
        unitPrice: 9,
        amount: 40 * 9,
        createdAt: twoDays,
      ),
      DealerTransaction(
        id: 't3',
        dealerId: hamdi.id,
        type: DealerTransactionType.returned,
        productName: 'Ekmek',
        quantity: 6,
        unitPrice: 8.5,
        amount: 6 * 8.5,
        note: 'Akşam kalan, iade',
        createdAt: twoDays.add(const Duration(hours: 8)),
      ),
      DealerTransaction(
        id: 't4',
        dealerId: hamdi.id,
        type: DealerTransactionType.payment,
        amount: 500,
        paymentMethod: DealerPaymentMethod.cash,
        note: 'Kısmi tahsilat',
        createdAt: yesterday,
      ),
      DealerTransaction(
        id: 't5',
        dealerId: hamdi.id,
        type: DealerTransactionType.delivery,
        productName: 'Ekmek',
        quantity: 60,
        unitPrice: 8.5,
        amount: 60 * 8.5,
        createdAt: today,
      ),
      // Mehmet: temiz hesap — teslim + tam ödeme
      DealerTransaction(
        id: 't6',
        dealerId: mehmet.id,
        type: DealerTransactionType.delivery,
        productName: 'Ekmek',
        quantity: 120,
        unitPrice: 8,
        amount: 120 * 8,
        createdAt: yesterday,
      ),
      DealerTransaction(
        id: 't7',
        dealerId: mehmet.id,
        type: DealerTransactionType.delivery,
        productName: 'Pide',
        quantity: 25,
        unitPrice: 18,
        amount: 25 * 18,
        createdAt: today,
      ),
      DealerTransaction(
        id: 't8',
        dealerId: mehmet.id,
        type: DealerTransactionType.payment,
        amount: 960,
        paymentMethod: DealerPaymentMethod.transfer,
        note: 'Cuma tahsilatı',
        createdAt: yesterday.add(const Duration(hours: 4)),
      ),
      // Pide Evi: peşin → bakiye 0
      DealerTransaction(
        id: 't9',
        dealerId: pideEvi.id,
        type: DealerTransactionType.delivery,
        productName: 'Pide',
        quantity: 30,
        unitPrice: 20,
        amount: 30 * 20,
        createdAt: today,
      ),
      DealerTransaction(
        id: 't10',
        dealerId: pideEvi.id,
        type: DealerTransactionType.payment,
        amount: 600,
        paymentMethod: DealerPaymentMethod.cash,
        note: 'Peşin tahsilat',
        createdAt: today.add(const Duration(minutes: 15)),
      ),
    ]);

    _notes.addAll([
      DealerNote(
        id: 'n1',
        dealerId: hamdi.id,
        note: 'Cumartesi öğleden sonra erken kapanır.',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      DealerNote(
        id: 'n2',
        dealerId: mehmet.id,
        note: 'Fatura ister, KDV dahil yazılacak.',
        createdAt: now.subtract(const Duration(days: 30)),
      ),
    ]);
  }
}
