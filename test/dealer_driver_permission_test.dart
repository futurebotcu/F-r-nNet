// feature/dealer-driver-permission-levels — Yarı/Tam yetki birim testleri.
// Default half, davet→full, yarı→exception, tam→fiyat/sil/düzeltme,
// atanmamış bayi reddi, Şoförler verisi gizli.

import 'package:firin_defter/features/dealers/models/dealer_driver.dart';
import 'package:firin_defter/features/dealers/models/dealer_price.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/repositories/driver_permission.dart';
import 'package:firin_defter/features/dealers/repositories/driver_scoped_dealer_repository.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({DriverScopedDealerRepository scoped, LocalDealerRepository inner})>
    _seed({required DriverPermission perm}) async {
  final inner = LocalDealerRepository(seed: true, currentUserId: 'u1');
  await inner.addDriver(
      driverUserId: 'u1', name: 'Ali Şoför', permissionLevel: perm);
  final driverId = (await inner.listDrivers()).first.id;
  await inner.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);
  return (scoped: DriverScopedDealerRepository(inner: inner), inner: inner);
}

void main() {
  test('Yeni şoför varsayılan YARI yetki', () async {
    final inner = LocalDealerRepository(seed: true, currentUserId: 'u1');
    await inner.addDriver(driverUserId: 'u1', name: 'Ali');
    expect((await inner.listDrivers()).first.permissionLevel,
        DriverPermission.half);
  });

  test('Davet varsayılan YARI; TAM davet kabul edilince şoför full olur',
      () async {
    final repo = LocalDealerRepository(seed: true, currentUserId: 'owner1');
    // default (half) davet
    await repo.createDriverInvite(firinnetId: 'u3', name: 'Hasan');
    final halfInv = (await repo.pendingDriverInvites())
        .firstWhere((i) => i.driverName == 'Hasan');
    expect(halfInv.permissionLevel, DriverPermission.half);
    // tam yetkili davet
    await repo.createDriverInvite(
        firinnetId: 'u2', name: 'Veli', permissionLevel: DriverPermission.full);
    final fullInv = (await repo.pendingDriverInvites())
        .firstWhere((i) => i.driverName == 'Veli');
    expect(fullInv.permissionLevel, DriverPermission.full);
    // kabul → driver full
    await repo.respondDriverInvite(fullInv.id, accept: true);
    final driver =
        (await repo.listDrivers()).firstWhere((d) => d.name == 'Veli');
    expect(driver.permissionLevel, DriverPermission.full);
  });

  test('YARI yetkili: fiyat/silme/düzeltme → DriverPermissionException',
      () async {
    final (:scoped, :inner) = await _seed(perm: DriverPermission.half);
    final tx = (await scoped.listTransactions('d_hamdi')).first;
    expect(
        () => scoped.addPrice(DealerPrice(
              id: 'x',
              dealerId: 'd_hamdi',
              productName: 'Ekmek',
              unitPrice: 12,
              validFrom: DateTime.now(),
            )),
        throwsA(isA<DriverPermissionException>()));
    expect(() => scoped.deleteTransaction(tx),
        throwsA(isA<DriverPermissionException>()));
    expect(
        () => scoped.addTransaction(DealerTransaction(
              id: 'x',
              dealerId: 'd_hamdi',
              type: DealerTransactionType.adjustment,
              amount: 100,
              createdAt: DateTime.now(),
            )),
        throwsA(isA<DriverPermissionException>()));
  });

  test('TAM yetkili: atanmış bayide fiyat ekler', () async {
    final (:scoped, :inner) = await _seed(perm: DriverPermission.full);
    await scoped.addPrice(DealerPrice(
      id: 'x',
      dealerId: 'd_hamdi',
      productName: 'Simit',
      unitPrice: 7.5,
      validFrom: DateTime.now(),
    ));
    final prices = await scoped.listPrices('d_hamdi');
    expect(prices.any((p) => p.productName == 'Simit' && p.unitPrice == 7.5),
        isTrue);
  });

  test('TAM yetkili: atanmış bayide işlem siler', () async {
    final (:scoped, :inner) = await _seed(perm: DriverPermission.full);
    final before = await scoped.listTransactions('d_hamdi');
    final tx = before.first;
    await scoped.deleteTransaction(tx);
    final after = await scoped.listTransactions('d_hamdi');
    expect(after.any((t) => t.id == tx.id), isFalse);
  });

  test('TAM yetkili: atanmış bayide düzeltme (adjustment) ekler', () async {
    final (:scoped, :inner) = await _seed(perm: DriverPermission.full);
    await scoped.addTransaction(DealerTransaction(
      id: 'x',
      dealerId: 'd_hamdi',
      type: DealerTransactionType.adjustment,
      amount: -250,
      createdAt: DateTime.now(),
    ));
    final txs = await scoped.listTransactions('d_hamdi');
    expect(txs.any((t) => t.type == DealerTransactionType.adjustment), isTrue);
  });

  test('TAM yetkili: atanmadığı bayide işlem yapamaz', () async {
    final (:scoped, :inner) = await _seed(perm: DriverPermission.full);
    expect(
        () => scoped.addTransaction(DealerTransaction(
              id: 'x',
              dealerId: 'd_mehmet', // atanmamış
              type: DealerTransactionType.delivery,
              productName: 'Ekmek',
              quantity: 5,
              unitPrice: 10,
              amount: 50,
              createdAt: DateTime.now(),
            )),
        throwsA(isA<StateError>()));
  });

  test('TAM yetkili bile Şoförler (yönetim) verisini göremez', () async {
    final (:scoped, :inner) = await _seed(perm: DriverPermission.full);
    expect(await scoped.listDrivers(), isEmpty);
    expect(await scoped.pendingDriverInvites(), isEmpty);
    expect(() => scoped.addDriver(driverUserId: 'z', name: 'X'),
        throwsA(isA<DriverPermissionException>()));
  });
}
