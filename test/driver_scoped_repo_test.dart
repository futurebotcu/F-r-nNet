// fix/driver-normal-dealer-shell — DriverScopedDealerRepository birim testi.
// Scope: listDealers→atanmış; addTransaction→addDriverTransaction köprüsü
// (normal formlar şoför RPC'sine gider); owner-yönetim write→throw.

import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/repositories/driver_scoped_dealer_repository.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({DriverScopedDealerRepository scoped, LocalDealerRepository inner})>
    _seed() async {
  final inner = LocalDealerRepository(seed: true, currentUserId: 'u1');
  await inner.addDriver(driverUserId: 'u1', name: 'Ali Şoför');
  final driverId = (await inner.listDrivers()).first.id;
  await inner.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);
  return (scoped: DriverScopedDealerRepository(inner: inner), inner: inner);
}

void main() {
  test('listDealers yalnız atanmış bayiyi döner', () async {
    final (:scoped, :inner) = await _seed();
    final dealers = await scoped.listDealers();
    expect(dealers.map((d) => d.id).toList(), ['d_hamdi']);
    expect(dealers.any((d) => d.id == 'd_mehmet'), isFalse);
  });

  test('addTransaction → addDriverTransaction köprüsü (driver_id set edilir)',
      () async {
    final (:scoped, :inner) = await _seed();
    // Normal teslimat formunun yaptığı gibi addTransaction çağrılır.
    await scoped.addTransaction(DealerTransaction(
      id: 'ignored',
      dealerId: 'd_hamdi',
      type: DealerTransactionType.delivery,
      productName: 'Ekmek',
      quantity: 5,
      unitPrice: 10,
      amount: 50,
      createdAt: DateTime.now(),
    ));
    // Şoför RPC yolundan gittiyse kayıt driver_id'li olur.
    final txs = await scoped.listTransactions('d_hamdi');
    final mine = txs.where((t) => t.driverId != null).toList();
    expect(mine, isNotEmpty);
    expect(mine.any((t) => t.productName == 'Ekmek'), isTrue);
  });

  test('owner-yönetim write metotları StateError fırlatır', () async {
    final (:scoped, :inner) = await _seed();
    expect(() => scoped.setActive('d_hamdi', active: false),
        throwsA(isA<StateError>()));
    expect(() => scoped.addDriver(driverUserId: 'z', name: 'X'),
        throwsA(isA<StateError>()));
    expect(() => scoped.setDriverAssignments(driverId: 'x', dealerIds: const []),
        throwsA(isA<StateError>()));
  });

  test('listTransactions TAM döner (bakiye doğru)', () async {
    final (:scoped, :inner) = await _seed();
    final txs = await scoped.listTransactions('d_hamdi');
    expect(txs, isNotEmpty); // seed patron hareketleri dahil
  });
}
