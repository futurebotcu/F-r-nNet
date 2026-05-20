// FırınNet Market V1 — Supabase impl (genişletilmiş).
//
// Pattern: feed/supabase_feed_repository.dart + stories impl'leri ile aynı:
// .select() RETURNING + empty empty StateError + storage rollback (orphan
// guard). Donor: Bagisto product/category repository iskeleti; ama veri
// katmanı tamamen Supabase + sıkı RLS.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/market_filters.dart';
import '../models/market_listing.dart';
import '../models/market_listing_media.dart';
import 'market_listing_repository.dart';

class SupabaseMarketListingRepository implements MarketListingRepository {
  SupabaseMarketListingRepository(this._client);

  final sb.SupabaseClient _client;
  final StreamController<void> _changes =
      StreamController<void>.broadcast();
  void _notify() => _changes.add(null);

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    return id;
  }

  String? get _currentUserIdOrNull => _client.auth.currentUser?.id;

  static const String _columns =
      'id, owner_id, title, category, listing_type, condition, description, '
      'city, district, price, unit, contact_preference, is_active, '
      'author_name, author_role, created_at, updated_at, '
      'status, is_deleted, equipment_category, currency, negotiable, '
      'brand, model, year, rent_price, transfer_price, '
      'equipment_included, has_license, area_m2, '
      'contact_phone, contact_whatsapp, view_count, '
      // V1 Market M2 controlled-data fix
      'country_code, city_code, district_code';

  static const String _mediaColumns =
      'id, listing_id, owner_id, storage_path, sort_order, '
      'is_deleted, created_at';

  /// RFC 4122 v4 UUID (feed image upload pattern'i).
  static String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String h(int s, int e) => bytes
        .sublist(s, e)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
  }

  static String _mimeForImageExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // ─── Internal helpers ───────────────────────────────────────────

  Future<Map<String, List<MarketListingMedia>>> _fetchMediaByListingIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const <String, List<MarketListingMedia>>{};
    try {
      final rows = await _client
          .from('market_listing_media')
          .select(_mediaColumns)
          .inFilter('listing_id', ids)
          .eq('is_deleted', false)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);
      final byId = <String, List<MarketListingMedia>>{};
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final path = r['storage_path'] as String;
        final publicUrl =
            _client.storage.from('market-media').getPublicUrl(path);
        final media = MarketListingMedia.fromRow(r, publicUrl: publicUrl);
        byId.putIfAbsent(media.listingId, () => <MarketListingMedia>[])
            .add(media);
      }
      return byId;
    } catch (_) {
      return const <String, List<MarketListingMedia>>{};
    }
  }

  Future<Set<String>> _fetchSavedSet(List<String> ids) async {
    final userId = _currentUserIdOrNull;
    if (userId == null || ids.isEmpty) return <String>{};
    try {
      final rows = await _client
          .from('market_listing_saves')
          .select('listing_id')
          .eq('user_id', userId)
          .inFilter('listing_id', ids);
      return (rows as List)
          .map((e) => (e as Map<String, dynamic>)['listing_id'] as String)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  List<MarketListing> _mapWithSidecars(
    List<Map<String, dynamic>> rows,
    Map<String, List<MarketListingMedia>> mediaByListing,
    Set<String> savedIds,
  ) {
    return rows
        .map((row) {
          final id = row['id'] as String;
          return MarketListing.fromRow(
            row,
            mediaList: mediaByListing[id] ?? const <MarketListingMedia>[],
            isSavedByMe: savedIds.contains(id),
          );
        })
        .toList(growable: false);
  }

  // ─── Listing read ───────────────────────────────────────────────

  @override
  Future<List<MarketListing>> listActive({
    String? category,
    int limit = 100,
  }) async {
    // Backward compat — eski UI; status + is_deleted defansif filtre.
    var q = _client
        .from('market_listings')
        .select(_columns)
        .eq('status', 'active')
        .eq('is_deleted', false);
    if (category != null && category.isNotEmpty) {
      q = q.eq('category', category);
    }
    final rows = await q
        .order('created_at', ascending: false)
        .limit(limit);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final ids =
        list.map((r) => r['id'] as String).toList(growable: false);
    final media = await _fetchMediaByListingIds(ids);
    final saved = await _fetchSavedSet(ids);
    return _mapWithSidecars(list, media, saved);
  }

  @override
  Future<List<MarketListing>> listFiltered(
    MarketFilters filters, {
    int limit = 100,
  }) async {
    var q = _client
        .from('market_listings')
        .select(_columns)
        .eq('status', 'active')
        .eq('is_deleted', false);
    if (filters.listingType != null) {
      q = q.eq('listing_type', filters.listingType!);
    }
    if (filters.equipmentCategory != null) {
      q = q.eq('equipment_category', filters.equipmentCategory!);
    }
    // V1 Market M2 controlled-data fix: filtreleme canonical kod üzerinden.
    // city/district text alanları sadece display label; serbest-text
    // filtreleme dropped (veri kalitesi nedeniyle).
    if (filters.countryCode != null && filters.countryCode!.isNotEmpty) {
      q = q.eq('country_code', filters.countryCode!);
    }
    if (filters.cityCode != null && filters.cityCode!.isNotEmpty) {
      q = q.eq('city_code', filters.cityCode!);
    }
    if (filters.districtCode != null && filters.districtCode!.isNotEmpty) {
      q = q.eq('district_code', filters.districtCode!);
    }
    if (filters.minPrice != null) {
      q = q.gte('price', filters.minPrice!);
    }
    if (filters.maxPrice != null) {
      q = q.lte('price', filters.maxPrice!);
    }
    if (filters.condition != null) {
      q = q.eq('condition', filters.condition!);
    }
    if (filters.negotiableOnly) {
      q = q.eq('negotiable', true);
    }
    final rows = await q
        .order('created_at', ascending: false)
        .limit(limit);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final ids =
        list.map((r) => r['id'] as String).toList(growable: false);
    final media = await _fetchMediaByListingIds(ids);
    final saved = await _fetchSavedSet(ids);
    return _mapWithSidecars(list, media, saved);
  }

  @override
  Future<List<MarketListing>> listMine() async {
    final ownerId = _requireUserId();
    final rows = await _client
        .from('market_listings')
        .select(_columns)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final ids =
        list.map((r) => r['id'] as String).toList(growable: false);
    final media = await _fetchMediaByListingIds(ids);
    final saved = await _fetchSavedSet(ids);
    return _mapWithSidecars(list, media, saved);
  }

  @override
  Future<MarketListing?> getListing(String id) async {
    final row = await _client
        .from('market_listings')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final media = await _fetchMediaByListingIds(<String>[id]);
    final saved = await _fetchSavedSet(<String>[id]);
    return MarketListing.fromRow(
      row,
      mediaList: media[id] ?? const <MarketListingMedia>[],
      isSavedByMe: saved.contains(id),
    );
  }

  // ─── Listing write ──────────────────────────────────────────────

  @override
  Future<MarketListing> upsertListing(MarketListing listing) async {
    final ownerId = _requireUserId();
    final payload = listing.toInsertRow(ownerId);
    Map<String, dynamic> row;
    if (listing.id == null || listing.id!.startsWith('ml_')) {
      row = await _client
          .from('market_listings')
          .insert(payload)
          .select(_columns)
          .single();
    } else {
      row = await _client
          .from('market_listings')
          .update(<String, dynamic>{
            ...payload,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', listing.id!)
          .eq('owner_id', ownerId)
          .select(_columns)
          .single();
    }
    _notify();
    return MarketListing.fromRow(row);
  }

  @override
  Future<void> softDeleteListing(String id) async {
    final ownerId = _requireUserId();
    // Sosyal sprint dersi: .select('id') empty → StateError. Silent
    // fail engellenir, UI gerçek hatayı görür.
    final rows = await _client
        .from('market_listings')
        .update(<String, dynamic>{'is_deleted': true})
        .eq('id', id)
        .eq('owner_id', ownerId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw StateError(
        'İlan silinemedi: yetki yok veya kayıt bulunamadı.',
      );
    }
    _notify();
  }

  @override
  Future<void> setStatus(String id, String status) async {
    final ownerId = _requireUserId();
    if (!const {'active', 'sold', 'paused'}.contains(status)) {
      throw ArgumentError('Geçersiz status: $status');
    }
    final rows = await _client
        .from('market_listings')
        .update(<String, dynamic>{'status': status})
        .eq('id', id)
        .eq('owner_id', ownerId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw StateError(
        'İlan durumu güncellenemedi: yetki yok veya kayıt bulunamadı.',
      );
    }
    _notify();
  }

  @override
  Future<void> setActive(String id, bool active) async {
    final ownerId = _requireUserId();
    await _client
        .from('market_listings')
        .update(<String, dynamic>{'is_active': active})
        .eq('id', id)
        .eq('owner_id', ownerId);
    _notify();
  }

  @override
  Future<void> deleteListing(String id) async {
    final ownerId = _requireUserId();
    await _client
        .from('market_listings')
        .delete()
        .eq('id', id)
        .eq('owner_id', ownerId);
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
    final userId = _requireUserId();
    final ext = fileExtension.toLowerCase().replaceAll('.', '');
    final mediaId = _generateUuidV4();
    final path = '$userId/$listingId/$mediaId.$ext';
    final mime = _mimeForImageExt(ext);

    // 1) Storage upload — path-prefix RLS owner_id=auth.uid().
    await _client.storage.from('market-media').uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(contentType: mime, upsert: false),
        );

    final publicUrl =
        _client.storage.from('market-media').getPublicUrl(path);

    // 2) DB INSERT — fail olursa storage rollback.
    try {
      final row = await _client
          .from('market_listing_media')
          .insert(<String, dynamic>{
            'id': mediaId,
            'listing_id': listingId,
            'owner_id': userId,
            'storage_path': path,
            'sort_order': sortOrder,
          })
          .select(_mediaColumns)
          .single();
      _notify();
      return MarketListingMedia.fromRow(row, publicUrl: publicUrl);
    } catch (e) {
      try {
        await _client.storage.from('market-media').remove(<String>[path]);
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<List<MarketListingMedia>> listListingMedia(String listingId) async {
    final rows = await _client
        .from('market_listing_media')
        .select(_mediaColumns)
        .eq('listing_id', listingId)
        .eq('is_deleted', false)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>().map((r) {
      final path = r['storage_path'] as String;
      final publicUrl =
          _client.storage.from('market-media').getPublicUrl(path);
      return MarketListingMedia.fromRow(r, publicUrl: publicUrl);
    }).toList(growable: false);
  }

  @override
  Future<void> deleteListingMedia(String mediaId) async {
    final ownerId = _requireUserId();
    final rows = await _client
        .from('market_listing_media')
        .update(<String, dynamic>{'is_deleted': true})
        .eq('id', mediaId)
        .eq('owner_id', ownerId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw StateError(
        'Görsel silinemedi: yetki yok veya kayıt bulunamadı.',
      );
    }
    _notify();
  }

  // ─── Saves ──────────────────────────────────────────────────────

  @override
  Future<void> saveListing(String listingId) async {
    final userId = _requireUserId();
    // Composite PK (listing_id, user_id) idempotent; çift-tap 23505 yutalım.
    try {
      await _client.from('market_listing_saves').insert(<String, dynamic>{
        'listing_id': listingId,
        'user_id': userId,
      });
    } on sb.PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
    _notify();
  }

  @override
  Future<void> unsaveListing(String listingId) async {
    final userId = _requireUserId();
    await _client
        .from('market_listing_saves')
        .delete()
        .eq('listing_id', listingId)
        .eq('user_id', userId);
    _notify();
  }

  @override
  Future<List<MarketListing>> listSavedListings() async {
    final userId = _requireUserId();
    final saveRows = await _client
        .from('market_listing_saves')
        .select('listing_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final ids = (saveRows as List)
        .map((e) => (e as Map<String, dynamic>)['listing_id'] as String)
        .toList(growable: false);
    if (ids.isEmpty) return const <MarketListing>[];
    final rows = await _client
        .from('market_listings')
        .select(_columns)
        .inFilter('id', ids)
        .eq('is_deleted', false);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final mediaByListing = await _fetchMediaByListingIds(ids);
    final savedSet = ids.toSet();
    // saves order ile listing'i sıralı tut
    final byId = <String, Map<String, dynamic>>{
      for (final r in list) r['id'] as String: r,
    };
    final ordered = <Map<String, dynamic>>[];
    for (final id in ids) {
      final r = byId[id];
      if (r != null) ordered.add(r);
    }
    return _mapWithSidecars(ordered, mediaByListing, savedSet);
  }

  @override
  Future<Set<String>> savedListingIdsSet(List<String> listingIds) =>
      _fetchSavedSet(listingIds);

  @override
  Stream<void> watch() => _changes.stream;
}
