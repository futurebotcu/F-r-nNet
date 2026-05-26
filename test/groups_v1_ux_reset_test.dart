// Groups V1 UX Reset — WhatsApp benzeri chat-centric grup ekranı.
//
// Kapsam:
//   1. Group detail (member/owner) için BÜYÜK hero/owner-status/members
//      kartı ana akışta görünmez; chat ön planda + sticky composer.
//   2. Pending join requests yoksa "Bekleyen katılım isteği yok" ana
//      ekranda görünmez; varsa kompakt alert görünür.
//   3. Non-member private grup gated card görür, chat görünmez.
//   4. Non-member public grup "Sohbete katıl" footer CTA'sını görür.
//   5. Groups list — "Tüm gruplar" altında joined gruplar tekrar
//      gösterilmez (source-level guard).
//   6. Groups list — FloatingActionButton.extended kaldırıldı.
//   7. Mesaj sıralaması: newest at bottom (reverse:true ListView).
//   8. AppBar yönetim menüsü kaynak düzeyi: owner/member için
//      PopupMenuButton + Üyeler/Gruptan çık entry'leri içerir.
//   9. AppStrings yeni sabitler.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/can_write_check_provider.dart';
import 'package:firin_defter/features/social_groups/models/group_category.dart';
import 'package:firin_defter/features/social_groups/models/group_member.dart';
import 'package:firin_defter/features/social_groups/models/social_group.dart';
import 'package:firin_defter/features/social_groups/providers/social_group_providers.dart';
import 'package:firin_defter/features/social_groups/repositories/local_social_group_repository.dart';
import 'package:firin_defter/features/social_groups/repositories/social_group_repository.dart';
import 'package:firin_defter/features/social_groups/screens/group_detail_screen.dart';

Widget _wrap({
  required SocialGroupRepository groupRepo,
  AuthUser? authUser,
  bool canWrite = true,
  List<Override> extraOverrides = const [],
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      socialGroupRepositoryProvider.overrideWithValue(groupRepo),
      canWriteCheckProvider.overrideWithValue(() => canWrite),
      currentAuthUserProvider.overrideWith((ref) => authUser),
      ...extraOverrides,
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('UX Reset — AppStrings yeni sabitler', () {
    test('groupFirstMessage', () {
      expect(AppStrings.groupFirstMessage, 'İlk mesajı sen yaz');
    });

    test('groupInfoMembers tekil/çoğul aynı yapı', () {
      expect(AppStrings.groupInfoMembers(1), '1 üye');
      expect(AppStrings.groupInfoMembers(4), '4 üye');
    });

    test('groupJoinRequestsCompact tekil/çoğul', () {
      expect(AppStrings.groupJoinRequestsCompact(1), '1 katılım isteği');
      expect(AppStrings.groupJoinRequestsCompact(3), '3 katılım isteği');
    });

    test('groupJoinNowCta = "Sohbete katıl"', () {
      expect(AppStrings.groupJoinNowCta, 'Sohbete katıl');
    });

    test('groupJoinRequestsMenu = "Katılım istekleri"', () {
      expect(AppStrings.groupJoinRequestsMenu, 'Katılım istekleri');
    });
  });

  group('UX Reset — Group detail screen (chat-centric)', () {
    testWidgets(
      'Owner: ana akışta büyük "Bu grubun kurucususun" kartı görünmez',
      (tester) async {
        final repo = LocalSocialGroupRepository(seed: false);
        final g = await repo.createGroup(
          name: 'Test',
          description: 'desc',
          category: GroupCategory.bakers,
        );
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'me_misafir', email: null),
          child: GroupDetailScreen(groupId: g.id),
        ));
        await tester.pumpAndSettle();
        // Owner status card ana ekrandan kaldırıldı — menüye taşındı.
        expect(
          find.text(AppStrings.groupOwnerStatusTitle),
          findsNothing,
          reason: 'Owner status card ana akışta görünmemeli (menüye taşındı)',
        );
        // Sticky composer mevcut olmalı.
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'Owner: AppBar menüsü PopupMenuButton içerir',
      (tester) async {
        final repo = LocalSocialGroupRepository(seed: false);
        final g = await repo.createGroup(
          name: 'Test',
          description: 'd',
          category: GroupCategory.bakers,
        );
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'me_misafir', email: null),
          child: GroupDetailScreen(groupId: g.id),
        ));
        await tester.pumpAndSettle();
        expect(
          find.byType(PopupMenuButton<String>),
          findsOneWidget,
          reason: 'Owner için yönetim menüsü AppBar\'da olmalı',
        );
      },
    );

    testWidgets(
      'Owner pending istek yoksa kompakt alert görünmez',
      (tester) async {
        final repo = LocalSocialGroupRepository(seed: false);
        final g = await repo.createGroup(
          name: 'Test',
          description: 'd',
          category: GroupCategory.bakers,
        );
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'me_misafir', email: null),
          child: GroupDetailScreen(groupId: g.id),
        ));
        await tester.pumpAndSettle();
        // "Bekleyen katılım isteği yok" tek-line yazısı ana ekranda olmamalı.
        expect(
          find.text(AppStrings.groupJoinRequestsEmpty),
          findsNothing,
          reason: 'Pending yoksa boş hâl ana ekranda görünmemeli',
        );
        // Kompakt "X katılım isteği" badge'i de count=0 → görünmemeli.
        expect(find.textContaining('katılım isteği'), findsNothing);
      },
    );

    testWidgets(
      'Owner pending istek varsa kompakt alert görünür',
      (tester) async {
        // Owner için pending istek yaratabilmek üzere: önce başka kullanıcı
        // perspektifinden requestJoinGroup, sonra owner perspektifinde
        // detayı pump et. Local repo tek-user simülasyon olduğu için
        // pending sayısı pendingJoinRequestCount üzerinden manuel test.
        // Burada onTap olmadan da sayı görünmesi için iki ayrı repo yaratıp
        // veriyi senkron tutmak yerine, owner-perspektifte request RPC'yi
        // çalıştırıp sonra count > 0 olduğunu manuel doğrularız.
        // NOT: LocalSocialGroupRepository içindeki request mekanizması
        // currentUserId üzerinden requester olarak owner'ı işaretler;
        // count yine de >0 dönecektir.
        final repo = LocalSocialGroupRepository(
          seed: false,
          currentUserId: 'owner_z',
        );
        final g = await repo.createGroup(
          name: 'Test',
          description: 'd',
          category: GroupCategory.bakers,
        );
        await repo.requestJoinGroup(g.id);
        expect(await repo.pendingJoinRequestCount(g.id), 1);
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'owner_z', email: null),
          child: GroupDetailScreen(groupId: g.id),
        ));
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.groupJoinRequestsCompact(1)),
          findsOneWidget,
          reason: 'Pending > 0 → kompakt alert görünür',
        );
      },
    );

    testWidgets(
      'Non-member private grup: gated card görünür, chat görünmez',
      (tester) async {
        // Local repo owner = currentUserId olduğu için non-member-of-private
        // grubu doğrudan kuramayız. Bunun yerine groupByIdProvider'ı
        // override edip farklı owner'lı private grup enjekte ederiz.
        final repo = LocalSocialGroupRepository(seed: false);
        const groupId = 'gpriv-1';
        final privateGroup = SocialGroup(
          id: groupId,
          name: 'Private G',
          description: 'desc',
          category: GroupCategory.bakers,
          ownerName: 'Owner',
          ownerId: 'someone_else',
          city: '',
          isPrivate: true,
          maxMembers: 100,
          currentMemberCount: 4,
          createdAt: DateTime(2026, 5, 19),
          tags: const [],
          visualSeed: 0,
        );
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'visitor', email: null),
          extraOverrides: [
            groupByIdProvider(groupId).overrideWith(
              (ref) async => privateGroup,
            ),
          ],
          child: const GroupDetailScreen(groupId: groupId),
        ));
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.groupPrivateInfo),
          findsOneWidget,
          reason: 'Non-member private gated card içeriği görünmeli',
        );
        // Chat composer (TextField + send icon) görünmez; sadece request CTA.
        expect(find.byIcon(Icons.send_rounded), findsNothing);
      },
    );
  });

  group('UX Reset — Source-level guards', () {
    test('group_detail_screen: AppBar + PopupMenuButton wiring', () {
      final src = File(
        'lib/features/social_groups/screens/group_detail_screen.dart',
      ).readAsStringSync();
      expect(
        src.contains('PopupMenuButton<String>'),
        isTrue,
        reason: 'Yönetim menüsü AppBar PopupMenuButton ile kurulmalı',
      );
      expect(src.contains("case 'members':"), isTrue);
      expect(src.contains("case 'leave':"), isTrue);
      expect(src.contains("case 'close':"), isTrue);
      expect(src.contains("case 'requests':"), isTrue);
    });

    test('group_detail_screen: hero / members entry card kaldırıldı', () {
      final src = File(
        'lib/features/social_groups/screens/group_detail_screen.dart',
      ).readAsStringSync();
      // _GroupHero / _MembersEntryRow private widget'ları artık yok.
      expect(
        src.contains('class _GroupHero'),
        isFalse,
        reason: 'Büyük hero kartı UX Reset ile kaldırıldı',
      );
      expect(
        src.contains('class _MembersEntryRow'),
        isFalse,
        reason: 'Üyeler ana kart UX Reset ile menüye taşındı',
      );
    });

    test('group_detail_screen: ListView.builder reverse:true kullanır', () {
      final src = File(
        'lib/features/social_groups/screens/group_detail_screen.dart',
      ).readAsStringSync();
      expect(
        src.contains('reverse: true'),
        isTrue,
        reason: 'Chat list reverse:true ile newest-at-bottom olmalı',
      );
    });

    test('groups_list_screen: FloatingActionButton kaldırıldı', () {
      final src = File(
        'lib/features/social_groups/screens/groups_list_screen.dart',
      ).readAsStringSync();
      expect(
        src.contains('FloatingActionButton'),
        isFalse,
        reason: 'FAB kaldırıldı; header\'daki + butonu yeterli',
      );
    });

    test('groups_list_screen: joined dedup guard kaynak düzeyi', () {
      final src = File(
        'lib/features/social_groups/screens/groups_list_screen.dart',
      ).readAsStringSync();
      expect(
        src.contains('!joinedIds.contains'),
        isTrue,
        reason: '"Tüm gruplar" altında joined grupları tekrar göstermemeli',
      );
    });

    test('group_card: joined kartta primary CTA gizli', () {
      final src = File(
        'lib/features/social_groups/widgets/group_card.dart',
      ).readAsStringSync();
      // `if (!isJoined) ...[ _PrimaryCta(...) ]` collection-spread bloğu.
      expect(
        src.contains('if (!isJoined) ...['),
        isTrue,
        reason: 'Joined kart Aç butonu yerine kart-tap kullanmalı',
      );
    });

    test('group_card: joined olunca "Katılım onaylı" badge gizli', () {
      final src = File(
        'lib/features/social_groups/widgets/group_card.dart',
      ).readAsStringSync();
      expect(
        src.contains('showApprovalBadge = group.isPrivate && !isJoined'),
        isTrue,
        reason: 'Joined kullanıcıda private badge taşma yapmamalı',
      );
    });
  });

  group('UX Reset — Mevcut Sprint 2 davranışları korunur (regression)', () {
    test('GroupLeaveOutcome enum hâlâ çalışıyor', () {
      expect(GroupLeaveOutcome.fromPersist('left'), GroupLeaveOutcome.left);
      expect(
        GroupLeaveOutcome.fromPersist('transferred'),
        GroupLeaveOutcome.transferred,
      );
      expect(
        GroupLeaveOutcome.fromPersist('closed'),
        GroupLeaveOutcome.closed,
      );
    });

    test('AppStrings.groupLeave / groupDelete metinleri korunur', () {
      expect(AppStrings.groupLeave, 'Gruptan çık');
      expect(AppStrings.groupDelete, 'Grubu kapat');
      expect(AppStrings.groupMembers, 'Üyeler');
    });
  });
}
