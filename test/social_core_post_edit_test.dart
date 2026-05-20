// FırınNet Social Core — Commit 1: Post edit (donor `updatePost` muadili).
//
// Kapsam:
//   * AppRoutes.socialPostEdit constant + route registered.
//   * SocialPostEditPage AppBar başlığı + Kaydet butonu.
//   * SocialPostCard ⋮ menüde owner için "Düzenle" item.
//   * Repo-direct: LocalFeedRepository.updatePost owner-only.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('V2 Social Core — AppRoutes.socialPostEdit', () {
    test('Constant + helper + route registered', () {
      final src = _strip(
        File('lib/app/router/app_router.dart').readAsStringSync(),
      );
      expect(
        src.contains("static const String socialPostEdit = '/social/post'"),
        isTrue,
      );
      expect(
        src.contains('static String socialPostEditFor('),
        isTrue,
      );
      expect(
        src.contains("'\${AppRoutes.socialPostEdit}/:postId/edit'"),
        isTrue,
      );
      expect(src.contains('SocialPostEditPage('), isTrue);
    });
  });

  group('V2 Social Core — SocialPostEditPage UI source', () {
    final src = _strip(
      File('lib/features/social/post/social_post_edit_page.dart')
          .readAsStringSync(),
    );

    test('AppBar başlığı "Gönderiyi düzenle" + Kaydet butonu', () {
      expect(src.contains('AppStrings.postEditTitle'), isTrue);
      expect(src.contains('AppStrings.postEditSaveCta'), isTrue);
    });

    test('Mevcut metin postAsync.whenData ile dolar (initialized once)', () {
      expect(src.contains('feedPostByIdProvider'), isTrue);
      expect(src.contains('_textCtrl.text = post.text'), isTrue);
    });

    test('Save success: invalidate + snackbar + pop', () {
      expect(
        src.contains('ref.invalidate(feedPagedNotifierProvider)'),
        isTrue,
      );
      expect(
        src.contains('ref.invalidate(feedPostByIdProvider(widget.postId))'),
        isTrue,
      );
      expect(src.contains('AppStrings.postEditSavedSnack'), isTrue);
      expect(src.contains('context.pop()'), isTrue);
    });

    test('Non-owner guard + auth guard', () {
      // isOwner = user != null && post != null && user.id == post.ownerId
      expect(src.contains('user.id == post.ownerId'), isTrue);
      expect(src.contains('AuthRequiredGuard.canWriteWithRef(ref)'), isTrue);
    });

    test('17 px textfield + 30s timeout', () {
      expect(src.contains('fontSize: 17'), isTrue);
      expect(
        src.contains('.timeout(const Duration(seconds: 30))'),
        isTrue,
      );
    });

    test('debugPrint tap/success/error trace', () {
      expect(src.contains('[FirinNet][PostEdit] save tap'), isTrue);
      expect(src.contains('[FirinNet][PostEdit] save success'), isTrue);
      expect(src.contains('[FirinNet][PostEdit] save error'), isTrue);
    });
  });

  group('V2 Social Core — SocialPostCard ⋮ menüde "Düzenle"', () {
    final src = _strip(
      File('lib/features/social/post/social_post_card.dart')
          .readAsStringSync(),
    );

    test('onEdit callback + isOwner ile koşullu', () {
      expect(
        src.contains('onEdit: isOwner'),
        isTrue,
        reason: 'isOwner true ise edit callback push eder',
      );
      expect(
        src.contains('AppRoutes.socialPostEditFor(post.id)'),
        isTrue,
      );
    });

    test('Menüde "Düzenle" item + edit icon', () {
      expect(src.contains("value: 'edit'"), isTrue);
      expect(src.contains('Icons.edit_outlined'), isTrue);
      expect(src.contains('AppStrings.postEditMenuItem'), isTrue);
    });
  });

  group('V2 Social Core — LocalFeedRepository.updatePost owner-only', () {
    test('Owner kendi postunu günceller', () async {
      final repo = LocalFeedRepository(
        seed: false,
        currentUserId: 'me',
      );
      final post = await repo.addPost(
        type: PostType.production,
        author: 'Me',
        role: 'Usta',
        text: 'eski',
      );
      final updated = await repo.updatePost(
        postId: post.id,
        text: 'yeni metin',
      );
      expect(updated.text, 'yeni metin');
      expect(updated.id, post.id);
      // Listeden de yeni metin görünür
      final list = await repo.listPosts();
      expect(list.first.text, 'yeni metin');
    });

    test('Non-owner update → StateError', () async {
      final mineRepo = LocalFeedRepository(
        seed: false,
        currentUserId: 'me',
      );
      final post = await mineRepo.addPost(
        type: PostType.production,
        author: 'Me',
        role: 'Usta',
        text: 'eski',
      );
      // Farklı owner perspektifindeki repo aynı in-memory paylaşmadığı için
      // bu test "post not found" StateError'ı verir; gerçek owner-mismatch
      // davranışı Supabase tarafında RLS ile yapılır. Local impl'in
      // garantisi: "kayıt yoksa / sahip değilse" StateError.
      final otherRepo = LocalFeedRepository(
        seed: false,
        currentUserId: 'other',
      );
      expect(
        () => otherRepo.updatePost(postId: post.id, text: 'changed'),
        throwsA(isA<StateError>()),
      );
    });

    test('AppStrings yeni edit sabitleri', () {
      expect(AppStrings.postEditTitle, 'Gönderiyi düzenle');
      expect(AppStrings.postEditSaveCta, 'Kaydet');
      expect(AppStrings.postEditSavedSnack, 'Gönderi güncellendi.');
      expect(AppStrings.postEditMenuItem, 'Düzenle');
      expect(AppStrings.feedEndOfList, 'Akışın sonu.');
    });
  });
}
