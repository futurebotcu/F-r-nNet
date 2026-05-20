// FırınNet Social V2 Commit 3.7 — Story P0 reality fix.
//
// Bug:
//   Story upload + DB INSERT + soft-delete chain çalışıyordu, ama
//   `story-media` bucket `public=false` olduğu için
//   `_client.storage.from('story-media').getPublicUrl(path)` ile alınan
//   URL viewer'da Image.network tarafından açılamıyordu (private bucket
//   public URL 400/403 verir). Sonuç: DB doğru, storage doğru, viewer
//   boş.
//
// Fix:
//   `story-media` bucket `public=true` (migration 20260520130000).
//   `feed_stories` RLS tablo seviyesinde zaten görünürlüğü kontrol eder
//   (is_deleted=false AND expires_at>now() OR owner_id=auth.uid()).
//   Bucket public yapmak content_url string'ini değiştirmez; mevcut
//   row'lar hemen erişilebilir hale gelir.
//
// Release-öncesi P1 (not P0):
//   * Expired story storage cleanup cron veya signed URL hardening.
//   * Bu testte kapsam dışı.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('V2 Commit 3.7 — Migration: story-media bucket public', () {
    final src = File(
      'supabase/migrations/20260520130000_story_media_bucket_public.sql',
    ).readAsStringSync();

    test('Migration dosyası bucket public flip içerir', () {
      expect(
        src.contains(
          "update storage.buckets\nset public = true\nwhere id = 'story-media';",
        ),
        isTrue,
      );
    });

    test('Migration açıklaması root cause + karar gerekçesini içerir', () {
      // Kalıcı dokümantasyon: gelecek geliştiriciler / cleanup için.
      expect(src.contains('public=false'), isTrue);
      expect(src.contains('getPublicUrl'), isTrue);
      expect(src.contains('Release-öncesi P1'), isTrue);
    });
  });

  group('V2 Commit 3.7 — Repository pattern korunur', () {
    final src = _strip(
      File(
        'lib/features/social/stories/repositories/'
        'supabase_social_stories_repository.dart',
      ).readAsStringSync(),
    );

    test('content_url = getPublicUrl (bucket public sayesinde çalışır)', () {
      // Bucket public yapıldığı için getPublicUrl URL'i artık erişilir.
      // Kodda değişiklik gerekmez; aynı pattern hem önceki feed-media
      // hem story-media için kullanılır.
      expect(
        src.contains(
          "_client.storage.from('story-media').getPublicUrl(path)",
        ),
        isTrue,
      );
      expect(
        src.contains("'content_url': publicUrl"),
        isTrue,
      );
    });

    test('Upload → INSERT → rollback chain bozulmadı', () {
      expect(src.contains('uploadBinary('), isTrue);
      expect(src.contains(".from('feed_stories')"), isTrue);
      expect(src.contains('.single()'), isTrue);
      // Rollback: INSERT fail → storage.remove
      expect(src.contains(".storage.from('story-media').remove"), isTrue);
    });

    test('listFreshStories defansif `expires_at > now()` filtre', () {
      // Bucket public olsa da app içinde expired story görünmemeli.
      expect(src.contains(".gt('expires_at', nowIso)"), isTrue);
      expect(src.contains(".eq('is_deleted', false)"), isTrue);
    });
  });

  group('V2 Commit 3.7 — Story RLS feed_stories tablo seviyesinde korur',
      () {
    // Bucket public yapmak DB-level görünürlüğü etkilemez. feed_stories
    // SELECT policy hâlâ: (is_deleted=false AND expires_at>now())
    // OR owner_id=auth.uid().
    // Bu test migration dosyasının kararını belgeler.
    final src = File(
      'supabase/migrations/20260520120000_social_stories_v1.sql',
    ).readAsStringSync();

    test('feed_stories_select_visible policy korunur', () {
      expect(
        src.contains(
          '(is_deleted = false and expires_at > now())\n'
          '    or owner_id = auth.uid()',
        ),
        isTrue,
      );
    });
  });
}
