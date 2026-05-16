import '../models/market_listing.dart';

/// Marketplace ürün/hizmet/ekipman ilanları için soyut erişim.
abstract class MarketListingRepository {
  Future<List<MarketListing>> listActive({String? category, int limit = 100});
  Future<List<MarketListing>> listMine();
  Future<MarketListing?> getListing(String id);
  Future<MarketListing> upsertListing(MarketListing listing);
  Future<void> setActive(String id, bool active);
  Future<void> deleteListing(String id);
  Stream<void> watch();
}
