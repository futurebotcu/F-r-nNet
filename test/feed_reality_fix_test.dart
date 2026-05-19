// FırınNet Feed Reality Fix — comment sheet bounded layout + optimistic
// like/save UI.
//
// Background:
//   Emülatör smoke (qa-screenshots/02_after_comment_tap.png + 03_after_avatar_tap.png):
//   - Yorum butonu tap → ekran dim oluyor ama sheet açılmıyor.
//     Root cause: `showModalBottomSheet(isScrollControlled: true)` + sheet
//     içeride `Column(mainAxisSize.min) + Flexible(child: list)` —
//     unbounded height + Flexible çakışıyor; RenderFlex assertion ile
//     sheet hiç çizilmiyor.
//   - Profil avatar tap → public profile düzgün açılıyor (yanlış teşhis).
//   - Like UX yavaş çünkü backend cevabı beklenirken UI değişmiyor.
//
// Fix:
//   * Comment sheet: dış sarma `SizedBox(height: (h - top) * 0.85)` ile
//     bounded. Donor (itsezlife) pattern: full Scaffold +
//     DraggableScrollableSheet (V1 için fixed-height yeterli).
//   * Like/Save: optimistic override state (_likedOverride, _savedOverride,
//     _likeCountOverride). Tap → UI anlık flip → backend call → success:
//     override clear; fail: revert.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reality Fix — Comment sheet bounded height', () {
    final src = File(
      'lib/features/feed/widgets/feed_comment_sheet.dart',
    ).readAsStringSync();

    test('Sheet dış sarmasında SizedBox(height: ...) var', () {
      // `Padding(child: SizedBox(height: sheetHeight, child: Column(...)))`
      expect(src.contains('SizedBox('), isTrue);
      expect(src.contains('sheetHeight'), isTrue);
      expect(
        src.contains("mq.size.height - mq.padding.top) * 0.85"),
        isTrue,
        reason: 'Sheet ekranın %85\'i ile bound olmalı',
      );
    });

    test('Column.mainAxisSize.max — bounded context için', () {
      expect(
        src.contains('mainAxisSize: MainAxisSize.max'),
        isTrue,
        reason: 'SizedBox bounded context veriyor → Column max ile dolu',
      );
    });
  });

  group('Reality Fix — Optimistic like/save UI', () {
    final src = File(
      'lib/features/feed/screens/feed_screen.dart',
    ).readAsStringSync();

    test('Override state field\'ları mevcut', () {
      expect(src.contains('bool? _likedOverride'), isTrue);
      expect(src.contains('bool? _savedOverride'), isTrue);
      expect(src.contains('int? _likeCountOverride'), isTrue);
    });

    test('Display getter\'lar override önceliklendiriyor', () {
      expect(
        src.contains('_likedOverride ?? post.isLiked'),
        isTrue,
      );
      expect(
        src.contains('_savedOverride ?? post.isSaved'),
        isTrue,
      );
      expect(
        src.contains('_likeCountOverride ?? post.likeCount'),
        isTrue,
      );
    });

    test('FeedPostCard display getter\'larını kullanıyor (anlık flip)', () {
      expect(src.contains('likeCount: _displayLikeCount'), isTrue);
      expect(src.contains('isLiked: _displayIsLiked'), isTrue);
      expect(src.contains('isSaved: _displayIsSaved'), isTrue);
    });

    test('Like handler: backend success sonrası override clear', () {
      // Source pattern: `_likedOverride = null;` success path'inde
      final idxFn = src.indexOf('Future<void> _onLikePressed');
      expect(idxFn, greaterThan(-1));
      final idxEnd = src.indexOf('Future<void> _onSavePressed', idxFn);
      final block = src.substring(idxFn, idxEnd);
      expect(block.contains('_likedOverride = null'), isTrue,
          reason: 'Success → override clear (next provider tick güncelleyecek)');
      expect(block.contains('_likeCountOverride = null'), isTrue);
    });

    test('Like handler: backend fail sonrası revert', () {
      final idxFn = src.indexOf('Future<void> _onLikePressed');
      final idxEnd = src.indexOf('Future<void> _onSavePressed', idxFn);
      final block = src.substring(idxFn, idxEnd);
      expect(block.contains('_likedOverride = wasLiked'), isTrue,
          reason: 'Fail → revert override + snackbar');
      expect(block.contains('_likeCountOverride = wasCount'), isTrue);
    });

    test('Save handler: aynı optimistic + revert pattern', () {
      final idxFn = src.indexOf('Future<void> _onSavePressed');
      final idxEnd = src.indexOf('Future<void> _onSharePressed', idxFn);
      final block = src.substring(idxFn, idxEnd);
      expect(block.contains('_savedOverride = newSaved'), isTrue);
      expect(block.contains('_savedOverride = null'), isTrue);
      expect(block.contains('_savedOverride = wasSaved'), isTrue,
          reason: 'Fail → revert');
    });
  });
}
