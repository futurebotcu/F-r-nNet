import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/daily_summary.dart';
import '../models/recipe_record.dart';
import '../repositories/bakery_repository.dart';
import '../repositories/local_bakery_repository.dart';
import '../repositories/local_recipe_repository.dart';
import '../repositories/recipe_repository.dart';
import '../repositories/supabase_bakery_repository.dart';
import '../repositories/supabase_recipe_repository.dart';
import '../services/recipe_calculator.dart';
import '../services/recipe_share_text_builder.dart';
import '../services/report_builder.dart';

/// Bakery repository — Supabase yapılandırılmış + oturum açık ise gerçek
/// veri katmanı; aksi halde in-memory local (eski mock akış korunur).
final bakeryRepositoryProvider = Provider<BakeryRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  if (AppConfig.supabaseEnabled && user != null) {
    return SupabaseBakeryRepository(sb.Supabase.instance.client);
  }
  return LocalBakeryRepository();
});

final recipeCalculatorProvider = Provider<RecipeCalculator>((ref) {
  return const RecipeCalculator();
});

final recipeShareTextBuilderProvider = Provider<RecipeShareTextBuilder>((ref) {
  return const RecipeShareTextBuilder();
});

/// Reçete kütüphanesi repository — Supabase yapılandırılmış + oturum açık ise
/// SupabaseRecipeRepository; aksi halde LocalRecipeRepository (in-memory).
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  if (AppConfig.supabaseEnabled && user != null) {
    return SupabaseRecipeRepository(sb.Supabase.instance.client);
  }
  return LocalRecipeRepository();
});

/// Repository değişikliklerini dinleyen "tick" sayacı.
final recipeChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.watch();
});

/// Kullanıcının kayıtlı reçeteleri.
final recipesListProvider = FutureProvider<List<Recipe>>((ref) async {
  ref.watch(recipeChangesProvider);
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.list();
});

/// Bir sahibin `is_public = true` reçeteleri (profil "Açık Reçeteler" için).
/// Boş/null ownerId → boş liste.
final publicRecipesByOwnerProvider =
    FutureProvider.autoDispose.family<List<Recipe>, String?>(
        (ref, ownerId) async {
  ref.watch(recipeChangesProvider);
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.listPublicByOwner(ownerId);
});

final reportBuilderProvider = Provider<ReportBuilder>((ref) {
  return const ReportBuilder();
});

/// Repository değişikliklerini dinleyen "tick" sayacı.
final bakeryChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(bakeryRepositoryProvider);
  return repo.watch();
});

/// "Bugün"ü tetik olarak repository değişikliklerine bağlanmış özet.
final todaySummaryProvider = FutureProvider<DailySummary>((ref) async {
  ref.watch(bakeryChangesProvider);
  final repo = ref.watch(bakeryRepositoryProvider);
  final now = DateTime.now();
  return repo.dailySummary(DateTime(now.year, now.month, now.day));
});
