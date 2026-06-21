// Feed detay UX fix — açılış pozisyonu (ana gönderi ilk) + yorum ikon-aksiyon.
//
// HEDEF 1: initialPost ile detay açılışında ana gönderi İLK frame'de tam çizilir
// (postAsync loading'de küçük fallback'e düşüp post gelince yorumları aşağı
// itme/sıçrama olmaz). Yorumlar her zaman gönderinin ALTINDA.
// HEDEF 2: yorum aksiyonları ikon-bazlı — görünür "Beğen/Cevapla/Yorum" metni
// yok; beğeni sayısı (>0) ikon yanında. Cevap + beğeni işlevi korunur.

import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/can_write_check_provider.dart';
import 'package:firin_defter/features/auth/providers/guest_mode_provider.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/social/comments/comments_page.dart';
import 'package:firin_defter/features/social/providers/social_providers.dart';
import 'package:firin_defter/features/social/repositories/local_social_comments_repository.dart';
import 'package:firin_defter/features/social/repositories/social_comments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = BakeryProfile(
  displayName: 'Hasan Kara',
  accountType: AccountType.individual,
  city: 'Konya',
  roleBadge: 'Usta Fırıncı',
  email: 'hasan@example.com',
);

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

const _postText = 'ANA GONDERI METNI BURADA';

FeedPost _post() => FeedPost(
      id: 'p1',
      ownerId: 'u1',
      type: PostType.production,
      author: 'Hasan Kara',
      role: 'Usta Fırıncı',
      text: _postText,
      createdAt: DateTime(2026, 1, 1),
      gradient: const [Color(0xFFCCCCCC), Color(0xFFDDDDDD)],
    );

Widget _wrap({
  required SocialCommentsRepository repo,
  AuthUser? authUser,
  bool canWrite = true,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      socialCommentsRepositoryProvider.overrideWithValue(repo),
      canWriteCheckProvider.overrideWithValue(() => canWrite),
      currentAuthUserProvider.overrideWith((ref) => authUser),
      // _CommentLikeButton canWriteWithRef'i (guest+profil) doğrudan okur.
      guestModeProvider.overrideWith(
        (_) => GuestModeNotifier()..setGuest(false),
      ),
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, _profile),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

const _me = AuthUser(id: 'u1', email: null);

void main() {
  group('Detay açılış pozisyonu (ana gönderi ilk)', () {
    testWidgets('initialPost → ana gönderi İLK frame\'de; fallback yok',
        (tester) async {
      final repo = LocalSocialCommentsRepository(currentUserId: 'u1');
      await tester.pumpWidget(_wrap(
        repo: repo,
        authUser: _me,
        child: Scaffold(
          body: SocialCommentsPage(postId: 'p1', initialPost: _post()),
        ),
      ));
      await tester.pump(); // ilk frame, async settle YOK

      // Ana gönderi metni ilk frame'de var; küçük fallback kutu YOK
      // (post gelince büyüyüp yorumları aşağı itme/sıçraması olmaz).
      expect(find.text(_postText), findsOneWidget);
      expect(find.text('Bu gönderiye ait yorumlar.'), findsNothing);
    });

    testWidgets('Yorum varken ana gönderi yorumların ÜSTÜnde kalır',
        (tester) async {
      final repo = LocalSocialCommentsRepository(currentUserId: 'u1');
      await repo.addComment(postId: 'p1', text: 'YORUM ICERIGI');
      await tester.pumpWidget(_wrap(
        repo: repo,
        authUser: _me,
        child: Scaffold(
          body: SocialCommentsPage(postId: 'p1', initialPost: _post()),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(_postText), findsOneWidget);
      expect(find.text('YORUM ICERIGI'), findsOneWidget);
      // Ana gönderi dikey olarak yorumun üstünde.
      final postY = tester.getTopLeft(find.text(_postText)).dy;
      final commentY = tester.getTopLeft(find.text('YORUM ICERIGI')).dy;
      expect(postY, lessThan(commentY));
    });
  });

  group('Yorum aksiyonları ikon-bazlı', () {
    testWidgets('Beğen/Cevapla/Yorum görünür metni yok; ikon + sayı var',
        (tester) async {
      final repo = LocalSocialCommentsRepository(currentUserId: 'u1');
      final c = await repo.addComment(postId: 'p1', text: 'YORUM ICERIGI');
      await repo.toggleCommentLike(c.id); // likeCount 1, isLiked true
      await tester.pumpWidget(_wrap(
        repo: repo,
        authUser: _me,
        child: Scaffold(
          body: SocialCommentsPage(postId: 'p1', initialPost: _post()),
        ),
      ));
      await tester.pumpAndSettle();

      // Görünür aksiyon metinleri yok (Tooltip/semanticLabel'da kalır).
      expect(find.text('Beğen'), findsNothing);
      expect(find.text('Cevapla'), findsNothing);
      expect(find.text('Yorum'), findsNothing);
      // İkonlar var (cevap + beğeni-aktif).
      expect(find.byIcon(Icons.reply_rounded), findsWidgets);
      expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
      // Beğeni sayısı ikon yanında.
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('Cevapla ikonu → composer cevap moduna geçer (işlev korunur)',
        (tester) async {
      final repo = LocalSocialCommentsRepository(currentUserId: 'u1');
      await repo.addComment(postId: 'p1', text: 'YORUM ICERIGI');
      await tester.pumpWidget(_wrap(
        repo: repo,
        authUser: _me,
        child: Scaffold(
          body: SocialCommentsPage(postId: 'p1', initialPost: _post()),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.reply_rounded).first);
      await tester.pumpAndSettle();
      // Composer cevap-chip'i göründü ("<author> adlı kişiye cevap").
      expect(find.textContaining('cevap'), findsWidgets);
    });

    testWidgets('Beğeni ikonu → optimistic sayı artar (işlev korunur)',
        (tester) async {
      final repo = LocalSocialCommentsRepository(currentUserId: 'u1');
      await repo.addComment(postId: 'p1', text: 'YORUM ICERIGI'); // likeCount 0
      await tester.pumpWidget(_wrap(
        repo: repo,
        authUser: _me,
        child: Scaffold(
          body: SocialCommentsPage(postId: 'p1', initialPost: _post()),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsNothing); // 0 gizli
      await tester.tap(find.byIcon(Icons.thumb_up_alt_outlined).first);
      await tester.pump();
      expect(find.text('1'), findsOneWidget); // optimistic +1
    });
  });
}
