// FırınNet Market V1 — guest write guard dekoratörü (genişletilmiş).

import 'dart:typed_data';

import '../../auth/services/auth_required_guard.dart';
import '../models/market_filters.dart';
import '../models/market_listing.dart';
import '../models/market_listing_media.dart';
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

  // ─── Read (delege) ──────────────────────────────────────────────

  @override
  Future<List<MarketListing>> listActive({
    String? category,
    int limit = 100,
  }) =>
      inner.listActive(category: category, limit: limit);

  @override
  Future<List<MarketListing>> listFiltered(
    MarketFilters filters, {
    int limit = 100,
  }) =>
      inner.listFiltered(filters, limit: limit);

  @override
  Future<List<MarketListing>> listMine() => inner.listMine();

  @override
  Future<MarketListing?> getListing(String id) => inner.getListing(id);

  @override
  Future<List<MarketListingMedia>> listListingMedia(String listingId) =>
      inner.listListingMedia(listingId);

  @override
  Future<List<MarketListing>> listSavedListings() => inner.listSavedListings();

  @override
  Future<Set<String>> savedListingIdsSet(List<String> listingIds) =>
      inner.savedListingIdsSet(listingIds);

  // ─── Write (guarded) ────────────────────────────────────────────

  @override
  Future<MarketListing> upsertListing(MarketListing listing) {
    _requireWrite('market ilanı kaydetmek');
    return inner.upsertListing(listing);
  }

  @override
  Future<void> softDeleteListing(String id) {
    _requireWrite('market ilanını silmek');
    return inner.softDeleteListing(id);
  }

  @override
  Future<void> setStatus(String id, String status) {
    _requireWrite('market ilanı durumunu güncellemek');
    return inner.setStatus(id, status);
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
  Future<MarketListingMedia> uploadListingImage({
    required String listingId,
    required Uint8List bytes,
    required String fileExtension,
    int sortOrder = 0,
  }) {
    _requireWrite('market ilanına görsel eklemek');
    return inner.uploadListingImage(
      listingId: listingId,
      bytes: bytes,
      fileExtension: fileExtension,
      sortOrder: sortOrder,
    );
  }

  @override
  Future<void> deleteListingMedia(String mediaId) {
    _requireWrite('market ilan görselini silmek');
    return inner.deleteListingMedia(mediaId);
  }

  @override
  Future<void> saveListing(String listingId) {
    _requireWrite('market ilanını kaydetmek');
    return inner.saveListing(listingId);
  }

  @override
  Future<void> unsaveListing(String listingId) {
    _requireWrite('market ilanı kaydını kaldırmak');
    return inner.unsaveListing(listingId);
  }

  @override
  Stream<void> watch() => inner.watch();
}
