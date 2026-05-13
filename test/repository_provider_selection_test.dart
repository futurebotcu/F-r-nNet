// Repository provider seçim testi.
//
// AppConfig.supabaseEnabled false ise (dart-define verilmedi):
//   - bakeryRepositoryProvider → LocalBakeryRepository
//   - dealerRepositoryProvider → LocalDealerRepository (seed: true)
//
// Supabase enabled + currentUser null ise yine Local'a düşer (yan etkisi yok,
// crash etmez). Bu test sadece "anahtarsız çalıştırma" senaryosunu kanıtlar;
// Supabase enabled durumu integration test ile karşılanır (canlı client gerekir).

import 'package:firin_defter/features/bakery_panel/repositories/bakery_repository.dart';
import 'package:firin_defter/features/bakery_panel/repositories/local_bakery_repository.dart';
import 'package:firin_defter/features/bakery_panel/providers/bakery_providers.dart';
import 'package:firin_defter/features/dealers/repositories/dealer_repository.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('anahtarsız çalıştırmada bakery repo Local impl', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = container.read(bakeryRepositoryProvider);
    expect(repo, isA<BakeryRepository>());
    expect(repo, isA<LocalBakeryRepository>());
  });

  test('anahtarsız çalıştırmada dealer repo Local impl + seed', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = container.read(dealerRepositoryProvider);
    expect(repo, isA<DealerRepository>());
    expect(repo, isA<LocalDealerRepository>());

    // Seed default true: 4 demo bayi gelmeli.
    final dealers = await repo.listDealers();
    expect(dealers.length, 4);
  });
}
