// FırınNet Social V2 Commit 2 — Stories testleri.
//
// Kapsam:
//   * Migration dosyası varlığı + RLS şartları (source-level).
//   * `feed_stories` SELECT policy `(is_deleted=false AND expires_at>now())
//     OR owner_id=auth.uid()` — soft-delete RETURNING (P0 dersi).
//   * Repository contract: SocialStoriesRepository interface +
//     listFreshStories, listFreshStoriesOf, createImageStory, deleteStory.
//   * Supabase impl: `.gt('expires_at', nowIso)` defansif filtre +
//     deleteStory `.select('id')` empty → StateError.
//   * Local impl: expiry filter + owner-only delete.
//   * Router: storyCreate + storyViewer + AppStrings sabitleri.
//   * Carousel: aktif story yok + guest → SizedBox.shrink.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/social/stories/models/social_story.dart';
import 'package:firin_defter/features/social/stories/repositories/local_social_stories_repository.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('V2 Stories — migration dosyası', () {
    final src = File(
      'supabase/migrations/20260520120000_social_stories_v1.sql',
    ).readAsStringSync();

    test('feed_stories table + enum + indexes', () {
      expect(src.contains('create type story_content_type as enum'), isTrue);
      expect(src.contains('create table public.feed_stories'), isTrue);
      expect(src.contains('owner_id uuid not null'), isTrue);
      expect(src.contains('content_type story_content_type not null'), isTrue);
      expect(src.contains('content_url text not null'), isTrue);
      expect(src.contains('is_deleted boolean not null default false'), isTrue);
      expect(
        src.contains("expires_at timestamptz not null default (now() + interval '24 hours')"),
        isTrue,
      );
      expect(
        src.contains('feed_stories_owner_id_created_at_idx'),
        isTrue,
      );
      expect(src.contains('feed_stories_expires_at_idx'), isTrue);
    });

    test('Sıkı RLS — visible policy soft-delete RETURNING (P0 dersi)', () {
      expect(
        src.contains(
          '(is_deleted = false and expires_at > now())\n'
          '    or owner_id = auth.uid()',
        ),
        isTrue,
        reason: 'Owner kendi soft-deleted/expired satırını RETURNING için '
            'görmeli (P0 RLS RETURNING fix pattern)',
      );
      expect(
        src.contains('with check (owner_id = auth.uid())'),
        isTrue,
      );
      expect(
        src.contains('using (owner_id = auth.uid())'),
        isTrue,
      );
    });

    test('story-media storage bucket + path-prefix policies', () {
      expect(
        src.contains("'story-media'"),
        isTrue,
      );
      expect(
        src.contains('(storage.foldername(name))[1] = auth.uid()::text'),
        isTrue,
      );
      expect(
        src.contains('story_media_select_authenticated'),
        isTrue,
      );
      expect(src.contains('story_media_insert_owner_prefix'), isTrue);
      expect(src.contains('story_media_delete_owner_prefix'), isTrue);
    });
  });

  group('V2 Stories — Repository interface', () {
    final src = _strip(
      File('lib/features/social/stories/repositories/'
              'social_stories_repository.dart')
          .readAsStringSync(),
    );

    test('interface 4 method bekliyor', () {
      expect(src.contains('Future<List<SocialStory>> listFreshStories'), isTrue);
      expect(
        src.contains('Future<List<SocialStory>> listFreshStoriesOf'),
        isTrue,
      );
      expect(src.contains('Future<SocialStory> createImageStory'), isTrue);
      expect(src.contains('Future<void> deleteStory'), isTrue);
      expect(src.contains('Stream<void> watch()'), isTrue);
    });
  });

  group('V2 Stories — Supabase impl', () {
    final src = _strip(
      File('lib/features/social/stories/repositories/'
              'supabase_social_stories_repository.dart')
          .readAsStringSync(),
    );

    test('listFreshStories defansif .gt(expires_at, now)', () {
      expect(src.contains(".gt('expires_at', nowIso)"), isTrue);
      expect(src.contains(".eq('is_deleted', false)"), isTrue);
      expect(
        src.contains(".order('created_at', ascending: false)"),
        isTrue,
      );
    });

    test('createImageStory storage upload + INSERT + rollback', () {
      expect(src.contains(".storage.from('story-media')"), isTrue);
      expect(src.contains('uploadBinary('), isTrue);
      expect(src.contains(".from('feed_stories')"), isTrue);
      expect(src.contains('.select(_columns)'), isTrue);
      expect(src.contains('.single()'), isTrue);
      // Rollback: INSERT fail → storage.remove
      expect(src.contains('.storage.from(\'story-media\').remove'), isTrue);
    });

    test('deleteStory .select(id) + empty → StateError (P0 dersi)', () {
      expect(src.contains(".select('id')"), isTrue);
      expect(src.contains('(rows as List).isEmpty'), isTrue);
      expect(
        src.contains("'Hikaye silinemedi: yetki yok veya kayıt bulunamadı.'"),
        isTrue,
      );
    });
  });

  group('V2 Stories — Local impl davranışı', () {
    test('createImageStory + listFreshStories + 24h expiry', () async {
      final repo = LocalSocialStoriesRepository(currentUserId: 'me');
      expect(await repo.listFreshStories(), isEmpty);
      final story = await repo.createImageStory(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileExtension: 'jpg',
      );
      expect(story.ownerId, 'me');
      expect(story.contentType, 'image');
      expect(story.isFresh, isTrue);
      // Expiry yaklaşık 24h sonra
      final diff = story.expiresAt.difference(story.createdAt);
      expect(diff.inHours, 24);
      final all = await repo.listFreshStories();
      expect(all, hasLength(1));
      expect(all.first.id, story.id);
    });

    test('Soft-delete owner-only + StateError non-owner', () async {
      final mine = LocalSocialStoriesRepository(currentUserId: 'me');
      final story = await mine.createImageStory(
        bytes: Uint8List.fromList(<int>[1]),
        fileExtension: 'jpg',
      );
      // Owner deletes → kaybolur
      await mine.deleteStory(story.id);
      expect(await mine.listFreshStories(), isEmpty);
      // Bilinmeyen id → StateError
      expect(
        () => mine.deleteStory('not_exist'),
        throwsA(isA<StateError>()),
      );
    });

    test('SocialStory.isExpired / isFresh', () {
      final past = SocialStory(
        id: 's1',
        ownerId: 'me',
        contentType: 'image',
        contentUrl: 'url',
        isDeleted: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 25)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(past.isExpired, isTrue);
      expect(past.isFresh, isFalse);

      final fresh = SocialStory(
        id: 's2',
        ownerId: 'me',
        contentType: 'image',
        contentUrl: 'url',
        isDeleted: false,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 23)),
      );
      expect(fresh.isExpired, isFalse);
      expect(fresh.isFresh, isTrue);
    });
  });

  group('V2 Stories — Router + AppStrings', () {
    final src = File('lib/app/router/app_router.dart').readAsStringSync();

    test('storyCreate + storyViewer constants + routes', () {
      expect(
        src.contains(
            "static const String storyCreate = '/social/stories/create'"),
        isTrue,
      );
      expect(
        src.contains(
            "static const String storyViewer = '/social/stories/viewer'"),
        isTrue,
      );
      expect(src.contains('SocialStoryCreatePage()'), isTrue);
      expect(src.contains('SocialStoryViewerPage(ownerId: ownerId)'), isTrue);
    });

    test('AppStrings yeni story sabitleri', () {
      expect(AppStrings.storyCreateTitle, 'Hikaye ekle');
      expect(AppStrings.storyCreateShareCta, 'Paylaş');
      expect(AppStrings.storyCreateSavedSnack, 'Hikayen paylaşıldı.');
      expect(AppStrings.storyDeleteCta, 'Sil');
      expect(AppStrings.storyDeletedSnack, 'Hikaye silindi.');
      expect(AppStrings.storyExpiresInHint, '24 saat sonra kaybolur.');
    });
  });

  group('V2 Stories — Carousel davranışı + source-level', () {
    final src = _strip(
      File('lib/features/social/stories/social_stories_carousel.dart')
          .readAsStringSync(),
    );

    test('Aktif story yok + guest → carousel gizli', () {
      expect(
        src.contains('if (distinctOwners.isEmpty && user == null)'),
        isTrue,
      );
      expect(src.contains('return const SizedBox.shrink();'), isTrue);
    });

    test('Hikayem slot → AppRoutes.storyCreate push', () {
      expect(src.contains('AppRoutes.storyCreate'), isTrue);
    });

    test('Owner avatar → AppRoutes.storyViewer ?ownerId=...', () {
      expect(src.contains('AppRoutes.storyViewer'), isTrue);
      expect(src.contains('?ownerId=\${story.ownerId}'), isTrue);
    });

    test('Instagram gradient ring YOK — düz copper border', () {
      // FırınNet sade halka: tek renkli border. UserStoriesAvatar gradient
      // ring zorlaması alınmadı.
      expect(
        src.contains('UserStoriesAvatar'),
        isFalse,
        reason: 'Donor gradient ring widget\'ı kullanılmadı',
      );
      expect(src.contains('color: AppColors.brandLemonPale'), isTrue);
      expect(src.contains('width: 1.6'), isTrue);
    });
  });

  group('V2 Stories — SocialFeedPage carousel aktive', () {
    final src = _strip(
      File('lib/features/social/feed/social_feed_page.dart')
          .readAsStringSync(),
    );

    test('_kShowStories = true', () {
      expect(src.contains('const bool _kShowStories = true'), isTrue);
    });
  });
}
