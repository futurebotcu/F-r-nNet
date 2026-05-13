import '../models/recipe_record.dart';

/// Reçete kütüphanesine soyut erişim.
///
/// V1.1 implementasyonları:
/// - LocalRecipeRepository — in-memory, Supabase yokken kullanılır.
/// - SupabaseRecipeRepository — `recipe_calculations` tablosu + jsonb
///   `metadata` sütununu okur/yazar. RLS owner CRUD + is_public select.
abstract class RecipeRepository {
  /// Sahibin tüm reçeteleri (gizli + açık birlikte).
  Future<List<Recipe>> list();

  /// Belirli bir sahibin yalnız `is_public = true` reçeteleri.
  /// Profil sayfasındaki "Açık Reçeteler" bölümü için.
  /// [ownerId] null veya boşsa boş liste döner.
  Future<List<Recipe>> listPublicByOwner(String? ownerId);

  Future<Recipe?> getById(String id);
  Future<Recipe> save(Recipe draft);
  Future<void> delete(String id);

  /// Repository içeriği değiştiğinde yayın.
  Stream<void> watch();
}
