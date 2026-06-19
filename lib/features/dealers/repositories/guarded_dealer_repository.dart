import '../../auth/services/auth_required_guard.dart';
import '../models/dealer.dart';
import '../models/dealer_driver.dart';
import '../models/dealer_driver_invite.dart';
import '../models/dealer_note.dart';
import '../models/dealer_price.dart';
import '../models/dealer_transaction.dart';
import 'dealer_repository.dart';

/// V1.3.3 — guest write korumalı [DealerRepository] dekoratörü.
class GuardedDealerRepository implements DealerRepository {
  GuardedDealerRepository({required this.inner, required this.canWriteCheck});

  final DealerRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  // ── Read ────────────────────────────────────────────

  @override
  Future<List<Dealer>> listDealers({
    bool? activeOnly,
    DealerCustomerType? customerType,
  }) =>
      inner.listDealers(activeOnly: activeOnly, customerType: customerType);

  @override
  Future<Dealer?> getDealer(String id) => inner.getDealer(id);

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

  @override
  Future<List<DealerDriver>> listDrivers() => inner.listDrivers();

  @override
  Future<DealerDriver?> getDriver(String driverId) =>
      inner.getDriver(driverId);

  @override
  Future<List<String>> assignedDealerIds(String driverId) =>
      inner.assignedDealerIds(driverId);

  @override
  Future<List<DealerDriverInvite>> pendingDriverInvites() =>
      inner.pendingDriverInvites();

  @override
  Future<List<DealerDriverInvite>> myDriverInvites() => inner.myDriverInvites();

  @override
  Future<List<String>> myDriverIds() => inner.myDriverIds();

  @override
  Future<bool> isAssignedDriver() => inner.isAssignedDriver();

  @override
  Future<List<Dealer>> dealersAssignedToMe() => inner.dealersAssignedToMe();

  @override
  Stream<void> watch() => inner.watch();

  @override
  Stream<void> watchContent() => inner.watchContent();

  @override
  void dispose() => inner.dispose();

  // ── Write (guarded) ────────────────────────────────

  @override
  Future<void> upsertDealer(Dealer dealer) {
    final action = dealer.customerType == DealerCustomerType.wholesaleCustomer
        ? 'müşteri eklemek'
        : 'bayi eklemek';
    _requireWrite(action);
    return inner.upsertDealer(dealer);
  }

  @override
  Future<void> setActive(String dealerId, {required bool active}) {
    _requireWrite('bayi durumunu güncellemek');
    return inner.setActive(dealerId, active: active);
  }

  @override
  Future<void> addPrice(DealerPrice price) {
    _requireWrite('bayi fiyatı eklemek');
    return inner.addPrice(price);
  }

  @override
  Future<void> addTransaction(DealerTransaction tx) {
    final action = switch (tx.type) {
      DealerTransactionType.delivery => 'teslimat kaydetmek',
      DealerTransactionType.returned => 'iade kaydetmek',
      DealerTransactionType.payment => 'tahsilat kaydetmek',
      DealerTransactionType.adjustment => 'bakiye düzeltmesi yapmak',
    };
    _requireWrite(action);
    return inner.addTransaction(tx);
  }

  @override
  Future<void> addNote(DealerNote note) {
    _requireWrite('bayi notu eklemek');
    return inner.addNote(note);
  }

  // ── Şoförler (guarded write) ───────────────────────

  @override
  Future<void> addDriver({
    required String driverUserId,
    required String name,
    String phone = '',
    String note = '',
  }) {
    _requireWrite('şoför eklemek');
    return inner.addDriver(
      driverUserId: driverUserId,
      name: name,
      phone: phone,
      note: note,
    );
  }

  @override
  Future<void> updateDriver(DealerDriver driver) {
    _requireWrite('şoför güncellemek');
    return inner.updateDriver(driver);
  }

  @override
  Future<void> setDriverAssignments({
    required String driverId,
    required List<String> dealerIds,
  }) {
    _requireWrite('şoföre bayi atamak');
    return inner.setDriverAssignments(driverId: driverId, dealerIds: dealerIds);
  }

  @override
  Future<void> createDriverInvite({
    required String firinnetId,
    required String name,
    String phone = '',
    String note = '',
  }) {
    _requireWrite('şoför daveti göndermek');
    return inner.createDriverInvite(
        firinnetId: firinnetId, name: name, phone: phone, note: note);
  }

  @override
  Future<void> respondDriverInvite(String inviteId, {required bool accept}) {
    _requireWrite('davet yanıtlamak');
    return inner.respondDriverInvite(inviteId, accept: accept);
  }

  @override
  Future<void> cancelDriverInvite(String inviteId) {
    _requireWrite('davet iptal etmek');
    return inner.cancelDriverInvite(inviteId);
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
  }) {
    _requireWrite('işlem eklemek');
    return inner.addDriverTransaction(
      dealerId: dealerId,
      type: type,
      amount: amount,
      quantity: quantity,
      unitPrice: unitPrice,
      paymentMethod: paymentMethod,
      productName: productName,
      note: note,
    );
  }
}
