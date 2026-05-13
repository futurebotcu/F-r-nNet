import '../../auth/services/auth_required_guard.dart';
import '../models/recipe_record.dart';
import 'recipe_repository.dart';

/// V1.3.3 — guest write korumalı [RecipeRepository] dekoratörü.
class GuardedRecipeRepository implements RecipeRepository {
  GuardedRecipeRepository({required this.inner, required this.canWriteCheck});

  final RecipeRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  // ── Read ────────────────────────────────────────────

  @override
  Future<List<Recipe>> list() => inner.list();

  @override
  Future<List<Recipe>> listPublicByOwner(String? ownerId) =>
      inner.listPublicByOwner(ownerId);

  @override
  Future<Recipe?> getById(String id) => inner.getById(id);

  @override
  Stream<void> watch() => inner.watch();

  // ── Write (guarded) ────────────────────────────────

  @override
  Future<Recipe> save(Recipe draft) {
    _requireWrite('reçete kaydetmek');
    return inner.save(draft);
  }

  @override
  Future<void> delete(String id) {
    _requireWrite('reçete silmek');
    return inner.delete(id);
  }
}
