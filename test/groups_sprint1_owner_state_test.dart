// Groups V1 Sprint 1 — Owner primary action + composer write permission
// + isJoined cache notify (GB-1, GB-2, GB-3, GB-8).
//
// Kapsam:
//   GB-1: PrimaryActionButton owner için her zaman "Bu grubun kurucususun";
//         "Katıl" / "Ayrıl" / "Katılma isteği gönder" HİÇ görünmez.
//   GB-2: SupabaseSocialGroupRepository._refreshJoinedCache cache değiştiğinde
//         _notify() çağırıyor (source-level guard).
//   GB-3: GroupComposer isOwner=true + isJoined=false → TextField görünür,
//         lock placeholder yok. (Owner cache race senaryosunda bile yazabilir.)
//   GB-8: Owner için "Ayrıl" butonu çıkmaz (status card override eder).
//
// Regression koruması:
//   - Non-owner non-member public → "Katıl"
//   - Non-owner non-member private → "Katılma isteği gönder"
//   - Non-owner non-joined → composer kilitli (mevcut davranış)
//   - Non-owner joined → composer açık

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/can_write_check_provider.dart';
import 'package:firin_defter/features/social_groups/models/group_category.dart';
import 'package:firin_defter/features/social_groups/models/social_group.dart';
import 'package:firin_defter/features/social_groups/providers/social_group_providers.dart';
import 'package:firin_defter/features/social_groups/repositories/local_social_group_repository.dart';
import 'package:firin_defter/features/social_groups/repositories/social_group_repository.dart';
import 'package:firin_defter/features/social_groups/screens/group_detail_screen.dart';

SocialGroup _mkGroup({
  required String id,
  required String ownerId,
  bool isPrivate = false,
}) {
  return SocialGroup(
    id: id,
    name: 'Test Grup',
    description: 'desc',
    category: GroupCategory.bakers,
    ownerName: 'Owner',
    ownerId: ownerId,
    city: '',
    isPrivate: isPrivate,
    maxMembers: 100,
    currentMemberCount: 5,
    createdAt: DateTime(2026, 5, 18),
    tags: const [],
    visualSeed: 0,
  );
}

Widget _wrap({
  required SocialGroupRepository groupRepo,
  AuthUser? authUser,
  bool canWrite = true,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      socialGroupRepositoryProvider.overrideWithValue(groupRepo),
      canWriteCheckProvider.overrideWithValue(() => canWrite),
      currentAuthUserProvider.overrideWith((ref) => authUser),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('Sprint 1 / GB-1+GB-8 — PrimaryActionButton owner branch', () {
    testWidgets(
      'Owner + joined=true → "Bu grubun kurucususun", Katıl/Ayrıl yok',
      (tester) async {
        final repo = LocalSocialGroupRepository(seed: false);
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'owner_x', email: null),
          child: Scaffold(
            body: PrimaryActionButton(
              group: _mkGroup(id: 'g1', ownerId: 'owner_x'),
              isJoined: true,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.groupOwnerStatusTitle), findsOneWidget);
        expect(find.text(AppStrings.groupOwnerStatusSubtitle), findsOneWidget);
        expect(find.text(AppStrings.groupActionJoin), findsNothing);
        expect(find.text(AppStrings.groupActionLeave), findsNothing);
        expect(find.text(AppStrings.groupJoinRequestSend), findsNothing);
      },
    );

    testWidgets(
      'Owner + joined=false (cache race) → yine "Bu grubun kurucususun"',
      (tester) async {
        // GB-2 cache race senaryosu: owner DB'de üye ama isJoined=false dönmüş.
        // Owner branch en üstte; bu durumda bile "Katıl" GÖSTERİLMEZ.
        final repo = LocalSocialGroupRepository(seed: false);
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'owner_y', email: null),
          child: Scaffold(
            body: PrimaryActionButton(
              group: _mkGroup(id: 'g2', ownerId: 'owner_y', isPrivate: true),
              isJoined: false,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.groupOwnerStatusTitle), findsOneWidget);
        expect(find.text(AppStrings.groupActionJoin), findsNothing);
        expect(find.text(AppStrings.groupActionLeave), findsNothing);
        expect(find.text(AppStrings.groupJoinRequestSend), findsNothing);
      },
    );

    testWidgets(
      'Non-owner + non-member public → "Katıl" (regression)',
      (tester) async {
        final repo = LocalSocialGroupRepository(seed: false);
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'visitor', email: null),
          child: Scaffold(
            body: PrimaryActionButton(
              group: _mkGroup(id: 'g3', ownerId: 'someone_else'),
              isJoined: false,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.groupActionJoin), findsOneWidget);
        expect(find.text(AppStrings.groupOwnerStatusTitle), findsNothing);
      },
    );

    testWidgets(
      'Non-owner + non-member private → "Katılma isteği gönder" (regression)',
      (tester) async {
        final repo = LocalSocialGroupRepository(seed: false);
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'visitor', email: null),
          child: Scaffold(
            body: PrimaryActionButton(
              group: _mkGroup(
                id: 'g4',
                ownerId: 'someone_else',
                isPrivate: true,
              ),
              isJoined: false,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.groupJoinRequestSend), findsOneWidget);
        expect(find.text(AppStrings.groupOwnerStatusTitle), findsNothing);
      },
    );

    testWidgets(
      'Non-owner + joined=true → "Ayrıl" (regression)',
      (tester) async {
        final repo = LocalSocialGroupRepository(seed: false);
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'member_z', email: null),
          child: Scaffold(
            body: PrimaryActionButton(
              group: _mkGroup(id: 'g5', ownerId: 'someone_else'),
              isJoined: true,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.groupActionLeave), findsOneWidget);
        expect(find.text(AppStrings.groupOwnerStatusTitle), findsNothing);
      },
    );
  });

  group('Sprint 1 / GB-3 — GroupComposer owner write permission', () {
    testWidgets(
      'isOwner=true + isJoined=false → TextField + Send (lock yok)',
      (tester) async {
        final repo = LocalSocialGroupRepository(seed: false);
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'owner_w', email: null),
          child: Scaffold(
            body: GroupComposer(
              group: _mkGroup(id: 'gc1', ownerId: 'owner_w'),
              isJoined: false,
              isOwner: true,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.groupDetailComposeJoinedOnly),
          findsNothing,
          reason: 'Owner için lock placeholder gösterilmemeli',
        );
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'isOwner=false + isJoined=false → lock placeholder (regression)',
      (tester) async {
        final repo = LocalSocialGroupRepository(seed: false);
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'guest', email: null),
          child: Scaffold(
            body: GroupComposer(
              group: _mkGroup(id: 'gc2', ownerId: 'someone_else'),
              isJoined: false,
              isOwner: false,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.groupDetailComposeJoinedOnly),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets(
      'isOwner=false + isJoined=true → TextField (regression)',
      (tester) async {
        final repo = LocalSocialGroupRepository(seed: false);
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'member_a', email: null),
          child: Scaffold(
            body: GroupComposer(
              group: _mkGroup(id: 'gc3', ownerId: 'someone_else'),
              isJoined: true,
              isOwner: false,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.groupDetailComposeJoinedOnly),
          findsNothing,
        );
        expect(find.byType(TextField), findsOneWidget);
      },
    );
  });

  group('Sprint 1 / GB-2 — Supabase repo cache notify (source-level)', () {
    test('_refreshJoinedCache cache değişikliğinde _notify çağırıyor', () {
      final src = File(
        'lib/features/social_groups/repositories/supabase_social_group_repository.dart',
      ).readAsStringSync();
      // _refreshJoinedCache fonksiyonunu çıkar:
      final fnMatch = RegExp(
        r'Future<void>\s+_refreshJoinedCache\(\)\s+async\s*\{([\s\S]*?)\n  \}',
      ).firstMatch(src);
      expect(fnMatch, isNotNull,
          reason: '_refreshJoinedCache imzası bulunamadı');
      final body = fnMatch!.group(1)!;
      expect(body.contains('_notify()'), isTrue,
          reason: 'Cache fill sonrası _notify() çağrısı yok — '
              'isJoinedProvider stale kalır (GB-2)');
      // Diff-check zorunlu: aksi halde listJoined sonsuz döngü riski.
      // P0 atomik swap sonrası diff, yeni set (`next`) swap'tan ÖNCE mevcut
      // cache ile karşılaştırılarak yapılır (await sırasında boş ara
      // pencere yok — composer "Sohbete katıl"a düşme regresyonu).
      expect(body.contains('final changed'), isTrue,
          reason: 'Diff-check korunmalı (listJoined ↔ notify döngüsünü '
              'engellemek için)');
      expect(body.contains('if (changed) _notify();'), isTrue,
          reason: 'Notify yalnız gerçek cache değişikliğinde tetiklenmeli');
    });
  });

  group('Sprint 1 — AppStrings owner status constants', () {
    test('groupOwnerStatusTitle = "Bu grubun kurucususun"', () {
      expect(AppStrings.groupOwnerStatusTitle, 'Bu grubun kurucususun');
    });

    test('groupOwnerStatusSubtitle Sprint 2\'de "Yönet menüsüne dokun"', () {
      // Sprint 2 — status card tıklanabilir oldu; subtitle aksiyon ipucu.
      expect(
        AppStrings.groupOwnerStatusSubtitle,
        'Yönet menüsüne dokun',
      );
    });
  });
}
