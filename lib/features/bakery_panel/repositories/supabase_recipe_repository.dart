import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/recipe_metadata.dart';
import '../models/recipe_quantities.dart';
import '../models/recipe_record.dart';
import '../services/recipe_calculator.dart';
import 'recipe_repository.dart';

/// Supabase implementasyonu — `recipe_calculations` tablosu + jsonb `metadata`
/// + `is_public`/`published_at` sütunları.
///
/// V1.1: kullanıcı gerçek miktar girer; tablodaki yüzde sütunları (water_percent
/// vb.) yalnız geriye dönük uyumluluk için repository'de türetilir. Otorite
/// kaynak `metadata.quantities` JSON'udur — okuma yaparken hesap buradan
/// yeniden üretilir (UI estimated_count'u tutarlı kalır).
///
/// Sözleşme:
/// - INSERT/UPDATE: `owner_id = auth.uid()` zorunlu. RLS owner-only.
/// - SELECT: owner kendi tüm kayıtlarını + diğer authenticated başkasının
///   `is_public = true` kayıtlarını okuyabilir (yeni policy).
/// - Trigger'a dokunulmaz; tablodaki kg sütunları trigger tarafından
///   yüzde→kg formülüyle doldurulur, ama UI bunlara güvenmez (UI extras
///   dahil hesabı `RecipeCalculator.calculateFromQuantities` ile yapar).
class SupabaseRecipeRepository implements RecipeRepository {
  SupabaseRecipeRepository(this._client, {RecipeCalculator? calculator})
      : _calculator = calculator ?? const RecipeCalculator();

  final sb.SupabaseClient _client;
  final RecipeCalculator _calculator;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _notify() => _changes.add(null);

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    return id;
  }

  static const String _columns =
      'id, owner_id, product_name, flour_kg, water_percent, yeast_percent, '
      'salt_percent, unit_weight_gr, waste_percent, water_kg, yeast_kg, '
      'salt_kg, total_dough_kg, net_dough_kg, estimated_count, metadata, '
      'is_public, published_at, created_at';

  Recipe _fromRow(Map<String, dynamic> row) {
    final metadataMap = (row['metadata'] as Map?)?.cast<String, dynamic>();
    final metadata = RecipeMetadata.fromJson(metadataMap);
    final quantitiesMap =
        (metadataMap?['quantities'] as Map?)?.cast<String, dynamic>();

    // Otorite kaynak metadata.quantities; yoksa tablodaki kg sütunlarından kur.
    final quantities = quantitiesMap != null
        ? RecipeQuantities.fromJson(quantitiesMap)
        : RecipeQuantities(
            flourKg: ((row['flour_kg'] as num?) ?? 0).toDouble(),
            waterKg: ((row['water_kg'] as num?) ?? 0).toDouble(),
            yeastKg: ((row['yeast_kg'] as num?) ?? 0).toDouble(),
            saltKg: ((row['salt_kg'] as num?) ?? 0).toDouble(),
            pieceWeightG:
                ((row['unit_weight_gr'] as num?) ?? 1).toDouble(),
            wasteKg: _waste(
              total: ((row['total_dough_kg'] as num?) ?? 0).toDouble(),
              net: ((row['net_dough_kg'] as num?) ?? 0).toDouble(),
            ),
          );

    // UI sonucu daima quantities + extras üzerinden — extras tablodaki
    // trigger'a dahil değildi; bu yüzden client-side recompute.
    final result = _calculator.calculateFromQuantities(
      quantities,
      extras: metadata.ingredients,
    );

    final isPublic = (row['is_public'] as bool?) ?? false;
    final publishedAtStr = row['published_at'] as String?;

    return Recipe(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String?,
      productName: (row['product_name'] as String?) ?? '',
      quantities: quantities,
      result: result,
      metadata: metadata,
      createdAt: DateTime.parse(row['created_at'] as String),
      visibility:
          isPublic ? RecipeVisibility.public : RecipeVisibility.private,
      publishedAt:
          publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null,
    );
  }

  static double _waste({required double total, required double net}) {
    if (total <= 0 || net >= total) return 0;
    return (total - net).clamp(0, total).toDouble();
  }

  /// Gerçek miktarları tablodaki yüzde sütunlarına çevirir.
  /// Hesaplanan kg sütunları (water_kg vs.) trigger tarafından dolduruluyor —
  /// burada yalnız 4 yüzde + flour_kg + unit_weight_gr + waste_percent yollanır.
  Map<String, dynamic> _toRow(Recipe draft, String ownerId) {
    final q = draft.quantities;
    final flourKg = q.flourKg <= 0 ? 0.001 : q.flourKg;
    final baseTotal = q.flourKg + q.waterKg + q.yeastKg + q.saltKg;
    final wastePercent = baseTotal > 0
        ? (q.wasteKg / baseTotal * 100.0).clamp(0, 100).toDouble()
        : 0.0;

    // Otorite quantities + extras metadata içinde JSON olarak.
    final enrichedMeta = draft.metadata.copyWith(
      updatedAt: DateTime.now().toUtc(),
    );
    final metaJson = <String, dynamic>{
      ...enrichedMeta.toJson(),
      'quantities': q.toJson(),
    };

    return <String, dynamic>{
      'owner_id': ownerId,
      'product_name': draft.productName,
      'flour_kg': flourKg,
      'water_percent': (q.waterKg / flourKg * 100.0).clamp(0, 1e6).toDouble(),
      'yeast_percent': (q.yeastKg / flourKg * 100.0).clamp(0, 1e6).toDouble(),
      'salt_percent': (q.saltKg / flourKg * 100.0).clamp(0, 1e6).toDouble(),
      'unit_weight_gr':
          q.pieceWeightG <= 0 ? 1.0 : q.pieceWeightG,
      'waste_percent': wastePercent,
      'metadata': metaJson,
      'is_public': draft.isPublic,
      // published_at server-side ayarlamadığımız için client now() yolluyoruz.
      // Toggle false→true ise set, true→true ise koru, public→private ise null.
      'published_at': draft.isPublic
          ? (draft.publishedAt ?? DateTime.now().toUtc()).toIso8601String()
          : null,
    };
  }

  @override
  Future<List<Recipe>> list() async {
    final ownerId = _requireUserId();
    final rows = await _client
        .from('recipe_calculations')
        .select(_columns)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_fromRow)
        .toList(growable: false);
  }

  @override
  Future<List<Recipe>> listPublicByOwner(String? ownerId) async {
    if (ownerId == null || ownerId.isEmpty) return const <Recipe>[];
    // RLS: authenticated kullanıcı sahibinin is_public=true reçetelerini okur.
    final rows = await _client
        .from('recipe_calculations')
        .select(_columns)
        .eq('owner_id', ownerId)
        .eq('is_public', true)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_fromRow)
        .toList(growable: false);
  }

  @override
  Future<Recipe?> getById(String id) async {
    // SELECT policy: owner OR is_public=true. Her iki durum da bu sorguyu geçer.
    final row = await _client
        .from('recipe_calculations')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _fromRow(row);
  }

  @override
  Future<Recipe> save(Recipe draft) async {
    final ownerId = _requireUserId();
    final payload = _toRow(draft, ownerId);

    Map<String, dynamic> row;
    if (draft.id.isEmpty || draft.id.startsWith('r_')) {
      row = await _client
          .from('recipe_calculations')
          .insert(payload)
          .select(_columns)
          .single();
    } else {
      row = await _client
          .from('recipe_calculations')
          .update(payload)
          .eq('id', draft.id)
          .eq('owner_id', ownerId)
          .select(_columns)
          .single();
    }
    _notify();
    return _fromRow(row);
  }

  @override
  Future<void> delete(String id) async {
    final ownerId = _requireUserId();
    await _client
        .from('recipe_calculations')
        .delete()
        .eq('id', id)
        .eq('owner_id', ownerId);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
