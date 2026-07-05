import 'package:firin_defter/features/branches/models/branch_models.dart';
import 'package:firin_defter/features/branches/repositories/local_branch_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Şube Yönetimi V1 — model taksonomileri + Local repo davranış testleri.
/// Local repo, server (RLS/RPC) kurallarının davranışsal aynasıdır; asıl
/// güvenlik DB'de ayrıca canlı smoke ile doğrulanmıştır (26/26).
void main() {
  group('taksonomiler — persistKey round-trip (DB CHECK ile hizalı)', () {
    test('BranchRole', () {
      for (final r in BranchRole.values) {
        expect(BranchRoleMeta.fromKey(r.persistKey), r);
      }
      expect(BranchRole.branchManager.persistKey, 'branch_manager');
    });

    test('BranchProcessType', () {
      for (final t in BranchProcessType.values) {
        expect(BranchProcessTypeMeta.fromKey(t.persistKey), t);
      }
      expect(BranchProcessType.values, hasLength(6));
    });

    test('BranchProcessStatus + isOpen', () {
      for (final s in BranchProcessStatus.values) {
        expect(BranchProcessStatusMeta.fromKey(s.persistKey), s);
      }
      expect(BranchProcessStatus.completed.isOpen, isFalse);
      expect(BranchProcessStatus.attention.isOpen, isTrue);
    });

    test('şube sorumlusu tüm süreç tiplerine yetkili', () {
      expect(BranchRole.branchManager.hasAllProcessPermissions, isTrue);
      expect(BranchRole.counter.hasAllProcessPermissions, isFalse);
    });
  });

  group('owner akışı', () {
    test('owner tüm şubelerini ve süreçlerini görür', () async {
      final repo = LocalBranchRepository(seed: true);
      final branches = await repo.myBranches();
      expect(branches, hasLength(2));
      final processes = await repo.processes('branch-1');
      expect(processes, hasLength(2));
      final overview = await repo.overview();
      expect(overview.totalBranches, 2);
      expect(overview.activeMembers, 1);
      expect(overview.openProcesses, 2);
    });

    test('şube oluşturma + attention türetimi', () async {
      final repo = LocalBranchRepository(seed: true);
      final id = await repo.createBranch(name: 'Yeni Şube');
      expect((await repo.myBranches()).map((b) => b.id), contains(id));
      // branch-1'de attention süreç var → hasAttention türetilir.
      final b1 = (await repo.myBranches()).firstWhere(
        (b) => b.id == 'branch-1',
      );
      expect(b1.hasAttention, isTrue);
    });

    test('FN-ID daveti: bireysel hedef kabul, toptancı nötr red', () async {
      final repo = LocalBranchRepository(seed: true);
      final id = await repo.createStaffInvite(
        branchId: 'branch-2',
        firinnetId: 'FN-2026-000002',
        role: BranchRole.counter,
      );
      expect(id, isNotEmpty);
      // Toptancı hedef → not-found ile aynı nötr mesaj.
      expect(
        () => repo.createStaffInvite(
          branchId: 'branch-2',
          firinnetId: 'FN-2026-000003',
          role: BranchRole.counter,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('FırınNet ID'),
          ),
        ),
      );
    });

    test('duplicate pending davet reddedilir', () async {
      final repo = LocalBranchRepository(seed: true);
      await repo.createStaffInvite(
        branchId: 'branch-2',
        firinnetId: 'FN-2026-000002',
        role: BranchRole.counter,
      );
      expect(
        () => repo.createStaffInvite(
          branchId: 'branch-2',
          firinnetId: 'FN-2026-000002',
          role: BranchRole.counter,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('bekleyen davet'),
          ),
        ),
      );
    });
  });

  group('bireysel (şube personeli) akışı', () {
    test(
      'davet kabul edilmeden veri görünmez; kabul üyelik oluşturur',
      () async {
        final repo = LocalBranchRepository(seed: true);
        final inviteId = await repo.createStaffInvite(
          branchId: 'branch-2',
          firinnetId: 'FN-2026-000002', // staff-2
          role: BranchRole.cashier,
          permissions: const [BranchProcessType.accountNote],
        );
        // staff-2 gözü: davet kabul edilmeden hiçbir şube verisi yok.
        repo.currentUserId = 'staff-2';
        expect(await repo.myMemberships(), isEmpty);
        expect(await repo.processes('branch-2'), isEmpty);
        expect((await repo.myPendingInvites()).single.id, inviteId);
        // Kabul → aktif üyelik + şube verisi açılır.
        await repo.respondInvite(inviteId, accept: true);
        final memberships = await repo.myMemberships();
        expect(memberships.single.branchId, 'branch-2');
        expect(memberships.single.role, BranchRole.cashier);
        expect(
          await repo.createProcess(
            branchId: 'branch-2',
            type: BranchProcessType.accountNote,
            title: 'Cari not',
          ),
          isNotEmpty,
        );
      },
    );

    test('aktif üye yalnız kendi şubesini görür', () async {
      final repo = LocalBranchRepository(seed: true, currentUserId: 'staff-1');
      final memberships = await repo.myMemberships();
      expect(memberships, hasLength(1));
      expect(memberships.first.branchId, 'branch-1');
      // Üye olmadığı şubenin süreçleri boş döner (başka şube görünmez).
      expect(await repo.processes('branch-2'), isEmpty);
      expect(await repo.processes('branch-1'), isNotEmpty);
      // Yönetim listesi (owner görünümü) bireyselde boş.
      expect(await repo.myBranches(), isEmpty);
    });

    test('izinli tip eklenir, izinsiz tip reddedilir', () async {
      final repo = LocalBranchRepository(seed: true, currentUserId: 'staff-1');
      final id = await repo.createProcess(
        branchId: 'branch-1',
        type: BranchProcessType.productionNote,
        title: 'Hamur hazır',
      );
      expect(id, isNotEmpty);
      expect(
        () => repo.createProcess(
          branchId: 'branch-1',
          type: BranchProcessType.accountNote,
          title: 'İzinsiz deneme',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('izinli tipte güncelleme çalışır, izinsizde reddedilir', () async {
      final repo = LocalBranchRepository(seed: true, currentUserId: 'staff-1');
      // proc-1 openingCheck (izinli) → durum güncellenir.
      await repo.updateProcess(
        'proc-1',
        status: BranchProcessStatus.inProgress,
      );
      final updated = (await repo.processes(
        'branch-1',
      )).firstWhere((p) => p.id == 'proc-1');
      expect(updated.status, BranchProcessStatus.inProgress);
      // proc-2 dealerCollection (izinsiz) → reddedilir.
      expect(
        () =>
            repo.updateProcess('proc-2', status: BranchProcessStatus.completed),
        throwsA(isA<StateError>()),
      );
    });

    test('suspended/removed üyelik erişimi keser', () async {
      final repo = LocalBranchRepository(seed: true);
      // Owner askıya alır…
      await repo.setMembershipStatus(
        'member-1',
        BranchMembershipStatus.suspended,
      );
      // …staff-1 gözünden erişim kesilir.
      repo.currentUserId = 'staff-1';
      expect(await repo.myMemberships(), isEmpty);
      expect(await repo.processes('branch-1'), isEmpty);
      expect(
        () => repo.createProcess(
          branchId: 'branch-1',
          type: BranchProcessType.productionNote,
          title: 'Askıda deneme',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('owner daveti iptal edebilir', () async {
      final repo = LocalBranchRepository(seed: true);
      final inviteId = await repo.createStaffInvite(
        branchId: 'branch-2',
        firinnetId: 'FN-2026-000002',
        role: BranchRole.shipping,
      );
      expect((await repo.branchPendingInvites('branch-2')), hasLength(1));
      await repo.cancelInvite(inviteId);
      expect((await repo.branchPendingInvites('branch-2')), isEmpty);
    });
  });
}
