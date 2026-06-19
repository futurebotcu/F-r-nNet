// Bayi Şoförler — Sprint 2 (patron-side) Local repo testleri.
//
// Kapsam: şoför ekle/listele/güncelle, duplicate engeli, bayi atama (yalnız
// mevcut bayiler), atanmış bayi sayısı. Şoför erişim/yazma yok (sonraki sprint).

import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/services/dealer_balance_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalDealerRepository — şoförler', () {
    test('şoför ekle → listele', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.addDriver(driverUserId: 'u1', name: 'Ali Şoför', phone: '0555');
      final drivers = await repo.listDrivers();
      expect(drivers.length, 1);
      expect(drivers.first.name, 'Ali Şoför');
      expect(drivers.first.assignedDealerCount, 0);
    });

    test('aynı kullanıcı iki kez eklenemez', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      expect(
        () => repo.addDriver(driverUserId: 'u1', name: 'Ali 2'),
        throwsStateError,
      );
    });

    test('bayi atama → assignedDealerIds + sayaç', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final id = (await repo.listDrivers()).first.id;

      await repo.setDriverAssignments(
        driverId: id,
        dealerIds: ['d_hamdi', 'd_mehmet'],
      );
      final assigned = await repo.assignedDealerIds(id);
      expect(assigned.toSet(), {'d_hamdi', 'd_mehmet'});

      final drv = await repo.getDriver(id);
      expect(drv!.assignedDealerCount, 2);
    });

    test('geçersiz (var olmayan) bayi ataması filtrelenir', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final id = (await repo.listDrivers()).first.id;

      await repo.setDriverAssignments(
        driverId: id,
        dealerIds: ['d_hamdi', 'yok_olan_bayi'],
      );
      final assigned = await repo.assignedDealerIds(id);
      expect(assigned, ['d_hamdi']);
    });

    test('atama tam-eşitleme (çıkarma) çalışır', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final id = (await repo.listDrivers()).first.id;
      await repo.setDriverAssignments(driverId: id, dealerIds: ['d_hamdi', 'd_mehmet']);
      await repo.setDriverAssignments(driverId: id, dealerIds: ['d_mehmet']);
      expect(await repo.assignedDealerIds(id), ['d_mehmet']);
    });

    test('updateDriver ad/aktiflik günceller', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final drv = (await repo.listDrivers()).first;
      await repo.updateDriver(drv.copyWith(name: 'Ali Veli', isActive: false));
      final updated = await repo.getDriver(drv.id);
      expect(updated!.name, 'Ali Veli');
      expect(updated.isActive, isFalse);
    });

    test('mevcut bayiler şoför eklemeden etkilenmez (regresyon)', () async {
      final repo = LocalDealerRepository(seed: true);
      final before = (await repo.listDealers()).length;
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final after = (await repo.listDealers()).length;
      expect(after, before);
    });
  });

  group('Şoför read-only (Sprint 3, Local currentUserId)', () {
    test('currentUserId yoksa şoför değildir', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      expect(await repo.isAssignedDriver(), isFalse);
      expect(await repo.dealersAssignedToMe(), isEmpty);
    });

    test('atanmış şoför kendisine atanan bayiyi görür, atanmayanı görmez',
        () async {
      final repo = LocalDealerRepository(seed: true, currentUserId: 'u1');
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final driverId = (await repo.listDrivers()).first.id;
      await repo.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);

      expect(await repo.isAssignedDriver(), isTrue);
      final mine = await repo.dealersAssignedToMe();
      expect(mine.map((d) => d.id).toList(), ['d_hamdi']);
      // d_mehmet atanmadı → görünmez.
      expect(mine.any((d) => d.id == 'd_mehmet'), isFalse);
    });

    test('başka kullanıcı (şoför olmayan) hiçbir atanmış bayi görmez', () async {
      final repo = LocalDealerRepository(seed: true, currentUserId: 'baska');
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final driverId = (await repo.listDrivers()).first.id;
      await repo.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);
      expect(await repo.isAssignedDriver(), isFalse);
      expect(await repo.dealersAssignedToMe(), isEmpty);
    });

    test('pasif şoför read-only erişimi alamaz', () async {
      final repo = LocalDealerRepository(seed: true, currentUserId: 'u1');
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final drv = (await repo.listDrivers()).first;
      await repo.setDriverAssignments(driverId: drv.id, dealerIds: ['d_hamdi']);
      await repo.updateDriver(drv.copyWith(isActive: false));
      expect(await repo.isAssignedDriver(), isFalse);
      expect(await repo.dealersAssignedToMe(), isEmpty);
    });
  });

  group('Şoför işlem yazma (Sprint 4, addDriverTransaction)', () {
    Future<LocalDealerRepository> seedAssignedDriver() async {
      final repo = LocalDealerRepository(seed: true, currentUserId: 'u1');
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final drv = (await repo.listDrivers()).first;
      await repo.setDriverAssignments(driverId: drv.id, dealerIds: ['d_hamdi']);
      return repo;
    }

    test('atanmış bayiye payment ekler → ledger + bakiye', () async {
      final repo = await seedAssignedDriver();
      final before = (await repo.listTransactions('d_hamdi')).length;
      const svc = DealerBalanceService();
      final balBefore = svc
          .summarize(
              dealerId: 'd_hamdi',
              transactions: await repo.listTransactions('d_hamdi'))
          .currentBalance;

      await repo.addDriverTransaction(
        dealerId: 'd_hamdi',
        type: DealerTransactionType.payment,
        amount: 100,
        paymentMethod: DealerPaymentMethod.cash,
      );
      final after = await repo.listTransactions('d_hamdi');
      expect(after.length, before + 1);
      final balAfter =
          svc.summarize(dealerId: 'd_hamdi', transactions: after).currentBalance;
      expect(balAfter, balBefore - 100); // payment bakiyeyi azaltır
    });

    test('atanmış bayiye delivery ekler (amount=adet*fiyat)', () async {
      final repo = await seedAssignedDriver();
      await repo.addDriverTransaction(
        dealerId: 'd_hamdi',
        type: DealerTransactionType.delivery,
        quantity: 10,
        unitPrice: 8.5,
        productName: 'Ekmek',
      );
      final tx = (await repo.listTransactions('d_hamdi'))
          .firstWhere((t) => t.productName == 'Ekmek' && t.quantity == 10);
      expect(tx.amount, 85.0);
      expect(tx.type, DealerTransactionType.delivery);
    });

    test('atanmış bayiye return ekler', () async {
      final repo = await seedAssignedDriver();
      await repo.addDriverTransaction(
        dealerId: 'd_hamdi',
        type: DealerTransactionType.returned,
        quantity: 2,
        unitPrice: 8.5,
        productName: 'Ekmek',
      );
      final has = (await repo.listTransactions('d_hamdi'))
          .any((t) => t.type == DealerTransactionType.returned);
      expect(has, isTrue);
    });

    test('atanmadığı bayiye işlem ekleyemez', () async {
      final repo = await seedAssignedDriver();
      expect(
        () => repo.addDriverTransaction(
            dealerId: 'd_mehmet',
            type: DealerTransactionType.payment,
            amount: 50),
        throwsStateError,
      );
    });

    test('pasif/şoför-olmayan kullanıcı işlem ekleyemez', () async {
      final repo = LocalDealerRepository(seed: true, currentUserId: 'baska');
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final drv = (await repo.listDrivers()).first;
      await repo.setDriverAssignments(driverId: drv.id, dealerIds: ['d_hamdi']);
      expect(
        () => repo.addDriverTransaction(
            dealerId: 'd_hamdi',
            type: DealerTransactionType.payment,
            amount: 50),
        throwsStateError,
      );
    });

    test('şoföre adjustment kapalı', () async {
      final repo = await seedAssignedDriver();
      expect(
        () => repo.addDriverTransaction(
            dealerId: 'd_hamdi',
            type: DealerTransactionType.adjustment,
            amount: 10),
        throwsStateError,
      );
    });
  });
}
