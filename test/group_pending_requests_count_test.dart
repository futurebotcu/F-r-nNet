// G.N4 — Owner grup kartında "X bekleyen istek" badge'i.
//
// Kapsam:
//   1. AppStrings.groupPendingRequestCount tekil/çoğul.
//   2. GroupCard pendingRequestCount=0 → badge yok.
//   3. GroupCard pendingRequestCount=1 → "1 bekleyen istek".
//   4. GroupCard pendingRequestCount=3 → "3 bekleyen istek".
//   5. GroupCard compact=true + count>0 → badge gizli (carousel taşmaması).
//   6. LocalSocialGroupRepository.pendingJoinRequestCount semantiği.
//   7. Source-level: interface, guarded delegate, screen wiring.
//   8. Mevcut private join flow regression (acil sanity).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/social_groups/models/group_category.dart';
import 'package:firin_defter/features/social_groups/models/social_group.dart';
import 'package:firin_defter/features/social_groups/repositories/local_social_group_repository.dart';
import 'package:firin_defter/features/social_groups/widgets/group_card.dart';

SocialGroup _mkGroup({required String id, bool isPrivate = true}) {
  return SocialGroup(
    id: id,
    name: 'Test Grup',
    description: 'desc',
    category: GroupCategory.bakers,
    ownerName: 'Owner',
    ownerId: 'owner_test',
    city: '',
    isPrivate: isPrivate,
    maxMembers: 100,
    currentMemberCount: 5,
    createdAt: DateTime(2026, 5, 17),
    tags: const [],
    visualSeed: 0,
  );
}

void main() {
  group('G.N4 — AppStrings.groupPendingRequestCount', () {
    test('Tekil: "1 bekleyen istek"', () {
      expect(AppStrings.groupPendingRequestCount(1), '1 bekleyen istek');
    });

    test('Çoğul: "3 bekleyen istek"', () {
      expect(AppStrings.groupPendingRequestCount(3), '3 bekleyen istek');
    });

    test('0 → "0 bekleyen istek" (UI 0\'da badge zaten gizlenir)', () {
      expect(AppStrings.groupPendingRequestCount(0), '0 bekleyen istek');
    });
  });

  group('G.N4 — GroupCard pending badge', () {
    testWidgets('count=0 → pill gösterilmez', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GroupCard(
            group: _mkGroup(id: 'g0'),
            isJoined: true,
            onPrimary: () {},
            pendingRequestCount: 0,
          ),
        ),
      ));
      expect(find.byIcon(Icons.hourglass_top_rounded), findsNothing);
      expect(find.textContaining('bekleyen istek'), findsNothing);
    });

    testWidgets('count=1 → "1 bekleyen istek" + hourglass icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GroupCard(
            group: _mkGroup(id: 'g1'),
            isJoined: true,
            onPrimary: () {},
            pendingRequestCount: 1,
          ),
        ),
      ));
      expect(find.text('1 bekleyen istek'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    });

    testWidgets('count=3 → "3 bekleyen istek"', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GroupCard(
            group: _mkGroup(id: 'g3'),
            isJoined: true,
            onPrimary: () {},
            pendingRequestCount: 3,
          ),
        ),
      ));
      expect(find.text('3 bekleyen istek'), findsOneWidget);
    });

    testWidgets(
      'compact=true + count>0 → pill gizli (carousel taşma koruması)',
      (tester) async {
        // Public grup kullan — compact cover strip'inin "KATILIM ONAYLI"
        // badge'i ile gereksiz overflow yaratma; testin asıl amacı pending
        // pill'in compact'ta gizli olduğunu doğrulamak.
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: GroupCard(
                group: _mkGroup(id: 'gc', isPrivate: false),
                isJoined: true,
                onPrimary: () {},
                pendingRequestCount: 2,
                compact: true,
              ),
            ),
          ),
        ));
        expect(find.byIcon(Icons.hourglass_top_rounded), findsNothing);
        expect(find.textContaining('bekleyen istek'), findsNothing);
      },
    );
  });

  group('G.N4 — LocalSocialGroupRepository.pendingJoinRequestCount', () {
    test('Hiç istek yok → 0', () async {
      final repo = LocalSocialGroupRepository(
        seed: false,
        currentUserId: 'req_a',
      );
      expect(await repo.pendingJoinRequestCount('gx'), 0);
    });

    test('Tek pending istek → 1', () async {
      final repo = LocalSocialGroupRepository(
        seed: false,
        currentUserId: 'req_a',
      );
      await repo.requestJoinGroup('gx');
      expect(await repo.pendingJoinRequestCount('gx'), 1);
      // Başka grupta sıfır kalır.
      expect(await repo.pendingJoinRequestCount('gy'), 0);
    });

    test('Approve sonrası count düşer', () async {
      final repo = LocalSocialGroupRepository(
        seed: false,
        currentUserId: 'req_b',
      );
      await repo.requestJoinGroup('gz');
      expect(await repo.pendingJoinRequestCount('gz'), 1);

      final pending = await repo.listPendingJoinRequests('gz');
      await repo.approveJoinRequest(pending.first.id);
      expect(
        await repo.pendingJoinRequestCount('gz'),
        0,
        reason: 'Approve sonrası status=approved → pending sayılmaz',
      );
    });

    test('Reject sonrası count düşer', () async {
      final repo = LocalSocialGroupRepository(
        seed: false,
        currentUserId: 'req_c',
      );
      await repo.requestJoinGroup('gw');
      final pending = await repo.listPendingJoinRequests('gw');
      await repo.rejectJoinRequest(pending.first.id);
      expect(await repo.pendingJoinRequestCount('gw'), 0);
    });
  });

  group('G.N4 — Source-level wiring guards', () {
    test('Repository interface pendingJoinRequestCount imzası', () {
      final src = File(
        'lib/features/social_groups/repositories/social_group_repository.dart',
      ).readAsStringSync();
      expect(
        src.contains('Future<int> pendingJoinRequestCount(String groupId);'),
        isTrue,
      );
    });

    test('GuardedSocialGroupRepository read-only delegate', () {
      final src = File(
        'lib/features/social_groups/repositories/guarded_social_group_repository.dart',
      ).readAsStringSync();
      expect(
        src.contains('inner.pendingJoinRequestCount(groupId)'),
        isTrue,
      );
    });

    test('SupabaseSocialGroupRepository count + status filter', () {
      final src = File(
        'lib/features/social_groups/repositories/supabase_social_group_repository.dart',
      ).readAsStringSync();
      expect(src.contains('pendingJoinRequestCount'), isTrue);
      expect(src.contains("'status', 'pending'"), isTrue);
      expect(src.contains('CountOption.exact'), isTrue);
    });

    test('GroupsListScreen owner check + pendingJoinRequestCountProvider', () {
      final src = File(
        'lib/features/social_groups/screens/groups_list_screen.dart',
      ).readAsStringSync();
      expect(src.contains('pendingJoinRequestCountProvider'), isTrue);
      expect(src.contains('currentAuthUserProvider'), isTrue);
      expect(src.contains('group.ownerId == user.id'), isTrue);
    });
  });
}
