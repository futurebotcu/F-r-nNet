import 'dart:async';

import '../models/recipe_record.dart';
import '../services/recipe_calculator.dart';
import 'recipe_repository.dart';

/// In-memory reçete kütüphanesi.
/// Uygulama yeniden başlayınca veri kaybolur — bu kasıtlı (mevcut local repo
/// tasarımıyla uyumlu).
class LocalRecipeRepository implements RecipeRepository {
  LocalRecipeRepository({RecipeCalculator? calculator})
      : _calculator = calculator ?? const RecipeCalculator();

  final RecipeCalculator _calculator;
  final List<Recipe> _items = <Recipe>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _notify() => _changes.add(null);

  @override
  Future<List<Recipe>> list() async {
    final copy = List<Recipe>.of(_items);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  @override
  Future<List<Recipe>> listPublicByOwner(String? ownerId) async {
    if (ownerId == null || ownerId.isEmpty) return const <Recipe>[];
    final copy = _items
        .where((r) => r.isPublic && (r.ownerId == ownerId))
        .toList();
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  @override
  Future<Recipe?> getById(String id) async {
    for (final r in _items) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<Recipe> save(Recipe draft) async {
    final now = DateTime.now();
    final result = _calculator.calculateFromQuantities(
      draft.quantities,
      extras: draft.metadata.ingredients,
    );
    final metadata = draft.metadata.copyWith(updatedAt: now);

    final existingIndex = _items.indexWhere((r) => r.id == draft.id);
    if (existingIndex >= 0) {
      final prev = _items[existingIndex];
      // is_public false→true geçişi → publishedAt set; tersine → null.
      final newPublishedAt = draft.isPublic
          ? (prev.isPublic ? prev.publishedAt : now)
          : null;
      // copyWith publishedAt:null'ı "değişiklik yok" sayar; bu yüzden direkt
      // constructor kullanıyoruz.
      final updated = Recipe(
        id: prev.id,
        ownerId: prev.ownerId,
        productName: draft.productName,
        quantities: draft.quantities,
        result: result,
        metadata: metadata,
        createdAt: prev.createdAt,
        visibility: draft.visibility,
        publishedAt: newPublishedAt,
      );
      _items[existingIndex] = updated;
      _notify();
      return updated;
    }

    final id = draft.id.isNotEmpty ? draft.id : 'r_${now.microsecondsSinceEpoch}';
    final created = Recipe(
      id: id,
      ownerId: draft.ownerId,
      productName: draft.productName,
      quantities: draft.quantities,
      result: result,
      metadata: metadata,
      createdAt: now,
      visibility: draft.visibility,
      publishedAt: draft.isPublic ? now : null,
    );
    _items.add(created);
    _notify();
    return created;
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((r) => r.id == id);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;

  // Test desteği.
  void debugClear() {
    _items.clear();
    _notify();
  }
}
