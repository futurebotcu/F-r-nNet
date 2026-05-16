import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/market_listing.dart';
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

  static const String _columns =
      'id, owner_id, title, category, listing_type, condition, description, '
      'city, district, price, unit, contact_preference, is_active, '
      'author_name, author_role, created_at, updated_at';

  @override
  Future<List<MarketListing>> listActive({String? category, int limit = 100}) async {
    var q = _client
        .from('market_listings')
        .select(_columns)
        .eq('is_active', true);
    if (category != null && category.isNotEmpty) {
      q = q.eq('category', category);
    }
    final rows =
        await q.order('created_at', ascending: false).limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MarketListing.fromRow)
        .toList(growable: false);
  }

  @override
  Future<List<MarketListing>> listMine() async {
    final ownerId = _requireUserId();
    final rows = await _client
        .from('market_listings')
        .select(_columns)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MarketListing.fromRow)
        .toList(growable: false);
  }

  @override
  Future<MarketListing?> getListing(String id) async {
    _requireUserId();
    final row = await _client
        .from('market_listings')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return MarketListing.fromRow(row);
  }

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

  @override
  Stream<void> watch() => _changes.stream;
}
