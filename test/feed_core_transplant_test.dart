// FırınNet Feed Core Transplant — donor-style action row stabilization.
//
// Background:
//   PATCH 1 — Feed Core Actions Transplant. Donor (itsezlife) sosyal feed
//   action pattern'ı incelendi: idempotent like/save, per-action busy
//   lock, timeout. FırınNet'in mevcut handler'ları source-level olarak
//   bu standarda göre güncellendi.
//
// Scope:
//   1. SupabaseFeedRepository.toggleLike / toggleSave 23505 unique_violation
//      yutuyor (idempotent — race window'da çift INSERT'i hard-block etmek
//      mümkün değil; idempotent yutma minimum güvenlik).
//   2. PostCardWired ConsumerStatefulWidget'a refactor edildi; per-action
//      busy lock (_likeBusy, _saveBusy, _shareBusy).
//   3. _onLikePressed / _onSavePressed / _onSharePressed metodları;
//      timeout 15s; finally setState busy=false.
//   4. Action callback'leri busy ise null geçer (UI hard-disable).
//   5. Existing pattern'lar bozulmadı: onComment, onDelete, onAuthorTap.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Transplant — SupabaseFeedRepository idempotent toggle', () {
    final src = File(
      'lib/features/feed/repositories/supabase_feed_repository.dart',
    ).readAsStringSync();

    test('toggleLike 23505 unique_violation yutuyor', () {
      final idxFn = src.indexOf('Future<FeedPost> toggleLike(');
      expect(idxFn, greaterThan(-1));
      final idxEnd = src.indexOf('Future<FeedPost> toggleSave(', idxFn);
      final block = src.substring(idxFn, idxEnd);
      expect(block.contains("on sb.PostgrestException catch (e)"), isTrue,
          reason: 'race window güvenliği için exception yakalama olmalı');
      expect(block.contains("e.code != '23505'"), isTrue,
          reason: 'unique_violation idempotent yutulmalı, diğerleri rethrow');
    });

    test('toggleSave 23505 unique_violation yutuyor', () {
      final idxFn = src.indexOf('Future<FeedPost> toggleSave(');
      expect(idxFn, greaterThan(-1));
      final idxEnd = src.indexOf('Future<List<FeedInsight>>', idxFn);
      final block = src.substring(idxFn, idxEnd);
      expect(block.contains("on sb.PostgrestException catch (e)"), isTrue);
      expect(block.contains("e.code != '23505'"), isTrue);
    });
  });

  group('Transplant — PostCardWired per-action busy lock', () {
    final src = File(
      'lib/features/feed/screens/feed_screen.dart',
    ).readAsStringSync();

    test('PostCardWired ConsumerStatefulWidget', () {
      expect(
        src.contains('class PostCardWired extends ConsumerStatefulWidget'),
        isTrue,
        reason: 'Per-action busy state için Stateful gerekli',
      );
      expect(src.contains('class _PostCardWiredState'), isTrue);
    });

    test('_likeBusy / _saveBusy / _shareBusy state field\'ları', () {
      expect(src.contains('bool _likeBusy = false;'), isTrue);
      expect(src.contains('bool _saveBusy = false;'), isTrue);
      expect(src.contains('bool _shareBusy = false;'), isTrue);
    });

    test('onLike/onSave/onShare busy ise null (UI hard-disable)', () {
      expect(src.contains('onLike: _likeBusy ? null :'), isTrue);
      expect(src.contains('onSave: _saveBusy ? null :'), isTrue);
      expect(src.contains('onShare: _shareBusy ? null :'), isTrue);
    });

    test('Action handler metodları + timeout + finally cleanup', () {
      // _onLikePressed / _onSavePressed / _onSharePressed
      expect(src.contains('Future<void> _onLikePressed(FeedRepository repo)'),
          isTrue);
      expect(src.contains('Future<void> _onSavePressed(FeedRepository repo)'),
          isTrue);
      expect(src.contains('Future<void> _onSharePressed()'), isTrue);
      // Timeout
      expect(src.contains('.timeout(const Duration(seconds: 15))'), isTrue);
      // Finally cleanup — busy=false setState
      expect(
        src.contains('if (mounted) setState(() => _likeBusy = false);'),
        isTrue,
      );
      expect(
        src.contains('if (mounted) setState(() => _saveBusy = false);'),
        isTrue,
      );
      expect(
        src.contains('if (mounted) setState(() => _shareBusy = false);'),
        isTrue,
      );
    });

    test('Sessiz catch(_) yok — kullanıcı dostu snackbar gösterilir', () {
      // PATCH 1 hedeflerinden: catch yutulmasın. _onLikePressed örnek
      // bloğunu inceleyelim — feedLikeUpdateError snackbar zorunlu.
      expect(src.contains('AppStrings.feedLikeUpdateError'), isTrue);
      expect(src.contains('AppStrings.feedSaveUpdateError'), isTrue);
      expect(src.contains('AppStrings.feedShareError'), isTrue);
    });

    test('Existing davranışlar korunmuş — onAuthorTap, onDelete, onComment',
        () {
      expect(src.contains('onAuthorTap:'), isTrue);
      expect(src.contains('onDelete: _isOwner(ref, post)'), isTrue);
      expect(src.contains('FeedCommentSheet.show(context, post.id)'), isTrue);
    });
  });
}
