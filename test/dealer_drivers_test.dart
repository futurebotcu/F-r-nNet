// Bayi Şoförler — Sprint 2 (patron-side) Local repo testleri.
//
// Kapsam: şoför ekle/listele/güncelle, duplicate engeli, bayi atama (yalnız
// mevcut bayiler), atanmış bayi sayısı. Şoför erişim/yazma yok (sonraki sprint).

import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
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
}
