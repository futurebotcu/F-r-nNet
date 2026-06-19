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

  group('Şoför daveti (Sprint 6, davet/onay)', () {
    test('davet oluştur → pending listede, aktif şoför YOK', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.createDriverInvite(invitedUserId: 'u1', name: 'Ali');
      expect((await repo.pendingDriverInvites()).length, 1);
      expect((await repo.listDrivers()).isEmpty, isTrue); // aktif bağlantı yok
    });

    test('kabul → aktif şoför oluşur, davet pending değil', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.createDriverInvite(invitedUserId: 'u1', name: 'Ali');
      final inv = (await repo.pendingDriverInvites()).first;
      await repo.respondDriverInvite(inv.id, accept: true);
      expect((await repo.listDrivers()).any((d) => d.driverUserId == 'u1'),
          isTrue);
      expect((await repo.pendingDriverInvites()).isEmpty, isTrue);
    });

    test('red → aktif şoför oluşmaz', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.createDriverInvite(invitedUserId: 'u1', name: 'Ali');
      final inv = (await repo.pendingDriverInvites()).first;
      await repo.respondDriverInvite(inv.id, accept: false);
      expect((await repo.listDrivers()).isEmpty, isTrue);
      expect((await repo.pendingDriverInvites()).isEmpty, isTrue);
    });

    test('aynı kullanıcıya ikinci bekleyen davet engellenir', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.createDriverInvite(invitedUserId: 'u1', name: 'Ali');
      expect(
        () => repo.createDriverInvite(invitedUserId: 'u1', name: 'Ali 2'),
        throwsStateError,
      );
    });

    test('zaten şoför olana davet engellenir', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.createDriverInvite(invitedUserId: 'u1', name: 'Ali');
      final inv = (await repo.pendingDriverInvites()).first;
      await repo.respondDriverInvite(inv.id, accept: true);
      expect(
        () => repo.createDriverInvite(invitedUserId: 'u1', name: 'Ali'),
        throwsStateError,
      );
    });

    test('iptal → bekleyen davet kalkar', () async {
      final repo = LocalDealerRepository(seed: true);
      await repo.createDriverInvite(invitedUserId: 'u1', name: 'Ali');
      final inv = (await repo.pendingDriverInvites()).first;
      await repo.cancelDriverInvite(inv.id);
      expect((await repo.pendingDriverInvites()).isEmpty, isTrue);
      expect((await repo.listDrivers()).isEmpty, isTrue);
    });

    test('pending davet şoföre bayi erişimi vermez', () async {
      final repo = LocalDealerRepository(seed: true, currentUserId: 'u1');
      // Not: davet patron tarafından oluşturulur; burada currentUserId=u1
      // sadece "erişim yok" kontrolü için — davet yokken de şoför değil.
      expect(await repo.isAssignedDriver(), isFalse);
      expect(await repo.dealersAssignedToMe(), isEmpty);
    });
  });

  group('Şoför özeti (Sprint 5, driver_id filtreli tek defter)', () {
    test('şoför işlemi driver_id taşır; eski NULL hareketler kırılıma girmez',
        () async {
      final repo = LocalDealerRepository(seed: true, currentUserId: 'u1');
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final driverId = (await repo.listDrivers()).first.id;
      await repo.setDriverAssignments(driverId: driverId, dealerIds: ['d_hamdi']);
      await repo.addDriverTransaction(
          dealerId: 'd_hamdi',
          type: DealerTransactionType.payment,
          amount: 100,
          paymentMethod: DealerPaymentMethod.cash);
      await repo.addDriverTransaction(
          dealerId: 'd_hamdi',
          type: DealerTransactionType.delivery,
          quantity: 10,
          unitPrice: 5);

      final all = await repo.listAllTransactions();
      final mine = all.where((t) => t.driverId == driverId).toList();
      expect(mine.length, 2); // yalnız şoför işlemleri
      // Seed (patron) hareketleri driver_id NULL → kırılıma girmez.
      expect(all.any((t) => t.driverId == null), isTrue);

      const svc = DealerBalanceService();
      final agg = svc.aggregateRange(
          transactions: mine,
          start: DateTime(2000),
          end: DateTime(2100));
      expect(agg.totalPayment, 100);
      expect(agg.totalDelivery, 50);
      expect(agg.txCount, 2);
    });

    test('başka şoförün işlemi kırılımda karışmaz', () async {
      final repo = LocalDealerRepository(seed: true, currentUserId: 'u1');
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final d1 = (await repo.listDrivers()).first.id;
      await repo.setDriverAssignments(driverId: d1, dealerIds: ['d_hamdi']);
      await repo.addDriverTransaction(
          dealerId: 'd_hamdi',
          type: DealerTransactionType.payment,
          amount: 70);

      final all = await repo.listAllTransactions();
      // Başka driverId ('drv_999') için hiçbir hareket yok.
      expect(all.where((t) => t.driverId == 'drv_999'), isEmpty);
      expect(all.where((t) => t.driverId == d1).length, 1);
    });

    test('date filtre: bugünkü şoför işlemi today aralığında, dün hariç',
        () async {
      final repo = LocalDealerRepository(seed: true, currentUserId: 'u1');
      await repo.addDriver(driverUserId: 'u1', name: 'Ali');
      final d1 = (await repo.listDrivers()).first.id;
      await repo.setDriverAssignments(driverId: d1, dealerIds: ['d_hamdi']);
      await repo.addDriverTransaction(
          dealerId: 'd_hamdi',
          type: DealerTransactionType.payment,
          amount: 40);

      final mine = (await repo.listAllTransactions())
          .where((t) => t.driverId == d1);
      const svc = DealerBalanceService();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final todayAgg = svc.aggregateRange(
          transactions: mine, start: today, end: tomorrow);
      final yesterdayAgg = svc.aggregateRange(
          transactions: mine,
          start: today.subtract(const Duration(days: 1)),
          end: today);
      expect(todayAgg.txCount, 1); // bugün
      expect(yesterdayAgg.txCount, 0); // dün aralığında yok
    });
  });
}
