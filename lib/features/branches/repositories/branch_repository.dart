import 'package:flutter/foundation.dart';

import '../models/branch_models.dart';

/// Şube Yönetimi V1 repo sözleşmesi.
///
/// Yazma yollarının güvenlik kuralları SERVER tarafındadır (SECURITY DEFINER
/// RPC'ler + RLS); client tarafındaki izin kontrolleri yalnız UX içindir.
/// [changes] her yazma sonrası artar; provider'lar bunu izleyip tazelenir.
abstract class BranchRepository {
  /// Yazma sonrası artan sayaç (provider invalidation tick'i).
  ValueListenable<int> get changes;

  // ── Patron (owner) tarafı ──
  Future<List<Branch>> myBranches();
  Future<Branch?> branchById(String id);
  Future<String> createBranch({
    required String name,
    String address = '',
    String phone = '',
  });
  Future<void> setBranchActive(String id, bool active);
  Future<BranchOverview> overview();
  Future<List<BranchMembership>> branchMembers(String branchId);
  Future<List<BranchInvite>> branchPendingInvites(String branchId);
  Future<String> createStaffInvite({
    required String branchId,
    required String firinnetId,
    required BranchRole role,
    List<BranchProcessType> permissions = const [],
    String note = '',
  });
  Future<void> cancelInvite(String inviteId);
  Future<void> setMembershipStatus(
    String membershipId,
    BranchMembershipStatus status,
  );

  // ── Bireysel (şube personeli) tarafı ──
  /// Aktif üyelikler — boşsa "Şube İşlerim" yüzeyi HİÇ görünmez.
  Future<List<BranchMembership>> myMemberships();
  Future<List<BranchInvite>> myPendingInvites();
  Future<void> respondInvite(String inviteId, {required bool accept});

  // ── Süreçler (iki taraf; yazma izni server'da denetlenir) ──
  Future<List<BranchProcess>> processes(String branchId);
  Future<String> createProcess({
    required String branchId,
    required BranchProcessType type,
    required String title,
    String note = '',
  });
  Future<void> updateProcess(
    String processId, {
    BranchProcessStatus? status,
    String? note,
  });

  void dispose();
}
