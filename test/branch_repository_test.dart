import 'package:firin_defter/features/branches/models/branch_activity.dart';
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

  // ── V2 — branch_manager yetkileri, aktivite, izin güncelleme, KPI ──

  /// branch-2'de staff-1'i şube sorumlusu yapar (davet→kabul akışıyla).
  Future<LocalBranchRepository> seedWithManager() async {
    final repo = LocalBranchRepository(seed: true);
    final inviteId = await repo.createStaffInvite(
      branchId: 'branch-2',
      firinnetId: 'FN-2026-000001', // staff-1
      role: BranchRole.branchManager,
    );
    repo.currentUserId = 'staff-1';
    await repo.respondInvite(inviteId, accept: true);
    return repo;
  }

  group('V2 — branch_manager yetkileri (server kurallarının aynası)', () {
    test(
      'manager alt rol davet edebilir; davet owner adına kaydolur',
      () async {
        final repo = await seedWithManager();
        final inviteId = await repo.createStaffInvite(
          branchId: 'branch-2',
          firinnetId: 'FN-2026-000002', // staff-2
          role: BranchRole.counter,
          permissions: const [BranchProcessType.generalNote],
        );
        expect(inviteId, isNotEmpty);
        // Manager kendi şubesinin bekleyen davetlerini görür.
        expect(await repo.branchPendingInvites('branch-2'), hasLength(1));
        // Davet ile gelen üyelik owner'a bağlıdır (owner listede görür).
        repo.currentUserId = 'staff-2';
        await repo.respondInvite(inviteId, accept: true);
        repo.currentUserId = 'owner-1';
        expect(
          (await repo.branchMembers('branch-2')).map((m) => m.userId),
          containsAll(['staff-1', 'staff-2']),
        );
      },
    );

    test('manager branch_manager rolü VEREMEZ', () async {
      final repo = await seedWithManager();
      expect(
        () => repo.createStaffInvite(
          branchId: 'branch-2',
          firinnetId: 'FN-2026-000002',
          role: BranchRole.branchManager,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('rolü veremez'),
          ),
        ),
      );
    });

    test(
      'manager başka şubeye davet atamaz; normal personel hiç atamaz',
      () async {
        final repo = await seedWithManager();
        // staff-1 branch-1'de yalnız production personelidir → davet yok.
        expect(
          () => repo.createStaffInvite(
            branchId: 'branch-1',
            firinnetId: 'FN-2026-000002',
            role: BranchRole.counter,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('manager non-manager üyeyi askıya alır; kendine dokunamaz', () async {
      final repo = await seedWithManager();
      final inviteId = await repo.createStaffInvite(
        branchId: 'branch-2',
        firinnetId: 'FN-2026-000002',
        role: BranchRole.counter,
      );
      repo.currentUserId = 'staff-2';
      await repo.respondInvite(inviteId, accept: true);
      repo.currentUserId = 'staff-1'; // manager
      final members = await repo.branchMembers('branch-2');
      final other = members.firstWhere((m) => m.userId == 'staff-2');
      final self = members.firstWhere((m) => m.userId == 'staff-1');
      await repo.setMembershipStatus(
        other.id,
        BranchMembershipStatus.suspended,
      );
      // Askıya alınan personelin erişimi kesilir.
      repo.currentUserId = 'staff-2';
      expect(await repo.myMemberships(), isEmpty);
      // Manager kendi üyeliğini değiştiremez (yetki yükseltme kapalı).
      repo.currentUserId = 'staff-1';
      expect(
        () => repo.setMembershipStatus(self.id, BranchMembershipStatus.active),
        throwsA(isA<StateError>()),
      );
    });

    test('normal personel yalnız kendi üyelik satırını görür', () async {
      final repo = LocalBranchRepository(seed: true, currentUserId: 'staff-1');
      final rows = await repo.branchMembers('branch-1');
      expect(rows, hasLength(1));
      expect(rows.single.userId, 'staff-1');
      // Bekleyen davet listesi yönetim yüzeyidir — personelde boş.
      expect(await repo.branchPendingInvites('branch-1'), isEmpty);
    });
  });

  group(
    'V2 — izin güncelleme (update_branch_membership_permissions aynası)',
    () {
      test('owner personel iznini yeniden davet olmadan günceller', () async {
        final repo = LocalBranchRepository(seed: true);
        await repo.updateMembershipPermissions('member-1', const [
          BranchProcessType.accountNote,
        ]);
        repo.currentUserId = 'staff-1';
        final m = (await repo.myMemberships()).single;
        expect(m.permissions, [BranchProcessType.accountNote]);
        // Yeni izinle süreç açılır; eski izinli tip artık reddedilir.
        expect(
          await repo.createProcess(
            branchId: 'branch-1',
            type: BranchProcessType.accountNote,
            title: 'Cari not',
          ),
          isNotEmpty,
        );
        expect(
          () => repo.createProcess(
            branchId: 'branch-1',
            type: BranchProcessType.productionNote,
            title: 'İzin düştü',
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('yetkisiz kullanıcı izin güncelleyemez', () async {
        final repo = LocalBranchRepository(
          seed: true,
          currentUserId: 'staff-2',
        );
        expect(
          () => repo.updateMembershipPermissions('member-1', const []),
          throwsA(isA<StateError>()),
        );
      });
    },
  );

  group('V2 — aktivite geçmişi', () {
    test(
      'süreç ve üyelik olayları loglanır; filtreler doğru eşleşir',
      () async {
        final repo = LocalBranchRepository(seed: true);
        final id = await repo.createProcess(
          branchId: 'branch-1',
          type: BranchProcessType.generalNote,
          title: 'Aktivite testi',
        );
        await repo.updateProcess(id, status: BranchProcessStatus.completed);
        await repo.setMembershipStatus(
          'member-1',
          BranchMembershipStatus.suspended,
        );
        final activity = await repo.activity('branch-1');
        expect(
          activity.map((a) => a.event),
          containsAll([
            BranchActivityEvent.processCreated,
            BranchActivityEvent.statusChanged,
            BranchActivityEvent.membershipChanged,
          ]),
        );
        final completed = activity
            .where(BranchActivityFilter.completed.matches)
            .toList();
        expect(completed, isNotEmpty);
        expect(completed.first.description, 'Süreç tamamlandı');
        final staffEvents = activity
            .where(BranchActivityFilter.staff.matches)
            .toList();
        expect(
          staffEvents.map((a) => a.description),
          contains('Personel askıya alındı'),
        );
        // Dikkat filtresi yalnız attention durum değişimini yakalar (seed).
        expect(
          activity.where(BranchActivityFilter.attention.matches).length,
          1,
        );
      },
    );

    test(
      'üye yalnız kendi şubesinin log\'unu görür; yabancı hiç görmez',
      () async {
        final repo = LocalBranchRepository(
          seed: true,
          currentUserId: 'staff-1',
        );
        expect(await repo.activity('branch-1'), isNotEmpty);
        expect(await repo.activity('branch-2'), isEmpty);
        repo.currentUserId = 'staff-2';
        expect(await repo.activity('branch-1'), isEmpty);
      },
    );
  });

  group('V2 — özet KPI hesapları', () {
    test(
      'attention + bugün tamamlanan doğru; suspended üye sayılmaz',
      () async {
        final repo = LocalBranchRepository(seed: true);
        final id = await repo.createProcess(
          branchId: 'branch-1',
          type: BranchProcessType.generalNote,
          title: 'Bugün biter',
        );
        await repo.updateProcess(id, status: BranchProcessStatus.completed);
        var o = await repo.overview();
        expect(o.attentionProcesses, 1); // seed proc-2
        expect(o.completedToday, 1);
        expect(o.activeMembers, 1);
        await repo.setMembershipStatus(
          'member-1',
          BranchMembershipStatus.suspended,
        );
        o = await repo.overview();
        expect(o.activeMembers, 0);
        // Tamamlanan süreç açık sayılmaz.
        expect(o.openProcesses, 2);
      },
    );

    test('şablon metadata: her tip için açıklama dolu', () {
      for (final t in BranchProcessType.values) {
        expect(t.templateDescription, isNotEmpty);
      }
    });
  });
}
