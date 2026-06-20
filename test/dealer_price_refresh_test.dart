// Bayi Defteri Hardening Sprinti — A) Fiyat ekleme sonrası refresh.
//
// Fiyat sheet'i kaydetince (`DealerPriceSheet._save`) repo.addPrice ardından
// `pricesByDealerProvider(dealerId)` invalidate edilir; detay ekranındaki
// fiyat listesi stream zamanlamasına bağlı kalmadan anında tazelenir.
// Teslimat/iade formu fiyatı imperatif `currentPriceFor` ile okuduğundan,
// yeni fiyat bir sonraki ürün seçiminde otomatik gelir (provider cache yok).
//
// Bu test refresh kontratını provider/repo seviyesinde kanıtlar. Half/full
// yetki davranışı dealer_driver_permission_test.dart'ta kapsanır (değişmedi).

import 'package:firin_defter/features/dealers/models/dealer_price.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Fiyat eklenince invalidate sonrası fiyat listesi yeni fiyatı gösterir',
      () async {
    final repo = LocalDealerRepository(seed: true);
    final container = ProviderContainer(
      overrides: [dealerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // autoDispose family'yi canlı tut (ekranda watch ediliyor gibi).
    final sub = container.listen(
      pricesByDealerProvider('d_pide'),
      (_, __) {},
    );
    addTearDown(sub.close);

    final before = await container.read(pricesByDealerProvider('d_pide').future);
    expect(before.any((p) => p.productName == 'Poğaça'), isFalse);

    final now = DateTime.now();
    await repo.addPrice(
      DealerPrice(
        id: 'p_test_${now.microsecondsSinceEpoch}',
        dealerId: 'd_pide',
        productName: 'Poğaça',
        unitPrice: 12.5,
        validFrom: now,
      ),
    );
    // Ekran davranışını birebir taklit: başarı sonrası invalidate.
    container.invalidate(pricesByDealerProvider('d_pide'));

    final after = await container.read(pricesByDealerProvider('d_pide').future);
    expect(
      after.any((p) => p.productName == 'Poğaça' && p.unitPrice == 12.5),
      isTrue,
    );
  });

  test('Teslimat formu yolu: currentPriceFor en güncel fiyatı döner', () async {
    final repo = LocalDealerRepository(seed: true);

    // Seed: d_pide · Pide @ 20. Daha yeni valid_from ile 22 eklenince
    // teslimat formunun okuduğu currentPriceFor güncel fiyatı dönmeli.
    final base =
        await repo.currentPriceFor(dealerId: 'd_pide', productName: 'Pide');
    expect(base?.unitPrice, 20);

    await repo.addPrice(
      DealerPrice(
        id: 'p_test_pide_new',
        dealerId: 'd_pide',
        productName: 'Pide',
        unitPrice: 22,
        validFrom: DateTime.now(),
      ),
    );

    final fresh =
        await repo.currentPriceFor(dealerId: 'd_pide', productName: 'Pide');
    expect(fresh?.unitPrice, 22);
  });
}
