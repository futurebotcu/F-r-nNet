import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/market_filters.dart';
import '../models/market_listing.dart';
import '../repositories/guarded_market_listing_repository.dart';
import '../repositories/local_market_listing_repository.dart';
import '../repositories/market_listing_repository.dart';
import '../repositories/supabase_market_listing_repository.dart';

final marketListingRepositoryProvider =
    Provider<MarketListingRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  final MarketListingRepository inner;
  if (AppConfig.supabaseEnabled && user != null) {
    inner = SupabaseMarketListingRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalMarketListingRepository();
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedMarketListingRepository(
      inner: inner, canWriteCheck: canWrite);
});

final marketListingChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(marketListingRepositoryProvider);
  return repo.watch();
});

final activeMarketListingsProvider = FutureProvider.family
    .autoDispose<List<MarketListing>, String?>((ref, category) async {
  ref.watch(marketListingChangesProvider);
  return ref
      .watch(marketListingRepositoryProvider)
      .listActive(category: category);
});

final myMarketListingsProvider =
    FutureProvider<List<MarketListing>>((ref) async {
  ref.watch(marketListingChangesProvider);
  return ref.watch(marketListingRepositoryProvider).listMine();
});

/// V2 Market expansion — filter object + media/saves sidecar.
/// `MarketFilters` immutable + Object.hash sayesinde family cache OK.
final filteredMarketListingsProvider = FutureProvider.family
    .autoDispose<List<MarketListing>, MarketFilters>((ref, filters) async {
  ref.watch(marketListingChangesProvider);
  return ref
      .watch(marketListingRepositoryProvider)
      .listFiltered(filters);
});

/// V2 Market expansion — tek bir ilan + media + isSavedByMe.
final marketListingByIdProvider = FutureProvider.family
    .autoDispose<MarketListing?, String>((ref, id) async {
  ref.watch(marketListingChangesProvider);
  return ref.watch(marketListingRepositoryProvider).getListing(id);
});

/// V2 Market expansion — kullanıcının kaydettiği ilanlar.
final savedMarketListingsProvider =
    FutureProvider.autoDispose<List<MarketListing>>((ref) async {
  ref.watch(marketListingChangesProvider);
  return ref.watch(marketListingRepositoryProvider).listSavedListings();
});
