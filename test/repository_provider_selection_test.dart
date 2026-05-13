// Repository provider seçim testi.
//
// V1.3.3 — Provider'lar GuardedX wrapper döner; inner LocalX olur. Test artık
// wrap kontratını doğrulamayı hedefler: tip GuardedX, davranış inner Local'la
// aynı (seed dahil).
//
// AppConfig.supabaseEnabled false ise (dart-define verilmedi):
//   - bakeryRepositoryProvider → GuardedBakeryRepository(inner: LocalBakeryRepository)
//   - dealerRepositoryProvider → GuardedDealerRepository(inner: LocalDealerRepository(seed: true))

import 'package:firin_defter/features/bakery_panel/repositories/bakery_repository.dart';
import 'package:firin_defter/features/bakery_panel/repositories/guarded_bakery_repository.dart';
import 'package:firin_defter/features/bakery_panel/providers/bakery_providers.dart';
import 'package:firin_defter/features/dealers/repositories/dealer_repository.dart';
import 'package:firin_defter/features/dealers/repositories/guarded_dealer_repository.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('anahtarsız çalıştırmada bakery repo Guarded wrapper döner', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = container.read(bakeryRepositoryProvider);
    expect(repo, isA<BakeryRepository>());
    expect(repo, isA<GuardedBakeryRepository>());
  });

  test('anahtarsız çalıştırmada dealer repo Guarded wrapper + seed okunur',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = container.read(dealerRepositoryProvider);
    expect(repo, isA<DealerRepository>());
    expect(repo, isA<GuardedDealerRepository>());

    // Seed default true: 4 demo bayi inner'dan okunur (read forwards).
    final dealers = await repo.listDealers();
    expect(dealers.length, 4);
  });
}
