import '../models/dealer.dart';
import '../models/dealer_driver.dart';
import '../models/dealer_driver_invite.dart';
import '../models/dealer_note.dart';
import '../models/dealer_price.dart';
import '../models/dealer_transaction.dart';
import 'dealer_repository.dart';

/// Şoför-scoped READ decorator (feat/driver-real-scoped-shell).
///
/// Bireysel şoför `/dealers` açınca normal [DealerShellScreen] **driverScoped**
/// modda render edilir ve provider'lar bu decorator'la sarılı repo'dan okur.
/// Böylece normal Bayi Yönetimi tab ekranları (overview/list/activity/reports)
/// AYNEN kullanılır; veri kapsamı yalnız şoföre atanmış bayilere daralır.
///
/// Scope kuralı:
/// - [listDealers] → yalnız şoföre atanmış bayiler (`dealersAssignedToMe`).
/// - [listTransactions]/[listAllTransactions] → passthrough (TAM). Bayi
///   bakiyesi doğru kalsın diye daraltılmaz; driver RLS zaten atanmış
///   bayilerle sınırlar. Hareketler tab'ındaki `driver_id` daraltması UI
///   katmanında (DealerActivityScreen driver mode) yapılır — burada DEĞİL.
/// - Owner-write metotları → [StateError] fırlatır (şoför yazamaz).
/// - [addDriverTransaction] + davet yanıtlama + self-view okumaları →
///   passthrough (mevcut şoför akışı korunur).
///
/// Migration/RLS/RPC/hesap servisi DEĞİŞMEZ; bu yalnız client-side bir
/// okuma daraltıcı + yazma kilidi.
class DriverScopedDealerRepository implements DealerRepository {
  DriverScopedDealerRepository({required this.inner});

  final DealerRepository inner;

  static Never _denied() =>
      throw StateError('Şoför modunda bu işlem yapılamaz.');

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

  // ── Reads: passthrough ──
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

  // ── Şoför self-view okumaları: passthrough ──
  @override
  Future<bool> isAssignedDriver() => inner.isAssignedDriver();

  @override
  Future<List<Dealer>> dealersAssignedToMe() => inner.dealersAssignedToMe();

  @override
  Future<List<String>> myDriverIds() => inner.myDriverIds();

  @override
  Future<List<DealerDriverInvite>> myDriverInvites() => inner.myDriverInvites();

  /// Şoför kendi davetini yanıtlar — geçerli şoför aksiyonu, korunur.
  @override
  Future<void> respondDriverInvite(String inviteId, {required bool accept}) =>
      inner.respondDriverInvite(inviteId, accept: accept);

  /// Şoför, atandığı bayiye işlem yazar — mevcut driverDealerDetail akışı.
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

  // ── Owner-only okumalar: şoför modunda anlamsız → boş ──
  @override
  Future<List<DealerDriver>> listDrivers() async => const [];

  @override
  Future<DealerDriver?> getDriver(String driverId) async => null;

  @override
  Future<List<String>> assignedDealerIds(String driverId) async => const [];

  @override
  Future<List<DealerDriverInvite>> pendingDriverInvites() async => const [];

  // ── Owner-write metotları: kilitli ──
  @override
  Future<void> upsertDealer(Dealer dealer) async => _denied();

  @override
  Future<void> setActive(String dealerId, {required bool active}) async =>
      _denied();

  @override
  Future<void> addPrice(DealerPrice price) async => _denied();

  @override
  Future<void> addTransaction(DealerTransaction tx) async => _denied();

  @override
  Future<void> addNote(DealerNote note) async => _denied();

  @override
  Future<void> addDriver({
    required String driverUserId,
    required String name,
    String phone = '',
    String note = '',
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
  }) async =>
      _denied();

  @override
  Future<void> cancelDriverInvite(String inviteId) async => _denied();

  // ── Streams + dispose: delegate ──
  @override
  Stream<void> watch() => inner.watch();

  @override
  Stream<void> watchContent() => inner.watchContent();

  @override
  void dispose() => inner.dispose();
}
