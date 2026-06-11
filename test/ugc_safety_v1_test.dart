// FırınNet UGC Safety V1 — report + block testleri.
//
// Kapsam:
//   1. ReportReason / ReportTargetType enum sözleşmeleri (DB CHECK ile aynı).
//   2. LocalSafetyRepository davranışı: duplicate report, self-report,
//      block/unblock, duplicate block, self-block.
//   3. GuardedSafetyRepository: guest write guard.
//   4. Provider zinciri: block → blockedUserIdsSyncProvider güncellenir.
//   5. GroupMessage.ownerId modeli.
//   6. Source contracts: migration RLS + tüm UI yüzey entegrasyonları +
//      feed render filtresi + mesaj başlatma engeli.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/providers/can_write_check_provider.dart';
import 'package:firin_defter/features/safety/models/report_models.dart';
import 'package:firin_defter/features/safety/providers/safety_providers.dart';
import 'package:firin_defter/features/safety/repositories/guarded_safety_repository.dart';
import 'package:firin_defter/features/safety/repositories/local_safety_repository.dart';
import 'package:firin_defter/features/safety/repositories/safety_repository.dart';
import 'package:firin_defter/features/auth/services/auth_required_guard.dart';
import 'package:firin_defter/features/social_groups/models/group_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V1 — ReportReason enum (DB CHECK sözleşmesi)', () {
    test('8 kategori, persist key\'ler migration CHECK ile birebir', () {
      expect(ReportReason.values, hasLength(8));
      expect(
        ReportReason.values.map((r) => r.persistKey).toList(),
        [
          'spam',
          'harassment',
          'hate',
          'scam',
          'inappropriate_media',
          'illegal_or_dangerous',
          'privacy',
          'other',
        ],
      );
    });

    test('tüm etiketler dolu (Türkçe)', () {
      for (final r in ReportReason.values) {
        expect(r.label, isNotEmpty);
      }
    });

    test('target type persist key\'leri migration CHECK ile birebir', () {
      expect(
        ReportTargetType.values.map((t) => t.persistKey).toList(),
        [
          'feed_post',
          'comment',
          'group_message',
          'market_listing',
          'job_listing',
          'profile',
        ],
      );
    });
  });

  group('V1 — LocalSafetyRepository davranış sözleşmesi', () {
    late LocalSafetyRepository repo;

    setUp(() => repo = LocalSafetyRepository(currentUserId: 'me'));

    test('report → submitted; aynı hedefe ikinci report → duplicate',
        () async {
      final first = await repo.reportContent(
        targetType: ReportTargetType.feedPost,
        targetId: 'p1',
        reportedUserId: 'other',
        reason: ReportReason.spam,
      );
      expect(first, ReportResult.submitted);

      final second = await repo.reportContent(
        targetType: ReportTargetType.feedPost,
        targetId: 'p1',
        reportedUserId: 'other',
        reason: ReportReason.hate,
      );
      expect(second, ReportResult.duplicate,
          reason: 'Aynı hedef tekrar şikayet edilirse duplicate dönmeli');
    });

    test('farklı target_type aynı id → ayrı report sayılır', () async {
      await repo.reportContent(
        targetType: ReportTargetType.feedPost,
        targetId: 'x1',
        reason: ReportReason.spam,
      );
      final other = await repo.reportContent(
        targetType: ReportTargetType.comment,
        targetId: 'x1',
        reason: ReportReason.spam,
      );
      expect(other, ReportResult.submitted);
    });

    test('kendi içeriğini şikayet → SelfTargetException', () {
      expect(
        () => repo.reportContent(
          targetType: ReportTargetType.profile,
          targetId: 'me',
          reportedUserId: 'me',
          reason: ReportReason.other,
        ),
        throwsA(isA<SelfTargetException>()),
      );
    });

    test('block → blocked; tekrar → alreadyBlocked; unblock kaldırır',
        () async {
      expect(await repo.blockUser('u2'), BlockResult.blocked);
      expect(await repo.blockUser('u2'), BlockResult.alreadyBlocked);
      expect(await repo.listBlockedUserIds(), {'u2'});

      await repo.unblockUser('u2');
      expect(await repo.listBlockedUserIds(), isEmpty);
    });

    test('kendini engelleme → SelfTargetException', () {
      expect(
        () => repo.blockUser('me'),
        throwsA(isA<SelfTargetException>()),
      );
    });
  });

  group('V1 — GuardedSafetyRepository (guest guard)', () {
    test('guest: report/block/unblock → GuestActionRequiredException', () {
      final guarded = GuardedSafetyRepository(
        inner: LocalSafetyRepository(),
        canWriteCheck: () => false,
      );
      expect(
        () => guarded.reportContent(
          targetType: ReportTargetType.feedPost,
          targetId: 'p1',
          reason: ReportReason.spam,
        ),
        throwsA(isA<GuestActionRequiredException>()),
      );
      expect(
        () => guarded.blockUser('u2'),
        throwsA(isA<GuestActionRequiredException>()),
      );
      expect(
        () => guarded.unblockUser('u2'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('auth: aksiyonlar inner\'a delege edilir', () async {
      final guarded = GuardedSafetyRepository(
        inner: LocalSafetyRepository(),
        canWriteCheck: () => true,
      );
      expect(
        await guarded.reportContent(
          targetType: ReportTargetType.comment,
          targetId: 'c1',
          reason: ReportReason.harassment,
        ),
        ReportResult.submitted,
      );
      expect(await guarded.blockUser('u9'), BlockResult.blocked);
      expect(await guarded.listBlockedUserIds(), {'u9'});
    });
  });

  group('V1 — provider zinciri: block → blocked set güncellenir', () {
    test('blockUser sonrası blockedUserIdsSyncProvider yeni id\'yi içerir',
        () async {
      final container = ProviderContainer(overrides: [
        canWriteCheckProvider.overrideWithValue(() => true),
      ]);
      addTearDown(container.dispose);
      // Stream tick'inin provider'ı tazelemesi için listener.
      container.listen(blockedUserIdsProvider, (_, __) {});

      expect(container.read(blockedUserIdsSyncProvider), isEmpty);

      final repo = container.read(safetyRepositoryProvider);
      await repo.blockUser('bad-user');
      // watch tick → blockedUserIdsProvider yeniden hesaplanır.
      await Future<void>.delayed(Duration.zero);
      await container.read(blockedUserIdsProvider.future);

      expect(
        container.read(blockedUserIdsSyncProvider),
        contains('bad-user'),
      );
    });
  });

  group('V1 — GroupMessage.ownerId (şikayet/engel için yazar id)', () {
    test('ownerId taşınır; eski kayıtlarda null güvenli', () {
      final withOwner = GroupMessage(
        id: 'g1',
        groupId: 'grp',
        ownerId: 'u1',
        authorName: 'A',
        authorRole: 'Üye',
        text: 'merhaba',
        createdAt: DateTime(2026, 6, 11),
      );
      expect(withOwner.ownerId, 'u1');

      final legacy = GroupMessage(
        id: 'g2',
        groupId: 'grp',
        authorName: 'B',
        authorRole: 'Üye',
        text: 'eski',
        createdAt: DateTime(2026, 6, 11),
      );
      expect(legacy.ownerId, isNull);
    });
  });

  group('V1 — source contracts', () {
    String src(String path) => File(path).readAsStringSync();

    test('migration: tablolar + RLS + duplicate/self guard\'lar', () {
      final sql =
          src('supabase/migrations/20260611013000_ugc_safety_v1.sql');
      expect(sql.contains('create table public.content_reports'), isTrue);
      expect(sql.contains('create table public.user_blocks'), isTrue);
      expect(
        sql.contains('unique (reporter_id, target_type, target_id)'),
        isTrue,
        reason: 'Duplicate report DB seviyesinde engellenmeli',
      );
      expect(
        sql.contains('unique (blocker_id, blocked_user_id)'),
        isTrue,
        reason: 'Duplicate block DB seviyesinde engellenmeli',
      );
      expect(
        sql.contains('check (blocker_id <> blocked_user_id)'),
        isTrue,
        reason: 'Self-block DB seviyesinde engellenmeli',
      );
      expect(sql.contains('enable row level security'), isTrue);
      expect(sql.contains('content_reports_insert_own'), isTrue);
      expect(sql.contains('content_reports_select_own'), isTrue);
      expect(sql.contains('user_blocks_delete_own'), isTrue);
      // Kullanıcıya update/delete policy YOK (moderasyon kuyruğu korunur).
      expect(sql.contains('content_reports_update'), isFalse);
      expect(sql.contains('content_reports_delete'), isFalse);
      // reason CHECK 8 kategoriyi içerir.
      for (final r in ReportReason.values) {
        expect(sql.contains("'${r.persistKey}'"), isTrue,
            reason: '${r.persistKey} migration CHECK içinde olmalı');
      }
    });

    test('feed post kartı: şikayet + engelle menüde, kendi postunda yok', () {
      final s = src('lib/features/social/post/social_post_card.dart');
      expect(s.contains('ReportTargetType.feedPost'), isTrue);
      expect(s.contains('confirmAndBlockUser'), isTrue);
      expect(s.contains('(isOwner || post.ownerId.isEmpty)'), isTrue,
          reason: 'Kendi gönderisinde şikayet/engel sunulmamalı');
    });

    test('yorumlar: şikayet/engel menüsü + blocked placeholder', () {
      final s = src('lib/features/social/comments/comments_page.dart');
      expect(s.contains('ReportTargetType.comment'), isTrue);
      expect(s.contains('_BlockedCommentPlaceholder'), isTrue);
      expect(s.contains('blocked.contains(c.ownerId)'), isTrue);
    });

    test('grup mesajı: ownerId parse + uzun basma + blocked placeholder', () {
      final repo = src(
        'lib/features/social_groups/repositories/'
        'supabase_social_group_repository.dart',
      );
      expect(repo.contains("ownerId: row['owner_id'] as String?"), isTrue,
          reason: 'group_messages.owner_id artık parse edilmeli');
      final screen =
          src('lib/features/social_groups/screens/group_detail_screen.dart');
      expect(screen.contains('ReportTargetType.groupMessage'), isTrue);
      expect(screen.contains('_BlockedMessagePlaceholder'), isTrue);
      expect(screen.contains('onLongPress'), isTrue);
    });

    test('market + iş ilanları: şikayet/engel wiring', () {
      final market = src(
        'lib/features/marketplace/screens/marketplace_detail_screen.dart',
      );
      expect(market.contains('ReportTargetType.marketListing'), isTrue);
      final jobs = src('lib/features/jobs/screens/jobs_screen.dart');
      expect(jobs.contains('ReportTargetType.jobListing'), isTrue);
      expect(jobs.contains('_withJobSafetyActions'), isTrue);
    });

    test('profil: şikayet + engelle/engeli kaldır + mesaj başlatma engeli',
        () {
      final s = src('lib/features/social/profile/profile_page.dart');
      expect(s.contains('ReportTargetType.profile'), isTrue);
      expect(s.contains('AppStrings.safetyActionUnblock'), isTrue);
      expect(s.contains('AppStrings.blockedMessageStartBanner'), isTrue,
          reason: 'Engellenen kullanıcıya mesaj başlatılamamalı');
    });

    test('feed render filtresi: blocked postlar gizlenir', () {
      final s = src('lib/features/social/feed/social_feed_page.dart');
      expect(s.contains('blockedUserIdsSyncProvider'), isTrue);
      expect(s.contains('!blocked.contains(p.ownerId)'), isTrue);
    });

    test('report sheet: 8 kategori + guard + banner', () {
      final s = src('lib/features/safety/widgets/report_sheet.dart');
      expect(s.contains('ReportReason.values'), isTrue,
          reason: 'Sheet tüm kategorileri listelemeli');
      expect(s.contains('canWriteWithRef'), isTrue,
          reason: 'Guest şikayette AuthRequiredSheet görmeli');
      expect(s.contains('AppStrings.reportSuccessBanner'), isTrue);
      expect(s.contains('AppStrings.reportDuplicateBanner'), isTrue);
    });

    test('AppStrings safety sabitleri tanımlı ve dolu', () {
      expect(AppStrings.reportSheetTitle, 'İçeriği şikayet et');
      expect(AppStrings.reportSuccessBanner,
          'Şikayetin alındı. Ekibimiz inceleyecek.');
      expect(AppStrings.safetyActionReport, isNotEmpty);
      expect(AppStrings.safetyActionBlock, isNotEmpty);
      expect(AppStrings.safetyActionUnblock, isNotEmpty);
      expect(AppStrings.blockConfirmTitle, isNotEmpty);
      expect(AppStrings.blockedContentPlaceholder, isNotEmpty);
      expect(AppStrings.blockedMessageStartBanner, isNotEmpty);
    });
  });
}
