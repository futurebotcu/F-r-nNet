import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/bakery_day_book.dart';
import '../models/bakery_task.dart';
import '../models/daily_summary.dart';
import '../models/ledger_range_report.dart';
import '../models/recipe_record.dart';
import '../repositories/bakery_repository.dart';
import '../repositories/guarded_bakery_repository.dart';
import '../repositories/guarded_recipe_repository.dart';
import '../repositories/local_bakery_repository.dart';
import '../repositories/local_recipe_repository.dart';
import '../repositories/recipe_repository.dart';
import '../repositories/supabase_bakery_repository.dart';
import '../repositories/supabase_recipe_repository.dart';
import '../services/recipe_calculator.dart';
import '../services/recipe_share_text_builder.dart';
import '../services/report_builder.dart';

/// V1.3.3 — Guarded wrapper ile sarılı bakery repository.
final bakeryRepositoryProvider = Provider<BakeryRepository>((ref) {
  // P0 kalıbı: yalnız userId izlenir (token refresh repo resetlemesin).
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  final BakeryRepository inner;
  if (AppConfig.supabaseEnabled && userId != null) {
    inner = SupabaseBakeryRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalBakeryRepository();
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedBakeryRepository(inner: inner, canWriteCheck: canWrite);
});

final recipeCalculatorProvider = Provider<RecipeCalculator>((ref) {
  return const RecipeCalculator();
});

final recipeShareTextBuilderProvider = Provider<RecipeShareTextBuilder>((ref) {
  return const RecipeShareTextBuilder();
});

/// V1.3.3 — Guarded wrapper ile sarılı recipe repository.
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  // P0 kalıbı: yalnız userId izlenir (token refresh repo resetlemesin).
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  final RecipeRepository inner;
  if (AppConfig.supabaseEnabled && userId != null) {
    inner = SupabaseRecipeRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalRecipeRepository();
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedRecipeRepository(inner: inner, canWriteCheck: canWrite);
});

/// Repository değişikliklerini dinleyen "tick" sayacı.
final recipeChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.watch();
});

/// Kullanıcının kayıtlı reçeteleri.
///
/// V1.4 P1.1 — autoDispose: ekran kapanınca cache temizlenir. Auth/role
/// değişiminde önceki kullanıcının reçeteleri görünmesin diye eklendi
/// (provider zaten `recipeRepositoryProvider`'ı watch ettiği için auth state
/// değişiminde repo yenilenir; autoDispose listener kalmadığında state'i de
/// silerek bellek tutmamasını sağlar).
final recipesListProvider = FutureProvider.autoDispose<List<Recipe>>((
  ref,
) async {
  ref.watch(recipeChangesProvider);
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.list();
});

/// Bir sahibin `is_public = true` reçeteleri (profil "Açık Reçeteler" için).
/// Boş/null ownerId → boş liste.
final publicRecipesByOwnerProvider = FutureProvider.autoDispose
    .family<List<Recipe>, String?>((ref, ownerId) async {
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
///
/// V1.4 P1.1 — autoDispose: `DateTime.now()` provider body'sinde hesaplanır,
/// gece yarısı geçildikten sonra eski "today" cache'inin kalmaması için
/// ekran kapanışında state silinir. Ekran tekrar açılınca yeni gün için
/// yeniden fetch.
final todaySummaryProvider = FutureProvider.autoDispose<DailySummary>((
  ref,
) async {
  ref.watch(bakeryChangesProvider);
  final repo = ref.watch(bakeryRepositoryProvider);
  final now = DateTime.now();
  return repo.dailySummary(DateTime(now.year, now.month, now.day));
});

// ── Fırın Defteri V1 ──

/// Bugünün defter satırı (ciro/not/kapanış). Yoksa null → gün henüz boş.
final todayDayBookProvider = FutureProvider.autoDispose<BakeryDayBook?>((
  ref,
) async {
  ref.watch(bakeryChangesProvider);
  final repo = ref.watch(bakeryRepositoryProvider);
  return repo.dayBook(DateTime.now());
});

/// Bugünün işleri ("Bugün ne yapacağım?").
final todayTasksProvider = FutureProvider.autoDispose<List<BakeryTask>>((
  ref,
) async {
  ref.watch(bakeryChangesProvider);
  final repo = ref.watch(bakeryRepositoryProvider);
  return repo.tasks(DateTime.now());
});

/// Rapor dönemleri — deterministik aralıklar (yerel gün).
enum LedgerReportPeriod { today, yesterday, week7, month30 }

extension LedgerReportPeriodMeta on LedgerReportPeriod {
  String get label {
    switch (this) {
      case LedgerReportPeriod.today:
        return 'Bugün';
      case LedgerReportPeriod.yesterday:
        return 'Dün';
      case LedgerReportPeriod.week7:
        return 'Son 7 Gün';
      case LedgerReportPeriod.month30:
        return 'Son 30 Gün';
    }
  }

  ({DateTime from, DateTime to}) range(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case LedgerReportPeriod.today:
        return (from: today, to: today);
      case LedgerReportPeriod.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return (from: y, to: y);
      case LedgerReportPeriod.week7:
        return (from: today.subtract(const Duration(days: 6)), to: today);
      case LedgerReportPeriod.month30:
        return (from: today.subtract(const Duration(days: 29)), to: today);
    }
  }
}

/// Seçili dönemin basit raporu.
final ledgerReportProvider = FutureProvider.autoDispose
    .family<LedgerRangeReport, LedgerReportPeriod>((ref, period) async {
      ref.watch(bakeryChangesProvider);
      final repo = ref.watch(bakeryRepositoryProvider);
      final r = period.range(DateTime.now());
      return repo.rangeReport(r.from, r.to);
    });
