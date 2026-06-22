import '../models/dealer.dart';
import '../models/dealer_driver.dart';
import '../models/dealer_driver_invite.dart';
import '../models/dealer_note.dart';
import '../models/dealer_price.dart';
import '../models/dealer_transaction.dart';
import 'dealer_repository.dart';
import 'driver_permission.dart';

/// Şoför-scoped repository decorator (fix/driver-normal-dealer-shell).
///
/// Bireysel şoför `/dealers` açınca **normal** [DealerShellScreen] +
/// [DealerDetailScreen] + normal teslimat/tahsilat/iade formları aynen
/// kullanılır. Bu decorator yalnız iki şey yapar:
///   1) Veri kapsamını şoföre **atanmış bayilere** daraltır
///      ([listDealers] → `dealersAssignedToMe`). Diğer okumalar passthrough;
///      RLS zaten atanmış bayi/şoför ile sınırlar. Bakiye doğru kalsın diye
///      [listTransactions] daraltılmaz.
///   2) Normal formların çağırdığı [addTransaction]'ı **şoför RPC'sine**
///      ([addDriverTransaction]) köprüler → owner write yapılmaz, mevcut
///      `driver_add_transaction` güvenlik akışı kullanılır. Böylece ürün
///      listesi/otomatik fiyat dahil normal form akışı şoför için çalışır.
///
/// Owner-only bayi/şoför YÖNETİM yazmaları (bayi oluştur/aktif-pasif/fiyat
/// ekle/şoför yönetimi/davet oluştur) [StateError] fırlatır — bu aksiyonlar
/// UI'da şoföre zaten gösterilmez. Migration/RLS/RPC/hesap servisi DEĞİŞMEZ.
class DriverScopedDealerRepository implements DealerRepository {
  DriverScopedDealerRepository({required this.inner});

  final DealerRepository inner;

  // Owner yetkisi gerektiren yazımlarda ham StateError yerine UI'ın temiz
  // mesaja çevirdiği tipli exception.
  static Never _denied() => throw const DriverPermissionException();

  /// Mevcut şoför tam yetkili mi? (fiyat/silme/düzeltme kararı).
  Future<bool> _isFull() async =>
      (await inner.myDriverPermission()) == DriverPermission.full;

  // ── Dealers: atanmışla sınırlı ──
  @override
  Future<List<Dealer>> listDealers({
    bool? activeOnly,
    DealerCustomerType? customerType,
  }) async {
    final assigned = await inner.dealersAssignedToMe();
    if (activeOnly == true) {
      return assigned.where((d) => d.isActive).toList(growable: false);
    }
    return assigned;
  }

  @override
  Future<Dealer?> getDealer(String id) => inner.getDealer(id);

  // ── Reads: passthrough (RLS atanmış bayi ile sınırlar) ──
  @override
  Future<List<DealerPrice>> listPrices(String dealerId) =>
      inner.listPrices(dealerId);

  @override
  Future<DealerPrice?> currentPriceFor({
    required String dealerId,
    required String productName,
  }) =>
      inner.currentPriceFor(dealerId: dealerId, productName: productName);

  @override
  Future<List<DealerTransaction>> listTransactions(String dealerId) =>
      inner.listTransactions(dealerId);

  @override
  Future<List<DealerTransaction>> listAllTransactions() =>
      inner.listAllTransactions();

  @override
  Future<List<DealerNote>> listNotes(String dealerId) =>
      inner.listNotes(dealerId);

  // ── Yazma köprüsü: normal formların addTransaction'ı → şoför RPC'si ──
  // Teslimat/Tahsilat/İade → addDriverTransaction (her şofor). Düzeltme
  // (adjustment) yalnız TAM yetkili şofore açık; yarı yetkili → temiz mesaj.
  @override
  Future<void> addTransaction(DealerTransaction tx) async {
    if (tx.type == DealerTransactionType.adjustment && !await _isFull()) {
      throw const DriverPermissionException();
    }
    return inner.addDriverTransaction(
      dealerId: tx.dealerId,
      type: tx.type,
      amount: tx.amount,
      quantity: tx.quantity,
      unitPrice: tx.unitPrice,
      paymentMethod: tx.paymentMethod,
      productName: tx.productName,
      note: tx.note,
    );
  }

  // İşlem silme: TAM yetkili şofor → RPC; yarı yetkili → temiz mesaj.
  @override
  Future<void> deleteTransaction(DealerTransaction tx) async {
    if (!await _isFull()) throw const DriverPermissionException();
    return inner.driverDeleteTransaction(tx);
  }

  @override
  Future<void> addDriverTransaction({
    required String dealerId,
    required DealerTransactionType type,
    double amount = 0,
    int? quantity,
    double? unitPrice,
    DealerPaymentMethod? paymentMethod,
    String? productName,
    String note = '',
  }) =>
      inner.addDriverTransaction(
        dealerId: dealerId,
        type: type,
        amount: amount,
        quantity: quantity,
        unitPrice: unitPrice,
        paymentMethod: paymentMethod,
        productName: productName,
        note: note,
      );

  /// Atanmış bayiye not — FN-AUDIT-009: owner_id=PATRON yazan driver RPC'sine
  /// köprülenir (şoförün uid'iyle görünmez not oluşmaz).
  @override
  Future<void> addNote(DealerNote note) =>
      inner.driverAddNote(dealerId: note.dealerId, note: note.note);

  @override
  Future<void> driverAddNote({required String dealerId, required String note}) =>
      inner.driverAddNote(dealerId: dealerId, note: note);

  // ── Şoför self-view okumaları: passthrough ──
  @override
  Future<bool> isAssignedDriver() => inner.isAssignedDriver();

  @override
  Future<List<Dealer>> dealersAssignedToMe() => inner.dealersAssignedToMe();

  @override
  Future<List<String>> myDriverIds() => inner.myDriverIds();

  @override
  Future<List<DealerDriverInvite>> myDriverInvites() => inner.myDriverInvites();

  @override
  Future<void> respondDriverInvite(String inviteId, {required bool accept}) =>
      inner.respondDriverInvite(inviteId, accept: accept);

  // ── Owner-only yönetim okumaları: şoför modunda anlamsız → boş ──
  @override
  Future<List<DealerDriver>> listDrivers() async => const [];

  @override
  Future<DealerDriver?> getDriver(String driverId) async => null;

  @override
  Future<List<String>> assignedDealerIds(String driverId) async => const [];

  @override
  Future<List<DealerDriverInvite>> pendingDriverInvites() async => const [];

  // ── Owner-only bayi/şoför YÖNETİM yazmaları: kilitli ──
  @override
  Future<void> upsertDealer(Dealer dealer) async => _denied();

  @override
  Future<void> setActive(String dealerId, {required bool active}) async =>
      _denied();

  // Fiyat ekleme/düzenleme: TAM yetkili şofor → RPC; yarı yetkili → temiz mesaj.
  @override
  Future<void> addPrice(DealerPrice price) async {
    if (!await _isFull()) throw const DriverPermissionException();
    return inner.driverSetPrice(
      dealerId: price.dealerId,
      productName: price.productName,
      unitPrice: price.unitPrice,
    );
  }

  @override
  Future<void> addDriver({
    required String driverUserId,
    required String name,
    String phone = '',
    String note = '',
    DriverPermission permissionLevel = DriverPermission.half,
  }) async =>
      _denied();

  @override
  Future<void> updateDriver(DealerDriver driver) async => _denied();

  @override
  Future<void> setDriverAssignments({
    required String driverId,
    required List<String> dealerIds,
  }) async =>
      _denied();

  @override
  Future<void> createDriverInvite({
    required String firinnetId,
    required String name,
    String phone = '',
    String note = '',
    DriverPermission permissionLevel = DriverPermission.half,
  }) async =>
      _denied();

  @override
  Future<void> cancelDriverInvite(String inviteId) async => _denied();

  // ── Yetki seviyesi + tam-yetkili şofor RPC passthrough ──
  @override
  Future<DriverPermission> myDriverPermission() => inner.myDriverPermission();

  @override
  Future<void> driverDeleteTransaction(DealerTransaction tx) =>
      inner.driverDeleteTransaction(tx);

  @override
  Future<void> driverSetPrice({
    required String dealerId,
    required String productName,
    required double unitPrice,
  }) =>
      inner.driverSetPrice(
          dealerId: dealerId, productName: productName, unitPrice: unitPrice);

  // ── Streams + dispose: delegate ──
  @override
  Stream<void> watch() => inner.watch();

  @override
  Stream<void> watchContent() => inner.watchContent();

  @override
  void dispose() => inner.dispose();
}
