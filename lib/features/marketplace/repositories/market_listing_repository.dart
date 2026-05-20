// FırınNet Market V1 — repository interface (genişletilmiş).
//
// V1 (commit M1) genişletmesi: filter, status, soft-delete, media,
// saves. Donor pattern: Bagisto opensource-ecommerce-mobile-app
// (product/category repository iskeleti). FırınNet'te BLoC yerine
// Riverpod + Supabase.

import 'dart:typed_data';

import '../models/market_filters.dart';
import '../models/market_listing.dart';
import '../models/market_listing_media.dart';

abstract class MarketListingRepository {
  // ─── Listing (V1 backward + V2 filtered) ────────────────────────

  /// V1 backward: kategori-temelli liste (eski marketplace_screen.dart).
  Future<List<MarketListing>> listActive({String? category, int limit = 100});

  /// V2 expansion: filter object + media + saved cross-check.
  /// status='active' AND is_deleted=false zorunlu; client policy zaten
  /// RLS ile aynı koşulu uygular.
  Future<List<MarketListing>> listFiltered(
    MarketFilters filters, {
    int limit = 100,
  });

  /// Owner kendi tüm ilanları (paused/sold/soft-deleted dahil).
  Future<List<MarketListing>> listMine();

  /// Single listing + media + isSavedByMe.
  Future<MarketListing?> getListing(String id);

  /// V1 upsert (id null/ml_ prefix → insert; aksi update).
  Future<MarketListing> upsertListing(MarketListing listing);

  /// V2 soft-delete (is_deleted=true). RLS owner self RETURNING için
  /// SELECT policy `(active+visible) OR owner_id=auth.uid()`.
  Future<void> softDeleteListing(String id);

  /// V2 status değiştir ('active' | 'sold' | 'paused').
  Future<void> setStatus(String id, String status);

  /// V1 backward: is_active toggle. Yeni kod setStatus kullansın.
  Future<void> setActive(String id, bool active);

  /// V1 backward: hard delete. V2'de soft-delete tercih edilir.
  Future<void> deleteListing(String id);

  // ─── Media ──────────────────────────────────────────────────────

  /// Storage upload + market_listing_media INSERT.
  /// Path: {owner_id}/{listing_id}/{media_id}.{ext}.
  /// Fail olursa storage rollback (orphan engelle).
  Future<MarketListingMedia> uploadListingImage({
    required String listingId,
    required Uint8List bytes,
    required String fileExtension,
    int sortOrder = 0,
  });

  Future<List<MarketListingMedia>> listListingMedia(String listingId);

  /// Soft-delete (`is_deleted=true`). Storage object orphan — V2 cleanup.
  Future<void> deleteListingMedia(String mediaId);

  // ─── Saves ──────────────────────────────────────────────────────

  Future<void> saveListing(String listingId);
  Future<void> unsaveListing(String listingId);
  Future<List<MarketListing>> listSavedListings();

  /// Detail/card render'da batch isSavedByMe çekmek için.
  Future<Set<String>> savedListingIdsSet(List<String> listingIds);

  // ─── Mutation tick ──────────────────────────────────────────────

  Stream<void> watch();
}
