// Storage bucket sınırları migration'ı — kaynak sözleşmesi + istemci uyumu.
//
// Allowlist, istemcinin ürettiği her MIME türünü kapsamalı (aksi halde meşru
// yükleme kırılır) ve tehlikeli türleri (html/svg/octet-stream) içermemeli.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20261023090000_storage_bucket_limits_v1.sql',
  ).readAsStringSync().toLowerCase();
  final code = sql
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n');

  String blockFor(String bucket) {
    final end = code.indexOf("where id = '$bucket'");
    expect(end, greaterThan(0), reason: bucket);
    final start = code.lastIndexOf('update storage.buckets', end);
    return code.substring(start, end);
  }

  test('5 bucket da boyut + MIME sınırı alır; tehlikeli tür yok', () {
    for (final b in [
      'avatars',
      'market-media',
      'story-media',
      'feed-media',
      'chat-media',
    ]) {
      final block = blockFor(b);
      expect(block.contains('file_size_limit'), isTrue, reason: b);
      expect(block.contains('allowed_mime_types'), isTrue, reason: b);
      expect(block.contains('svg'), isFalse, reason: b);
      expect(block.contains('html'), isFalse, reason: b);
      expect(block.contains('octet-stream'), isFalse, reason: b);
    }
    expect(code.contains('delete'), isFalse);
    expect(code.contains('drop'), isFalse);
  });

  /// İstemci kaynaklarındaki `return 'mime'` değerleri bucket allowlist'inde.
  Set<String> clientMimes(String path, {Set<String> ignore = const {}}) {
    final src = File(path).readAsStringSync();
    return RegExp(r"return '((?:image|video)/[a-z0-9.+-]+)'")
        .allMatches(src)
        .map((m) => m.group(1)!)
        .where((m) => !ignore.contains(m))
        .toSet();
  }

  test('istemcinin ürettiği her MIME türü ilgili bucket allowlist\'inde', () {
    final cases = <String, List<String>>{
      'avatars': ['lib/features/profile/services/avatar_upload_service.dart'],
      'market-media': [
        'lib/features/marketplace/repositories/supabase_market_listing_repository.dart',
        'lib/features/b2b_market/services/b2b_media_upload_service.dart',
      ],
      'story-media': [
        'lib/features/social/stories/repositories/supabase_social_stories_repository.dart',
      ],
      'feed-media': [
        'lib/features/feed/repositories/supabase_feed_repository.dart',
      ],
      'chat-media': [
        'lib/features/messaging/services/chat_media_upload_service.dart',
      ],
    };
    cases.forEach((bucket, files) {
      final block = blockFor(bucket);
      for (final f in files) {
        for (final mime in clientMimes(f)) {
          expect(
            block.contains("'$mime'"),
            isTrue,
            reason: '$bucket ← $f: $mime',
          );
        }
      }
    });
  });

  test('boyut sınırları istemci cap\'lerinin üstünde', () {
    int mb(String bucket) {
      final m = RegExp(
        r'file_size_limit = (\d+) \* 1024 \* 1024',
      ).firstMatch(blockFor(bucket));
      return int.parse(m!.group(1)!);
    }

    expect(mb('avatars'), greaterThanOrEqualTo(5));
    expect(mb('market-media'), greaterThanOrEqualTo(5));
    expect(mb('story-media'), greaterThanOrEqualTo(5));
    expect(mb('feed-media'), greaterThanOrEqualTo(50)); // composer 50 MB video
    expect(mb('chat-media'), greaterThanOrEqualTo(25)); // chat 25 MB video
  });
}
