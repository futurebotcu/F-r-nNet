// FırınNet — P0 wiring fix: comment delete + post delete + navigation
// kanıt testi.
//
// Smoke gözlemi (kullanıcı raporu):
//   1. Yorum silme çalışmıyor (UI'da feedback yok, refresh olmuyor).
//   2. Post silme sonrası feed/profile refresh olmuyor.
//   3. Feed kartına/üzerine tıklayınca yanlış akış açılıyor.
//   4. Comments page order: PostContext → "Yorumlar (N)" → list → composer.
//
// Bu testler source-level olarak fix'in yerinde kaldığını garantiler.
// Repo-direct delete davranışı ayrıca `social_f1_comments_rebuild_test`
// içinde `LocalSocialCommentsRepository` ile mevcut.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('P0 — Comment delete wiring', () {
    final raw = File(
      'lib/features/social/comments/comments_page.dart',
    ).readAsStringSync();
    final src = _strip(raw);

    test('_confirmAndDelete success path: invalidate + snackbar', () {
      // Manuel invalidate — autoDispose.family stream tick yarışlarını
      // bypass et.
      expect(
        src.contains('ref.invalidate(socialCommentsProvider(postId))'),
        isTrue,
      );
      // Post header'daki "N yorum" sayısı için.
      expect(
        src.contains('ref.invalidate(feedPostByIdProvider(postId))'),
        isTrue,
      );
      expect(
        src.contains('AppStrings.feedCommentDeletedSnack'),
        isTrue,
        reason: 'Başarılı silme snackbar gösterilir',
      );
    });

    test('_confirmAndDelete error path: snackbar + guest guard', () {
      expect(
        src.contains('on GuestActionRequiredException'),
        isTrue,
        reason: 'Guest exception ayrı handle edilir',
      );
      expect(
        src.contains('showAuthRequiredSheet'),
        isTrue,
      );
      expect(
        src.contains('AppStrings.feedCommentDeleteFailed'),
        isTrue,
        reason: 'Generic error snackbar gösterilir (sessiz değil)',
      );
    });

    test('debugPrint tap/success/error trace', () {
      expect(src.contains('[FirinNet][Comments] delete tap'), isTrue);
      expect(src.contains('[FirinNet][Comments] delete success'), isTrue);
      expect(src.contains('[FirinNet][Comments] delete error'), isTrue);
    });
  });

  group('P0 — Post delete wiring', () {
    final raw = File(
      'lib/features/social/post/social_post_card.dart',
    ).readAsStringSync();
    final src = _strip(raw);

    test('_onDeleteTap success path: 3 invalidate', () {
      expect(src.contains('ref.invalidate(feedPostsProvider)'), isTrue);
      expect(
        src.contains('ref.invalidate(feedPostByIdProvider(post.id))'),
        isTrue,
      );
      expect(
        src.contains('ref.invalidate(userPostsProvider(post.ownerId))'),
        isTrue,
        reason: 'Profile post listesi de refresh olmalı',
      );
    });

    test('_onDeleteTap 15s timeout + Türkçe hata mesajı', () {
      expect(
        src.contains('.timeout(const Duration(seconds: 15))'),
        isTrue,
      );
      expect(
        src.contains('AppStrings.feedPostDeleteError'),
        isTrue,
      );
      expect(
        src.contains('AppStrings.feedPostDeleteSuccess'),
        isTrue,
      );
    });

    test('debugPrint tap/success/error trace', () {
      expect(src.contains('[FirinNet][PostCard] delete tap'), isTrue);
      expect(src.contains('[FirinNet][PostCard] delete success'), isTrue);
      expect(src.contains('[FirinNet][PostCard] delete error'), isTrue);
    });
  });

  group('P0 — SocialPostCard navigation guards', () {
    final raw = File(
      'lib/features/social/post/social_post_card.dart',
    ).readAsStringSync();
    final src = _strip(raw);

    test('Root Container onTap YOK (geniş kart tap yorum açmaz)', () {
      // Kart container'ı sade `Container(decoration:..., child: Column(...))`;
      // GestureDetector veya InkWell ile sarılı değil.
      expect(
        src.contains('GestureDetector('),
        isFalse,
        reason: 'Kart root\'unda GestureDetector kullanılmıyor',
      );
      // build içinde "Container(" sayısı kontrol: yalnız decoration container.
      final containerOccurrences =
          'Container('.allMatches(src).length;
      expect(containerOccurrences, greaterThan(0));
    });

    test('SocialCommentsPage.show sadece 2 yerden çağrılır', () {
      // 1) Action row "Yorum" buton: onComment lambda
      // 2) _CommentsPreview onTap lambda
      final calls = RegExp(r'SocialCommentsPage\.show\(').allMatches(src);
      expect(
        calls.length,
        2,
        reason: 'Sadece Yorum buton + Tüm yorumları gör tap; başka yer yok',
      );
    });

    test('CommentsPreview chevron + softGold link görünümü', () {
      expect(src.contains('Icons.chevron_right_rounded'), isTrue);
      expect(src.contains('AppColors.softGold'), isTrue);
      // "Tüm yorumları gör" string'i kullanılıyor.
      expect(src.contains('postViewAllComments'), isTrue);
    });
  });

  group('P0 — Comments page order: PostContext → Heading → List → Composer',
      () {
    final raw = File(
      'lib/features/social/comments/comments_page.dart',
    ).readAsStringSync();
    final src = _strip(raw);

    test('ListView ilk öğe _PostContextHeader', () {
      // _PostDetailScroll içinde i==0 → _PostContextHeader.
      expect(
        src.contains('if (i == 0) return _PostContextHeader('),
        isTrue,
      );
    });

    test('ListView ikinci öğe _SectionHeading "Yorumlar (N)"', () {
      expect(
        src.contains('if (i == 1) return _SectionHeading('),
        isTrue,
      );
      expect(
        src.contains('AppStrings.postCommentsHeading'),
        isTrue,
      );
    });

    test('Composer body Column\'un son child\'ı (sticky bottom)', () {
      // Pattern: Expanded(child: ...) sonra Divider sonra _CommentComposer.
      // String içinde sırayı kabaca kontrol et.
      final expandedIdx = src.indexOf('Expanded(');
      final composerIdx = src.indexOf('_CommentComposer(');
      expect(expandedIdx, greaterThan(0));
      expect(composerIdx, greaterThan(expandedIdx),
          reason: 'Composer Expanded list bloğundan sonra (alta) geliyor');
    });
  });

  group('P0 — AppStrings yeni delete fail metni', () {
    test('feedCommentDeleteFailed Türkçe + tekrar dene yönlendirmesi', () {
      expect(AppStrings.feedCommentDeleteFailed.isNotEmpty, isTrue);
      expect(
        AppStrings.feedCommentDeleteFailed.toLowerCase().contains('silinemedi'),
        isTrue,
      );
    });
  });

  group('P0 — Supabase delete hardening: .select(id) + empty → throw', () {
    test('supabase_social_comments_repository deleteComment .select(id)', () {
      final raw = File(
        'lib/features/social/repositories/supabase_social_comments_repository.dart',
      ).readAsStringSync();
      final src = _strip(raw);
      // .update().eq().eq().select('id') zinciri sonrası empty check.
      expect(src.contains(".select('id')"), isTrue,
          reason: '0-row update silent-fail kapatıldı');
      expect(src.contains('(rows as List).isEmpty'), isTrue);
      expect(
        src.contains("'Yorum silinemedi: yetki yok veya kayıt bulunamadı.'"),
        isTrue,
      );
    });

    test('supabase_feed_repository deletePost .select(id)', () {
      final raw = File(
        'lib/features/feed/repositories/supabase_feed_repository.dart',
      ).readAsStringSync();
      final src = _strip(raw);
      // deletePost bloğunu izole et.
      final start = src.indexOf('Future<void> deletePost(String postId)');
      final endMarker = src.indexOf('Future<', start + 30);
      expect(start, greaterThan(0));
      expect(endMarker, greaterThan(start));
      final body = src.substring(start, endMarker);
      expect(body.contains(".select('id')"), isTrue,
          reason: 'deletePost hardened');
      expect(body.contains('(rows as List).isEmpty'), isTrue);
      expect(
        body.contains(
          "'Gönderi silinemedi: yetki yok veya kayıt bulunamadı.'",
        ),
        isTrue,
      );
    });
  });
}
