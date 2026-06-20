// feat/driver-real-scoped-shell — DriverScopedDealerRepository decorator birim
// testi. Scope: listDealers→atanmış, listTransactions→TAM (bakiye doğru),
// owner-write→throw, addDriverTransaction→passthrough.

import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/repositories/driver_scoped_dealer_repository.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DriverScopedDealerRepository> _seed() async {
  final local = LocalDealerRepository(seed: true, currentUserId: 'u1');
  await local.addDriver(driverUserId: 'u1', name: 'Ali Şoför');
  final driverId = (await local.listDrivers()).first.id;
  await local.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);
  return DriverScopedDealerRepository(inner: local);
}

void main() {
  test('listDealers yalnız atanmış bayileri döner', () async {
    final repo = await _seed();
    final dealers = await repo.listDealers();
    expect(dealers.map((d) => d.id).toList(), ['d_hamdi']);
    // Atanmamış bayi yok.
    expect(dealers.any((d) => d.id == 'd_mehmet'), isFalse);
  });

  test('listTransactions TAM döner (bakiye doğru kalsın)', () async {
    final repo = await _seed();
    // Seed d_hamdi üzerine patron (driver_id null) hareketleri ekler; decorator
    // bunları daraltMAZ — bakiye full tx üzerinden hesaplanır.
    final txs = await repo.listTransactions('d_hamdi');
    expect(txs, isNotEmpty);
  });

  test('owner-write metotları StateError fırlatır', () async {
    final repo = await _seed();
    expect(() => repo.setActive('d_hamdi', active: false),
        throwsA(isA<StateError>()));
    expect(
        () => repo.setDriverAssignments(driverId: 'x', dealerIds: const []),
        throwsA(isA<StateError>()));
    expect(() => repo.addDriver(driverUserId: 'z', name: 'X'),
        throwsA(isA<StateError>()));
    expect(() => repo.createDriverInvite(firinnetId: 'FN', name: 'X'),
        throwsA(isA<StateError>()));
  });

  test('addDriverTransaction passthrough çalışır (şoför işlem akışı korunur)',
      () async {
    final repo = await _seed();
    await repo.addDriverTransaction(
      dealerId: 'd_hamdi',
      type: DealerTransactionType.delivery,
      quantity: 3,
      unitPrice: 10,
    );
    // Eklenen driver_id'li hareket listede görünür.
    final txs = await repo.listTransactions('d_hamdi');
    expect(txs.any((t) => t.driverId != null), isTrue);
  });
}
