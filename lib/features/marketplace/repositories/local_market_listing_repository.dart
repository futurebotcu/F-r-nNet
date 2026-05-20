// FırınNet Market V1 — Local in-memory parite (test / guest / Supabase off).

import 'dart:async';
import 'dart:typed_data';

import '../models/market_filters.dart';
import '../models/market_listing.dart';
import '../models/market_listing_media.dart';
import 'market_listing_repository.dart';

class LocalMarketListingRepository implements MarketListingRepository {
  LocalMarketListingRepository({String currentUserId = 'me_misafir'})
      : _meId = currentUserId;

  final String _meId;
  final List<MarketListing> _items = <MarketListing>[];
  final Map<String, List<MarketListingMedia>> _mediaByListing =
      <String, List<MarketListingMedia>>{};
  final Set<String> _savedIds = <String>{};

  final StreamController<void> _changes =
      StreamController<void>.broadcast();
  void _notify() => _changes.add(null);

  String _genId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  bool _visible(MarketListing m) =>
      m.status == 'active' && !m.isDeleted;

  List<MarketListing> _withSidecars(Iterable<MarketListing> src) {
    return src
        .map((m) => m.copyWith(
              mediaList:
                  _mediaByListing[m.id] ?? const <MarketListingMedia>[],
              isSavedByMe: _savedIds.contains(m.id),
            ))
        .toList(growable: false);
  }

  // ─── Listing read ───────────────────────────────────────────────

  @override
  Future<List<MarketListing>> listActive({
    String? category,
    int limit = 100,
  }) async {
    final src = _items.where(_visible).where(
      (m) => category == null || m.category == category,
    );
    final sorted = src.toList()
      ..sort((a, b) {
        final ad = a.createdAt ?? DateTime(1900);
        final bd = b.createdAt ?? DateTime(1900);
        return bd.compareTo(ad);
      });
    final out = _withSidecars(
      sorted.length > limit ? sorted.take(limit) : sorted,
    );
    return List.unmodifiable(out);
  }

  @override
  Future<List<MarketListing>> listFiltered(
    MarketFilters filters, {
    int limit = 100,
  }) async {
    bool keep(MarketListing m) {
      if (!_visible(m)) return false;
      if (filters.listingType != null && m.listingType != filters.listingType) {
        return false;
      }
      if (filters.equipmentCategory != null &&
          m.equipmentCategory != filters.equipmentCategory) {
        return false;
      }
      if (filters.city != null &&
          filters.city!.isNotEmpty &&
          m.city != filters.city) {
        return false;
      }
      if (filters.district != null &&
          filters.district!.isNotEmpty &&
          m.district != filters.district) {
        return false;
      }
      if (filters.minPrice != null &&
          (m.price == null || m.price! < filters.minPrice!)) {
        return false;
      }
      if (filters.maxPrice != null &&
          (m.price == null || m.price! > filters.maxPrice!)) {
        return false;
      }
      if (filters.condition != null && m.condition != filters.condition) {
        return false;
      }
      if (filters.negotiableOnly && !m.negotiable) return false;
      return true;
    }

    final src = _items.where(keep).toList()
      ..sort((a, b) {
        final ad = a.createdAt ?? DateTime(1900);
        final bd = b.createdAt ?? DateTime(1900);
        return bd.compareTo(ad);
      });
    final out =
        _withSidecars(src.length > limit ? src.take(limit) : src);
    return List.unmodifiable(out);
  }

  @override
  Future<List<MarketListing>> listMine() async {
    final src = _items.where((m) => m.ownerId == _meId).toList()
      ..sort((a, b) {
        final ad = a.createdAt ?? DateTime(1900);
        final bd = b.createdAt ?? DateTime(1900);
        return bd.compareTo(ad);
      });
    return List.unmodifiable(_withSidecars(src));
  }

  @override
  Future<MarketListing?> getListing(String id) async {
    for (final m in _items) {
      if (m.id == id) {
        return m.copyWith(
          mediaList:
              _mediaByListing[id] ?? const <MarketListingMedia>[],
          isSavedByMe: _savedIds.contains(id),
        );
      }
    }
    return null;
  }

  // ─── Listing write ──────────────────────────────────────────────

  @override
  Future<MarketListing> upsertListing(MarketListing listing) async {
    final now = DateTime.now();
    final idx = _items.indexWhere(
      (m) => listing.id != null && m.id == listing.id,
    );
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(
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
        equipmentCategory: listing.equipmentCategory,
        currency: listing.currency,
        negotiable: listing.negotiable,
        brand: listing.brand,
        model: listing.model,
        year: listing.year,
        rentPrice: listing.rentPrice,
        transferPrice: listing.transferPrice,
        equipmentIncluded: listing.equipmentIncluded,
        hasLicense: listing.hasLicense,
        areaM2: listing.areaM2,
        contactPhone: listing.contactPhone,
        contactWhatsapp: listing.contactWhatsapp,
      );
      _notify();
      return _items[idx];
    }
    final saved = MarketListing(
      id: listing.id ?? _genId('ml'),
      ownerId: listing.ownerId ?? _meId,
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
      status: listing.status,
      isDeleted: listing.isDeleted,
      equipmentCategory: listing.equipmentCategory,
      currency: listing.currency,
      negotiable: listing.negotiable,
      brand: listing.brand,
      model: listing.model,
      year: listing.year,
      rentPrice: listing.rentPrice,
      transferPrice: listing.transferPrice,
      equipmentIncluded: listing.equipmentIncluded,
      hasLicense: listing.hasLicense,
      areaM2: listing.areaM2,
      contactPhone: listing.contactPhone,
      contactWhatsapp: listing.contactWhatsapp,
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
  Future<void> softDeleteListing(String id) async {
    final i = _items.indexWhere((m) => m.id == id);
    if (i < 0) {
      throw StateError('İlan silinemedi: kayıt bulunamadı.');
    }
    if (_items[i].ownerId != _meId) {
      throw StateError('İlan silinemedi: yetki yok.');
    }
    _items[i] = _items[i].copyWith(isDeleted: true);
    _notify();
  }

  @override
  Future<void> setStatus(String id, String status) async {
    if (!const {'active', 'sold', 'paused'}.contains(status)) {
      throw ArgumentError('Geçersiz status: $status');
    }
    final i = _items.indexWhere((m) => m.id == id);
    if (i < 0) {
      throw StateError('İlan durumu güncellenemedi: kayıt bulunamadı.');
    }
    if (_items[i].ownerId != _meId) {
      throw StateError('İlan durumu güncellenemedi: yetki yok.');
    }
    _items[i] = _items[i].copyWith(status: status);
    _notify();
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
    _mediaByListing.remove(id);
    _savedIds.remove(id);
    _notify();
  }

  // ─── Media ──────────────────────────────────────────────────────

  @override
  Future<MarketListingMedia> uploadListingImage({
    required String listingId,
    required Uint8List bytes,
    required String fileExtension,
    int sortOrder = 0,
  }) async {
    final i = _items.indexWhere((m) => m.id == listingId);
    if (i < 0) {
      throw StateError('İlan bulunamadı: $listingId');
    }
    final now = DateTime.now();
    final id = _genId('mlm');
    final ext = fileExtension.toLowerCase().replaceAll('.', '');
    final path = '${_items[i].ownerId}/$listingId/$id.$ext';
    final media = MarketListingMedia(
      id: id,
      listingId: listingId,
      ownerId: _items[i].ownerId ?? _meId,
      storagePath: path,
      publicUrl: 'local://$path',
      sortOrder: sortOrder,
      isDeleted: false,
      createdAt: now,
    );
    (_mediaByListing[listingId] ??= <MarketListingMedia>[]).add(media);
    _notify();
    return media;
  }

  @override
  Future<List<MarketListingMedia>> listListingMedia(String listingId) async {
    final list = _mediaByListing[listingId] ?? const <MarketListingMedia>[];
    final visible = list.where((m) => !m.isDeleted).toList()
      ..sort((a, b) {
        final s = a.sortOrder.compareTo(b.sortOrder);
        return s != 0 ? s : a.createdAt.compareTo(b.createdAt);
      });
    return List.unmodifiable(visible);
  }

  @override
  Future<void> deleteListingMedia(String mediaId) async {
    for (final entry in _mediaByListing.entries) {
      final i = entry.value.indexWhere((m) => m.id == mediaId);
      if (i >= 0) {
        final old = entry.value[i];
        if (old.ownerId != _meId) {
          throw StateError('Görsel silinemedi: yetki yok.');
        }
        entry.value[i] = MarketListingMedia(
          id: old.id,
          listingId: old.listingId,
          ownerId: old.ownerId,
          storagePath: old.storagePath,
          publicUrl: old.publicUrl,
          sortOrder: old.sortOrder,
          isDeleted: true,
          createdAt: old.createdAt,
        );
        _notify();
        return;
      }
    }
    throw StateError('Görsel silinemedi: kayıt bulunamadı.');
  }

  // ─── Saves ──────────────────────────────────────────────────────

  @override
  Future<void> saveListing(String listingId) async {
    _savedIds.add(listingId);
    _notify();
  }

  @override
  Future<void> unsaveListing(String listingId) async {
    _savedIds.remove(listingId);
    _notify();
  }

  @override
  Future<List<MarketListing>> listSavedListings() async {
    final src =
        _items.where((m) => _savedIds.contains(m.id) && !m.isDeleted);
    return List.unmodifiable(_withSidecars(src));
  }

  @override
  Future<Set<String>> savedListingIdsSet(List<String> listingIds) async {
    return listingIds.where(_savedIds.contains).toSet();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
