// Bayi Defteri Hardening Sprinti — C) Toptancı izolasyon kanıtı.
//
// Toptancı yüzeyi (WholesaleCustomersScreen) verisini
// `dealersByTypeProvider(DealerCustomerType.wholesaleCustomer)` ile çeker.
// Bu test, tip-bazlı izolasyonu kanıtlar: toptancı yalnız `wholesale_customer`
// kayıtlarını görür; `bakery_dealer` (ticari bayi) kayıtları sızmaz.
//
// NOT — KAPSAM DIŞI (yalnız cihaz/RLS ile doğrulanır, fake repo single-tenant):
//   * Başka owner'ın bayisini/müşterisini görememe → `dealers_select_own`
//     (owner_id = auth.uid()) RLS politikası. LocalDealerRepository tek
//     kiracılıdır; çapraz-owner sızıntısı widget testiyle KANITLANAMAZ →
//     cihaz UAT (§ PR raporu) ile doğrulanır.
//
// Mevcut testlerde zaten kapsanan (burada tekrar edilmez):
//   * Toptancı /dealers → /wholesale/customers redirect →
//     dealer_shell_screen_test.dart
//   * Toptancı Şoförler ekranına erişim →
//     dealer_wholesale_drivers_entry_test.dart

import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDealerRepository repo;
  late ProviderContainer container;

  setUp(() async {
    repo = LocalDealerRepository(seed: false);
    final now = DateTime.now();
    await repo.upsertDealer(
      Dealer(
        id: 'w1',
        name: 'Toptancı Müşterisi A',
        createdAt: now,
        customerType: DealerCustomerType.wholesaleCustomer,
      ),
    );
    await repo.upsertDealer(
      Dealer(
        id: 'b1',
        name: 'Fırın Bayisi B',
        createdAt: now,
        // customerType varsayılan: bakeryDealer
      ),
    );
    container = ProviderContainer(
      overrides: [dealerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('Toptancı yalnız wholesale_customer kayıtlarını görür (bayi sızmaz)',
      () async {
    final customers = await container.read(
      dealersByTypeProvider(DealerCustomerType.wholesaleCustomer).future,
    );
    expect(customers.map((d) => d.id), ['w1']);
    expect(
      customers.any((d) => d.customerType == DealerCustomerType.bakeryDealer),
      isFalse,
    );
  });

  test('Ticari yüzeyi yalnız bakery_dealer kayıtlarını görür (müşteri sızmaz)',
      () async {
    final dealers = await container.read(
      dealersByTypeProvider(DealerCustomerType.bakeryDealer).future,
    );
    expect(dealers.map((d) => d.id), ['b1']);
    expect(
      dealers.any((d) => d.customerType == DealerCustomerType.wholesaleCustomer),
      isFalse,
    );
  });
}
