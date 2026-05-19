// FırınNet Social S3 — Feed image post regresyon testi.
//
// Scope:
//   1. Migration: feed_media tablo + bucket + sıkı RLS source-level.
//   2. AppStrings yeni sabitler.
//   3. FeedMedia model + FeedPost.mediaList + firstImage helper.
//   4. LocalFeedRepository.uploadFeedImage in-memory parite.
//   5. Source-level: Supabase repo upload path = {owner_id}/{post_id}/...
//      + getPublicUrl + bucket id 'feed-media'.
//   6. Source-level: Guarded uploadFeedImage write guard'lı.
//   7. pubspec image_picker + cached_network_image dep'leri.
//   8. FeedComposer "Foto ekle" buton render.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/feed/models/feed_media.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/feed_repository.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/feed/widgets/feed_composer.dart';
import 'package:firin_defter/features/auth/providers/can_write_check_provider.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

const _profile = BakeryProfile(
  displayName: 'Hasan Usta',
  accountType: AccountType.commercial,
  city: 'Konya',
  roleBadge: 'Fırıncı',
  email: 'hasan@example.com',
);

Widget _wrap({
  required FeedRepository feedRepo,
  BakeryProfile profile = _profile,
  bool canWrite = true,
}) {
  return ProviderScope(
    overrides: [
      feedRepositoryProvider.overrideWithValue(feedRepo),
      canWriteCheckProvider.overrideWithValue(() => canWrite),
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, profile),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: FeedComposer())),
  );
}

void main() {
  group('S3 — Migration file', () {
    const path =
        'supabase/migrations/20260519180000_social_s3_feed_media.sql';

    test('Dosya repo\'da var', () {
      expect(File(path).existsSync(), isTrue);
    });

    test('feed_media tablo + RLS + sıkı policy', () {
      final sql = File(path).readAsStringSync();
      expect(sql.contains('create table public.feed_media'), isTrue);
      expect(
        sql.contains("check (media_type in ('image','video'))"),
        isTrue,
      );
      expect(
        sql.contains('alter table public.feed_media enable row level security'),
        isTrue,
      );
      expect(sql.contains('feed_media_select_visible'), isTrue);
      expect(sql.contains('feed_media_insert_self'), isTrue);
      expect(sql.contains('feed_media_update_own'), isTrue);
      expect(sql.contains('feed_media_delete_own'), isTrue);
      // INSERT policy cross-check: owner_id = auth.uid() + post owner aynı
      expect(
        sql.contains('owner_id = auth.uid()') &&
            sql.contains('p.owner_id = auth.uid()'),
        isTrue,
        reason: 'INSERT policy hem media owner hem post owner kontrolü yapmalı',
      );
    });

    test('feed-media bucket public + path-prefix storage policy', () {
      final sql = File(path).readAsStringSync();
      expect(
        sql.contains("insert into storage.buckets (id, name, public)"),
        isTrue,
      );
      expect(sql.contains("'feed-media'"), isTrue);
      // Storage INSERT/UPDATE/DELETE path-prefix `(storage.foldername(name))[1] = auth.uid()::text`
      expect(
        sql.contains("(storage.foldername(name))[1] = auth.uid()::text"),
        isTrue,
        reason: 'Path prefix kontrolü storage policy\'lerinde olmalı',
      );
    });
  });

  group('S3 — AppStrings', () {
    test('Foto ekle / kaldır / hata metinleri', () {
      expect(AppStrings.feedComposerAddPhoto, 'Foto ekle');
      expect(AppStrings.feedComposerRemovePhoto, 'Resmi kaldır');
      expect(
        AppStrings.feedComposerPickError,
        'Resim seçilemedi. Lütfen tekrar dene.',
      );
      expect(
        AppStrings.feedComposerUploadError,
        'Resim yüklenemedi. Gönderi metin olarak kaydedildi.',
      );
      expect(AppStrings.feedImageLoadError, 'Resim yüklenemedi.');
    });
  });

  group('S3 — FeedMedia model + FeedPost.mediaList', () {
    test('FeedMedia.fromRow + publicUrl pass-through', () {
      final media = FeedMedia.fromRow(
        <String, dynamic>{
          'id': 'm1',
          'post_id': 'p1',
          'owner_id': 'u1',
          'media_type': 'image',
          'storage_path': 'u1/p1/m1.jpg',
          'width': 1024,
          'height': 768,
          'size_bytes': 12345,
          'created_at': '2026-05-19T15:30:00Z',
        },
        publicUrl: 'https://example.com/u1/p1/m1.jpg',
      );
      expect(media.id, 'm1');
      expect(media.isImage, isTrue);
      expect(media.isVideo, isFalse);
      expect(media.publicUrl, 'https://example.com/u1/p1/m1.jpg');
      expect(media.width, 1024);
    });

    test('FeedPost.firstImage + hasImage helper\'ları', () {
      final post = FeedPost(
        id: 'p1',
        ownerId: 'u1',
        type: PostType.production,
        author: 'X',
        role: 'Üye',
        text: 'hi',
        createdAt: DateTime(2026, 5, 19),
        gradient: const <Color>[Color(0xFFEEE), Color(0xFFDDD)],
        mediaList: [
          FeedMedia(
            id: 'm1',
            postId: 'p1',
            ownerId: 'u1',
            mediaType: 'image',
            storagePath: 'u1/p1/m1.jpg',
            publicUrl: 'https://x/u1/p1/m1.jpg',
            createdAt: DateTime(2026, 5, 19),
          ),
        ],
      );
      expect(post.hasImage, isTrue);
      expect(post.firstImage?.id, 'm1');
      expect(post.firstImage?.publicUrl, 'https://x/u1/p1/m1.jpg');
    });

    test('Boş mediaList → hasImage false, firstImage null', () {
      final post = FeedPost(
        id: 'p2',
        ownerId: 'u1',
        type: PostType.production,
        author: 'X',
        role: 'Üye',
        text: 'plain',
        createdAt: DateTime(2026, 5, 19),
        gradient: const <Color>[Color(0xFFEEE), Color(0xFFDDD)],
      );
      expect(post.hasImage, isFalse);
      expect(post.firstImage, isNull);
    });
  });

  group('S3 — LocalFeedRepository.uploadFeedImage', () {
    test('Post mediaList\'e ekler + fake URL üretir', () async {
      final repo = LocalFeedRepository(seed: false, currentUserId: 'me');
      final post = await repo.addPost(
        type: PostType.production,
        author: 'Me',
        role: 'Usta',
        text: 'görselli post',
      );
      final media = await repo.uploadFeedImage(
        postId: post.id,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileExtension: 'jpg',
        width: 800,
        height: 600,
      );
      expect(media.mediaType, 'image');
      expect(media.ownerId, 'me');
      expect(media.publicUrl, startsWith('local://'));
      expect(media.storagePath.contains('me/'), isTrue);
      expect(media.storagePath.contains('/${post.id}/'), isTrue);
      // listPosts mediaList ile geliyor mu?
      final reloaded = await repo.listPosts();
      expect(reloaded.first.firstImage?.id, media.id);
    });

    test('Bilinmeyen post → StateError', () async {
      final repo = LocalFeedRepository(seed: false, currentUserId: 'me');
      expect(
        () => repo.uploadFeedImage(
          postId: 'nope',
          bytes: Uint8List.fromList(<int>[]),
          fileExtension: 'jpg',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('S3 — Source-level Supabase upload path', () {
    final src = File(
      'lib/features/feed/repositories/supabase_feed_repository.dart',
    ).readAsStringSync();

    test('Storage bucket adı doğru', () {
      expect(src.contains("from('feed-media')"), isTrue);
    });

    test('Upload path {userId}/{postId}/{mediaId}.{ext} formatında', () {
      // Path string template
      expect(src.contains(r"final path = '$userId/$postId/$mediaId.$ext';"),
          isTrue);
    });

    test('getPublicUrl çağrısı + feed_media INSERT', () {
      expect(src.contains('getPublicUrl(path)'), isTrue);
      expect(src.contains("from('feed_media')"), isTrue);
      expect(src.contains("'media_type': 'image'"), isTrue);
      expect(src.contains("'owner_id': userId"), isTrue);
      expect(src.contains("'storage_path': path"), isTrue);
    });

    test('listPosts mediaByPostId join çağırıyor', () {
      expect(src.contains('_fetchMediaByPostIds'), isTrue);
      expect(src.contains('mediaByPostId: media'), isTrue);
    });
  });

  group('S3 — Source-level Guarded uploadFeedImage', () {
    final src = File(
      'lib/features/feed/repositories/guarded_feed_repository.dart',
    ).readAsStringSync();

    test('Write guard yerinde', () {
      expect(src.contains('uploadFeedImage('), isTrue);
      expect(
        src.contains("_requireWrite('gönderiye resim eklemek')"),
        isTrue,
      );
    });
  });

  group('S3 — pubspec deps', () {
    test('image_picker + cached_network_image bağımlılığı pubspec\'te', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('image_picker:'), isTrue);
      expect(pubspec.contains('cached_network_image:'), isTrue);
    });
  });

  group('S3 — Composer UI', () {
    testWidgets(
      'Expanded composer "Foto ekle" butonu render eder',
      (tester) async {
        final repo = LocalFeedRepository(seed: false);
        await tester.pumpWidget(_wrap(feedRepo: repo));
        await tester.pumpAndSettle();
        // Composer collapsed. Önce expand.
        await tester.tap(find.byType(FeedComposer));
        await tester.pumpAndSettle();
        // Foto ekle CTA görünür.
        expect(find.text(AppStrings.feedComposerAddPhoto), findsOneWidget);
      },
    );
  });
}
