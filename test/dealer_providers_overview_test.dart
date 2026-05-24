// Quality Patch v1 P0-2 — dealersOverviewProvider deterministik testi.
//
// Genel Bakış KPI'ları artık DealerBalanceService.aggregateRange üzerinden
// hesaplanıyor (manuel switch loop'u kaldırıldı). Bu test deterministik
// seed üzerinde:
//   - openBalance: aktif bayilerin pozitif currentBalance toplamı
//   - todayDelivered / todayCollected: bugünün gross toplamları
//   - monthNetChange / monthTxCount: bu ay signed net + tx sayısı
// değerlerinin refactor öncesi/sonrası aynı olduğunu doğrular.

import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<LocalDealerRepository> _seededRepo() async {
  final repo = LocalDealerRepository(seed: false);

  // 3 bayi: 2 aktif, 1 pasif
  await repo.upsertDealer(Dealer(
    id: 'd-active-1',
    name: 'Hamdi Bakkal',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd-active-2',
    name: 'Mehmet Market',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd-passive',
    name: 'Şenel Büfe',
    isActive: false,
    createdAt: DateTime(2026, 1, 1),
  ));

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 10);
  final monthStart = DateTime(now.year, now.month, 1, 12);

  // Hamdi — bugün delivery 500, payment 200; ayın başında delivery 1000
  await repo.addTransaction(DealerTransaction(
    id: 't-h1',
    dealerId: 'd-active-1',
    type: DealerTransactionType.delivery,
    amount: 500,
    createdAt: today,
  ));
  await repo.addTransaction(DealerTransaction(
    id: 't-h2',
    dealerId: 'd-active-1',
    type: DealerTransactionType.payment,
    amount: 200,
    createdAt: today,
  ));
  await repo.addTransaction(DealerTransaction(
    id: 't-h-month',
    dealerId: 'd-active-1',
    type: DealerTransactionType.delivery,
    amount: 1000,
    createdAt: monthStart,
  ));

  // Mehmet — bugün delivery 100, return 50; ay içi adjustment +25
  await repo.addTransaction(DealerTransaction(
    id: 't-m1',
    dealerId: 'd-active-2',
    type: DealerTransactionType.delivery,
    amount: 100,
    createdAt: today,
  ));
  await repo.addTransaction(DealerTransaction(
    id: 't-m2',
    dealerId: 'd-active-2',
    type: DealerTransactionType.returned,
    amount: 50,
    createdAt: today,
  ));
  await repo.addTransaction(DealerTransaction(
    id: 't-m-adj',
    dealerId: 'd-active-2',
    type: DealerTransactionType.adjustment,
    amount: 25,
    createdAt: monthStart,
  ));

  // Şenel pasif — bugün delivery 999 (overview'a yansır: tx tüm bayiler
  // toplandığı için bugün gross + ay net'e dahil olur; ama openBalance
  // hesabına dahil DEĞİL çünkü o yalnız aktif bayiler).
  await repo.addTransaction(DealerTransaction(
    id: 't-p1',
    dealerId: 'd-passive',
    type: DealerTransactionType.delivery,
    amount: 999,
    createdAt: today,
  ));

  return repo;
}

void main() {
  group('dealersOverviewProvider — KPI hesapları', () {
    test('aktif bayi sayısı + openBalance (yalnız aktif + pozitif)',
        () async {
      final repo = await _seededRepo();
      final container = ProviderContainer(overrides: [
        dealerRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final o = await container.read(dealersOverviewProvider.future);

      expect(o.totalDealers, 3);
      expect(o.activeDealers, 2);
      // Hamdi balance: 500 (today delivery) − 200 (today pay) + 1000 (ay
      // başı delivery) = 1300 → pozitif, openBalance'a dahil.
      // Mehmet balance: 100 − 50 + 25 = 75 → pozitif, dahil.
      // Şenel pasif → openBalance'a DAHİL DEĞİL.
      expect(o.openBalance, 1300 + 75);
    });

    test('bugün gross delivery/payment — tüm bayiler (pasif dahil)',
        () async {
      final repo = await _seededRepo();
      final container = ProviderContainer(overrides: [
        dealerRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final o = await container.read(dealersOverviewProvider.future);

      // Bugün delivery toplamı: Hamdi 500 + Mehmet 100 + Şenel 999 = 1599
      expect(o.todayDelivered, 1599);
      // Bugün payment toplamı: yalnız Hamdi 200
      expect(o.todayCollected, 200);
    });

    test('bu ay net change + tx count — cross-dealer signed agregat',
        () async {
      final repo = await _seededRepo();
      final container = ProviderContainer(overrides: [
        dealerRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final o = await container.read(dealersOverviewProvider.future);

      // Bu ay net (cross-dealer signed):
      // Hamdi:  +500 − 200 + 1000 = +1300
      // Mehmet: +100 − 50 + 25    = +75
      // Şenel:  +999
      // Toplam: 2374
      expect(o.monthNetChange, 1300 + 75 + 999);
      // 3 + 3 + 1 = 7 tx
      expect(o.monthTxCount, 7);
    });
  });
}
