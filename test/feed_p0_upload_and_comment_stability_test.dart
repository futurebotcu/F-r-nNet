// FırınNet Feed P0 — Image upload chain + comment freeze fix.
//
// Background:
//   Real device test ortaya çıkardı: source-level testler geçtiği halde
//   gerçek upload zinciri kırıktı. Storage'a dosya yüklendi ama
//   feed_media INSERT 22P02 (`invalid input syntax for type uuid`)
//   atıyordu çünkü client-side `_newMediaId()` non-UUID string
//   üretiyordu (`0006522be759e1e9-0`). Catch (_) bunu yutuyordu;
//   kullanıcı "Resim yüklenemedi. Gönderi metin olarak kaydedildi."
//   snackbar görüyor, post text-only kalıyor, storage orphan oluyordu.
//
//   Comment tarafında: timeout yoktu; network hang `_sending=true`
//   stuck → kullanıcıya "donuyor" hissi.
//
// Fix:
//   * SupabaseFeedRepository._generateUuidV4() RFC-4122 v4 üretiyor.
//   * Upload fail olursa storage cleanup + composer post rollback.
//   * Comment + image upload + post create timeout (30s/60s/30s).
//   * Snackbar text "Gönderi paylaşılmadı." (silent text-only fallback
//     kaldırıldı).
//
// Bu test:
//   1. UUID v4 format doğrulama (regex + version/variant bit check).
//   2. Source-level: SupabaseFeedRepository upload INSERT fail path'inde
//      storage.remove çağrısı var (rollback).
//   3. Source-level: composer image upload fail olursa repo.deletePost
//      çağırıyor.
//   4. Source-level: composer + comment sheet + addPost timeout
//      kullanıyor.
//   5. AppStrings yeni mesaj.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';

void main() {
  group('P0 — AppStrings net hata', () {
    test('feedComposerUploadError artık "paylaşılmadı"', () {
      expect(
        AppStrings.feedComposerUploadError,
        'Resim yüklenemedi. Gönderi paylaşılmadı.',
      );
    });
  });

  group('P0 — SupabaseFeedRepository upload chain', () {
    final src = File(
      'lib/features/feed/repositories/supabase_feed_repository.dart',
    ).readAsStringSync();

    test('RFC-4122 v4 UUID üretici mevcut + bit-set kuralları', () {
      expect(src.contains('_generateUuidV4'), isTrue);
      // Version 4 nibble + RFC variant bit-set
      expect(src.contains('bytes[6] = (bytes[6] & 0x0F) | 0x40'), isTrue);
      expect(src.contains('bytes[8] = (bytes[8] & 0x3F) | 0x80'), isTrue);
    });

    test('_newMediaId hex-timestamp pattern kaldırılmış', () {
      // Eski format: `${now.padLeft(16, '0')}-$rnd` — Postgres uuid'e
      // cast'lenemiyordu. Yeni kodda olmamalı.
      expect(src.contains("now.padLeft(16, '0')"), isFalse,
          reason: 'Eski non-UUID üretici kaldırılmalı');
    });

    test('Insert fail olursa storage.remove ile rollback yapılıyor', () {
      // try { ... insert ... } catch (e) { ... remove ... rethrow }
      final idxUpload = src.indexOf('Future<FeedMedia> uploadFeedImage');
      expect(idxUpload, greaterThan(-1));
      final block = src.substring(idxUpload, idxUpload + 2500);
      expect(block.contains("from('feed-media').remove"), isTrue,
          reason: 'INSERT fail → storage objesi geri alınmalı (orphan engelle)');
      expect(block.contains('rethrow;'), isTrue,
          reason: 'Hata caller\'a iletilmeli (composer rollback için)');
    });
  });

  group('P0 — FeedComposer rollback + timeout', () {
    final src = File(
      'lib/features/feed/widgets/feed_composer.dart',
    ).readAsStringSync();

    test('addPost + uploadFeedImage timeout ekleniyor', () {
      expect(src.contains('.timeout(const Duration(seconds: 30))'), isTrue);
      expect(src.contains('.timeout(const Duration(seconds: 60))'), isTrue);
    });

    test('Image upload fail → repo.deletePost ile rollback', () {
      // Composer içinde uploadFeedImage çağrısı çok satırlı chain
      // olabilir; sadece `uploadFeedImage(` substring'i + ardından gelen
      // catch path'inde `deletePost(post.id)` çağrısı bekleriz.
      expect(src.contains('uploadFeedImage('), isTrue);
      expect(
        src.contains('repo.deletePost(post.id)'),
        isTrue,
        reason: 'Upload fail olursa text post rollback edilmeli',
      );
    });

    test('Silent text-only fallback (uploadFailed→snackbar) kaldırıldı', () {
      // Eski davranış: `Text(uploadFailed ? feedComposerUploadError : ...)`
      // ternary snackbar. Şimdi inline error + return.
      expect(
        src.contains('uploadFailed ? AppStrings.feedComposerUploadError'),
        isFalse,
        reason: 'Sessiz fallback ternary snackbar yok',
      );
    });
  });

  group('P0 — FeedCommentSheet timeout', () {
    final src = File(
      'lib/features/feed/widgets/feed_comment_sheet.dart',
    ).readAsStringSync();

    test('addComment timeout ekleniyor', () {
      // Sheet içinde addComment çağrısı timeout zinciri ile sarılı.
      expect(src.contains('.timeout(const Duration(seconds: 30))'), isTrue,
          reason: 'Network hang stuck busy state yapmasın diye timeout şart');
    });
  });
}
