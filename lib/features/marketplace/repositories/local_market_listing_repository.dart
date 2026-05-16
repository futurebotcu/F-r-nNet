import 'dart:async';

import '../models/market_listing.dart';
import 'market_listing_repository.dart';

class LocalMarketListingRepository implements MarketListingRepository {
  final List<MarketListing> _items = <MarketListing>[];
  final StreamController<void> _changes =
      StreamController<void>.broadcast();
  void _notify() => _changes.add(null);
  String _gen() => 'ml_${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<List<MarketListing>> listActive({String? category, int limit = 100}) async {
    final out = _items.where((m) => m.isActive).toList();
    final filtered = category == null
        ? out
        : out.where((m) => m.category == category).toList();
    filtered.sort((a, b) {
      final ad = a.createdAt ?? DateTime(1900);
      final bd = b.createdAt ?? DateTime(1900);
      return bd.compareTo(ad);
    });
    if (filtered.length > limit) filtered.length = limit;
    return List.unmodifiable(filtered);
  }

  @override
  Future<List<MarketListing>> listMine() async {
    final out = List<MarketListing>.from(_items);
    out.sort((a, b) {
      final ad = a.createdAt ?? DateTime(1900);
      final bd = b.createdAt ?? DateTime(1900);
      return bd.compareTo(ad);
    });
    return List.unmodifiable(out);
  }

  @override
  Future<MarketListing?> getListing(String id) async {
    for (final m in _items) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  Future<MarketListing> upsertListing(MarketListing listing) async {
    final now = DateTime.now();
    final idx = _items.indexWhere((m) => m.id == listing.id && listing.id != null);
    if (idx >= 0) {
      _items[idx] = MarketListing(
        id: _items[idx].id,
        ownerId: _items[idx].ownerId,
        title: listing.title,
        category: listing.category,
        listingType: listing.listingType,
        condition: listing.condition,
        description: listing.description,
        city: listing.city,
        district: listing.district,
        price: listing.price,
        unit: listing.unit,
        contactPreference: listing.contactPreference,
        isActive: listing.isActive,
        authorName: _items[idx].authorName,
        authorRole: _items[idx].authorRole,
        createdAt: _items[idx].createdAt,
        updatedAt: now,
      );
      _notify();
      return _items[idx];
    }
    final saved = MarketListing(
      id: listing.id ?? _gen(),
      ownerId: listing.ownerId,
      title: listing.title,
      category: listing.category,
      listingType: listing.listingType,
      condition: listing.condition,
      description: listing.description,
      city: listing.city,
      district: listing.district,
      price: listing.price,
      unit: listing.unit,
      contactPreference: listing.contactPreference,
      isActive: listing.isActive,
      authorName: listing.authorName,
      authorRole: listing.authorRole,
      createdAt: listing.createdAt ?? now,
      updatedAt: now,
    );
    _items.add(saved);
    _notify();
    return saved;
  }

  @override
  Future<void> setActive(String id, bool active) async {
    final i = _items.indexWhere((m) => m.id == id);
    if (i < 0) return;
    _items[i] = _items[i].copyWith(isActive: active);
    _notify();
  }

  @override
  Future<void> deleteListing(String id) async {
    _items.removeWhere((m) => m.id == id);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
