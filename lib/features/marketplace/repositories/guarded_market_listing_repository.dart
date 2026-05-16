import '../../auth/services/auth_required_guard.dart';
import '../models/market_listing.dart';
import 'market_listing_repository.dart';

class GuardedMarketListingRepository implements MarketListingRepository {
  GuardedMarketListingRepository({
    required this.inner,
    required this.canWriteCheck,
  });

  final MarketListingRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  @override
  Future<List<MarketListing>> listActive({String? category, int limit = 100}) =>
      inner.listActive(category: category, limit: limit);

  @override
  Future<List<MarketListing>> listMine() => inner.listMine();

  @override
  Future<MarketListing?> getListing(String id) => inner.getListing(id);

  @override
  Future<MarketListing> upsertListing(MarketListing listing) {
    _requireWrite('market ilanı kaydetmek');
    return inner.upsertListing(listing);
  }

  @override
  Future<void> setActive(String id, bool active) {
    _requireWrite('market ilanı durumunu güncellemek');
    return inner.setActive(id, active);
  }

  @override
  Future<void> deleteListing(String id) {
    _requireWrite('market ilanı silmek');
    return inner.deleteListing(id);
  }

  @override
  Stream<void> watch() => inner.watch();
}
