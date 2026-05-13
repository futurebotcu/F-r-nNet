import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_price.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalDealerRepository — fiyat seçimi', () {
    test('farklı bayilere farklı fiyat uygulanır', () async {
      final repo = LocalDealerRepository(seed: false);
      final now = DateTime(2026, 5, 1);

      await repo.upsertDealer(Dealer(
        id: 'd1',
        name: 'Bayi 1',
        createdAt: now,
      ));
      await repo.upsertDealer(Dealer(
        id: 'd2',
        name: 'Bayi 2',
        createdAt: now,
      ));

      await repo.addPrice(DealerPrice(
        id: 'p1',
        dealerId: 'd1',
        productName: 'Ekmek',
        unitPrice: 8.5,
        validFrom: now,
      ));
      await repo.addPrice(DealerPrice(
        id: 'p2',
        dealerId: 'd2',
        productName: 'Ekmek',
        unitPrice: 9,
        validFrom: now,
      ));

      final p1 =
          await repo.currentPriceFor(dealerId: 'd1', productName: 'Ekmek');
      final p2 =
          await repo.currentPriceFor(dealerId: 'd2', productName: 'Ekmek');

      expect(p1!.unitPrice, 8.5);
      expect(p2!.unitPrice, 9);
    });

    test('en güncel validFrom kazanır (fiyat değişimi)', () async {
      final repo = LocalDealerRepository(seed: false);
      final base = DateTime(2026, 1, 1);

      await repo.upsertDealer(Dealer(
        id: 'd1',
        name: 'Bayi',
        createdAt: base,
      ));

      await repo.addPrice(DealerPrice(
        id: 'p1',
        dealerId: 'd1',
        productName: 'Ekmek',
        unitPrice: 7,
        validFrom: base,
      ));
      await repo.addPrice(DealerPrice(
        id: 'p2',
        dealerId: 'd1',
        productName: 'Ekmek',
        unitPrice: 8.5,
        validFrom: base.add(const Duration(days: 90)),
      ));

      final current =
          await repo.currentPriceFor(dealerId: 'd1', productName: 'Ekmek');
      expect(current!.unitPrice, 8.5);
    });

    test('fiyat tanımlı değilse null döner', () async {
      final repo = LocalDealerRepository(seed: false);
      final r =
          await repo.currentPriceFor(dealerId: 'd-yok', productName: 'X');
      expect(r, isNull);
    });

    test('pasif yapma geçmiş işlemleri silmez', () async {
      final repo = LocalDealerRepository(seed: true);
      final all = await repo.listDealers();
      final hamdi = all.firstWhere((d) => d.id == 'd_hamdi');
      final priorTx = await repo.listTransactions(hamdi.id);
      expect(priorTx, isNotEmpty);

      await repo.setActive(hamdi.id, active: false);
      final updated = await repo.getDealer(hamdi.id);
      expect(updated!.isActive, isFalse);

      final txAfter = await repo.listTransactions(hamdi.id);
      expect(txAfter.length, priorTx.length);
    });
  });
}
