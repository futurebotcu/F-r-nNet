import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/branch_activity.dart';
import '../models/branch_models.dart';
import '../repositories/branch_repository.dart';
import '../repositories/local_branch_repository.dart';
import '../repositories/supabase_branch_repository.dart';

/// Şube reposu — Supabase açıksa gerçek repo, değilse local (test/offline).
/// P0 kalıbı: yalnız userId izlenir (token refresh repo resetlemesin).
final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  final BranchRepository repo;
  if (AppConfig.supabaseEnabled && userId != null) {
    repo = SupabaseBranchRepository(sb.Supabase.instance.client);
  } else {
    repo = LocalBranchRepository(seed: true);
  }
  ref.onDispose(repo.dispose);
  return repo;
});

/// Yazma sonrası artan tick — liste provider'ları bunu izler
/// (dealerChangesProvider stream kalıbının şube karşılığı).
final branchChangesProvider = StreamProvider<int>((ref) {
  final listenable = ref.watch(branchRepositoryProvider).changes;
  final controller = StreamController<int>();
  void onChange() {
    if (!controller.isClosed) controller.add(listenable.value);
  }

  listenable.addListener(onChange);
  ref.onDispose(() {
    listenable.removeListener(onChange);
    controller.close();
  });
  return controller.stream;
});

// ── Patron tarafı ──

final myBranchesProvider = FutureProvider.autoDispose<List<Branch>>((
  ref,
) async {
  ref.watch(branchChangesProvider);
  return ref.watch(branchRepositoryProvider).myBranches();
});

final branchOverviewProvider = FutureProvider.autoDispose<BranchOverview>((
  ref,
) async {
  ref.watch(branchChangesProvider);
  return ref.watch(branchRepositoryProvider).overview();
});

final branchByIdProvider = FutureProvider.autoDispose.family<Branch?, String>((
  ref,
  id,
) async {
  ref.watch(branchChangesProvider);
  return ref.watch(branchRepositoryProvider).branchById(id);
});

final branchMembersProvider = FutureProvider.autoDispose
    .family<List<BranchMembership>, String>((ref, branchId) async {
      ref.watch(branchChangesProvider);
      return ref.watch(branchRepositoryProvider).branchMembers(branchId);
    });

final branchPendingInvitesProvider = FutureProvider.autoDispose
    .family<List<BranchInvite>, String>((ref, branchId) async {
      ref.watch(branchChangesProvider);
      return ref.watch(branchRepositoryProvider).branchPendingInvites(branchId);
    });

final branchProcessesProvider = FutureProvider.autoDispose
    .family<List<BranchProcess>, String>((ref, branchId) async {
      ref.watch(branchChangesProvider);
      return ref.watch(branchRepositoryProvider).processes(branchId);
    });

/// V2 — şube aktivite geçmişi (owner + aktif üye; RLS sınırında).
final branchActivityProvider = FutureProvider.autoDispose
    .family<List<BranchActivityEntry>, String>((ref, branchId) async {
      ref.watch(branchChangesProvider);
      return ref.watch(branchRepositoryProvider).activity(branchId);
    });

// ── Bireysel (şube personeli) tarafı ──

/// Aktif üyelikler — boş liste = "Şube İşlerim" yüzeyi görünmez.
final myBranchMembershipsProvider =
    FutureProvider.autoDispose<List<BranchMembership>>((ref) async {
      ref.watch(branchChangesProvider);
      return ref.watch(branchRepositoryProvider).myMemberships();
    });

/// Bireysele gelen bekleyen şube davetleri (panel kabul kartı).
final myBranchInvitesProvider = FutureProvider.autoDispose<List<BranchInvite>>((
  ref,
) async {
  ref.watch(branchChangesProvider);
  return ref.watch(branchRepositoryProvider).myPendingInvites();
});

/// Panelde "Şube İşlerim" kartının görünürlüğü: aktif üyelik VEYA bekleyen
/// davet varsa true. Hata/yükleme → false (fail-closed görünürlük).
final hasBranchWorkSurfaceProvider = Provider.autoDispose<bool>((ref) {
  final memberships =
      ref.watch(myBranchMembershipsProvider).valueOrNull ?? const [];
  final invites = ref.watch(myBranchInvitesProvider).valueOrNull ?? const [];
  return memberships.isNotEmpty || invites.isNotEmpty;
});
