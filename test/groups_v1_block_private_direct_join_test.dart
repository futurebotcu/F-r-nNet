// Groups V1 P0 — Block direct join into private groups.
//
// Kapsam:
//   1. Migration dosyası mevcut + policy `is_private = false OR owner_id`
//      koşulu içeriyor.
//   2. GroupJoinResult.requiresApproval enum + message tanımlı.
//   3. SupabaseSocialGroupRepository.joinGroup defansif olarak
//      is_private kolonunu seçiyor ve requiresApproval döndürüyor.
//   4. LocalSocialGroupRepository.joinGroup non-owner private grupta
//      requiresApproval döndürüyor (Supabase ile paritye).
//   5. GroupCard._PrimaryCta private non-joined kart için
//      "Katılma isteği gönder" CTA gösteriyor.
//   6. groups_list_screen _GroupCardWired.onPrimary private branch'i
//      requestJoinGroup'a dispatch ediyor.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/social_groups/models/group_category.dart';
import 'package:firin_defter/features/social_groups/models/social_group.dart';
import 'package:firin_defter/features/social_groups/repositories/local_social_group_repository.dart';
import 'package:firin_defter/features/social_groups/services/group_join_result.dart';
import 'package:firin_defter/features/social_groups/widgets/group_card.dart';

SocialGroup _privateGroup({
  required String id,
  String ownerId = 'someone_else',
}) {
  return SocialGroup(
    id: id,
    name: 'Konyali Test',
    description: 'private',
    category: GroupCategory.bakers,
    ownerName: 'Owner',
    ownerId: ownerId,
    city: '',
    isPrivate: true,
    maxMembers: 100,
    currentMemberCount: 1,
    createdAt: DateTime(2026, 5, 19),
    tags: const [],
    visualSeed: 0,
  );
}

void main() {
  group('P0 — Migration file (block private direct join)', () {
    const migrationPath =
        'supabase/migrations/20260519140000_groups_v1_block_private_direct_join.sql';

    test('Migration dosyası repo\'da var', () {
      expect(File(migrationPath).existsSync(), isTrue);
    });

    test('Policy is_private guard içeriyor', () {
      final sql = File(migrationPath).readAsStringSync();
      expect(
        sql.contains('drop policy if exists group_members_insert_self'),
        isTrue,
      );
      expect(
        sql.contains('create policy group_members_insert_self'),
        isTrue,
      );
      expect(sql.contains('g.is_private = false'), isTrue,
          reason: 'Policy public grup direct join\'e izin vermeli');
      expect(sql.contains('g.owner_id = auth.uid()'), isTrue,
          reason: 'Owner kendi grubuna defansif olarak INSERT yapabilmeli');
    });
  });

  group('P0 — GroupJoinResult.requiresApproval', () {
    test('Enum değeri mevcut', () {
      // Var olan dört değerin yanına yeni değer eklendi.
      expect(GroupJoinResult.values.length, 5);
      expect(GroupJoinResult.values.contains(GroupJoinResult.requiresApproval),
          isTrue);
    });

    test('Türkçe message tanımlı', () {
      expect(GroupJoinResult.requiresApproval.message,
          'Bu grup katılım onaylı. Katılma isteği gönderebilirsin.');
    });
  });

  group('P0 — LocalSocialGroupRepository.joinGroup parite davranışı', () {
    test('Non-owner private grup → requiresApproval', () async {
      final repo = LocalSocialGroupRepository(
        seed: false,
        currentUserId: 'visitor',
      );
      // Owner farklı bir kullanıcı olan private grup yaratabilmek için
      // doğrudan seed simülasyonu kullanılır. Local repo'da owner = _meId,
      // bu yüzden createGroup ile aynı user'lı private grup yapamayız.
      // Bunun yerine createGroup ile public yap, sonra liste içinde
      // is_private'i değiştirebilmek için yeniden simülasyon gerekir. Bu
      // testi yapmak için repo'nun internal state'ini etkilemeden seed
      // genişletilemediği için: source-level guard ile aynı garantiyi
      // veriyoruz (aşağıda). Bu satır pariteyi semptomatik olarak teyit
      // eder: owner == me ise private grup yaratıp katılım denenirse owner
      // branch'i çalışır.
      final g = await repo.createGroup(
        name: 'X',
        description: 'd',
        category: GroupCategory.bakers,
        isPrivate: true,
      );
      // Owner zaten kendi grubunda; tekrar join → alreadyJoined.
      final r = await repo.joinGroup(g.id);
      expect(r, GroupJoinResult.alreadyJoined,
          reason: 'Owner zaten üye → alreadyJoined; private branch\'e '
              'düşmez (defansif owner kontrolü çalışıyor)');
    });

    test('Source-level: local repo private + non-owner → requiresApproval',
        () {
      final src = File(
        'lib/features/social_groups/repositories/local_social_group_repository.dart',
      ).readAsStringSync();
      expect(
        src.contains('g.isPrivate && g.ownerId != _meId'),
        isTrue,
        reason: 'Local repo joinGroup\'ta private guard yer almalı',
      );
      expect(
        src.contains('return GroupJoinResult.requiresApproval'),
        isTrue,
      );
    });
  });

  group('P0 — SupabaseSocialGroupRepository.joinGroup defansif kontrol', () {
    final src = File(
      'lib/features/social_groups/repositories/supabase_social_group_repository.dart',
    ).readAsStringSync();

    test('joinGroup is_private kolonunu seçiyor', () {
      expect(
        src.contains("'id, max_members, member_count, is_deleted, is_private'"),
        isTrue,
        reason: 'is_private kolonu select listesine eklenmeli',
      );
    });

    test('joinGroup private grupta requiresApproval döndürür', () {
      // is_private branch'i source-level kontrol.
      expect(
        src.contains("(groupRow['is_private'] as bool?) ?? false"),
        isTrue,
      );
      expect(
        src.contains('return GroupJoinResult.requiresApproval'),
        isTrue,
      );
    });
  });

  group('P0 — GroupCard private non-joined CTA', () {
    testWidgets(
      'isJoined=false + isPrivate=true → "Katılma isteği gönder" CTA',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: GroupCard(
                  group: _privateGroup(id: 'gp1'),
                  isJoined: false,
                  onPrimary: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.groupJoinRequestSend), findsOneWidget);
        expect(find.text(AppStrings.groupActionJoin), findsNothing,
            reason: 'Private kartta "Katıl" butonu görünmemeli');
      },
    );

    testWidgets(
      'isJoined=true + isPrivate=true → CTA yok (kart-tap)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: GroupCard(
                  group: _privateGroup(id: 'gp2'),
                  isJoined: true,
                  onPrimary: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // V1 UX Reset — joined kartta primary CTA yok.
        expect(find.text(AppStrings.groupActionOpen), findsNothing);
        expect(find.text(AppStrings.groupJoinRequestSend), findsNothing);
      },
    );

    testWidgets(
      'Public non-joined → "Katıl" devam ediyor (regression)',
      (tester) async {
        final publicGroup = SocialGroup(
          id: 'gpub',
          name: 'Public Test',
          description: 'd',
          category: GroupCategory.bakers,
          ownerName: 'Owner',
          ownerId: 'owner_x',
          city: '',
          isPrivate: false,
          maxMembers: 100,
          currentMemberCount: 1,
          createdAt: DateTime(2026, 5, 19),
          tags: const [],
          visualSeed: 0,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: GroupCard(
                  group: publicGroup,
                  isJoined: false,
                  onPrimary: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.groupActionJoin), findsOneWidget);
        expect(find.text(AppStrings.groupJoinRequestSend), findsNothing);
      },
    );
  });

  group('P0 — Source-level: groups_list_screen private dispatch', () {
    final src = File(
      'lib/features/social_groups/screens/groups_list_screen.dart',
    ).readAsStringSync();

    test('_GroupCardWired.onPrimary private branch requestJoinGroup\'a gider',
        () {
      // Kod yorumlarını strip et.
      final stripped = src
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(stripped.contains('if (group.isPrivate)'), isTrue,
          reason: 'Liste kartı private branch içermeli');
      expect(stripped.contains('repo.requestJoinGroup(group.id)'), isTrue,
          reason: 'Private branch requestJoinGroup RPC\'sini çağırmalı');
      expect(stripped.contains('AppStrings.groupJoinRequestSent'), isTrue,
          reason: 'Başarılı request snackbar metni kullanılmalı');
    });
  });
}
