// FırınNet V1 — Feed Comment Sheet UX Hardening regresyon testi.
//
// Audit: bottom sheet üzerinde `ScaffoldMessenger.showSnackBar` çağırınca
// snackbar parent scaffold'a düşüyor ve sheet onun üzerini örtüyor → kullanıcı
// hata/başarı mesajını GÖREMEZ. Catch (_) ile ham hata sebebi de yutuluyor.
//
// Bu patch:
//   1. Empty/submit/network hata → sheet içinde inline error banner.
//   2. Başarı durumunda snackbar yok (input clear + yeni yorum listede dipte).
//   3. Guest kullanıcı → composer "Yorum yazmak için giriş yap" CTA, TextField
//      değil.
//   4. Network exception ayrı Türkçe mesaj; diğeri generic submit hatası.
//
// Test scope:
//   * AppStrings: yeni 3 sabit tanımlı.
//   * Source-level: sheet içinde inline error state + _humanizeError +
//     _GuestComposerCta var; ScaffoldMessenger ile showSnackBar çağrıları
//     kaldırılmış.
//   * Widget: guest user → CTA görünür, TextField görünmez.
//   * Widget: signed-in user + boş input + Gönder → inline error banner
//     görünür (snackbar değil).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/can_write_check_provider.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/feed_repository.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/feed/widgets/feed_comment_sheet.dart';

Widget _wrap({
  required FeedRepository feedRepo,
  AuthUser? authUser,
  bool canWrite = true,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      feedRepositoryProvider.overrideWithValue(feedRepo),
      canWriteCheckProvider.overrideWithValue(() => canWrite),
      currentAuthUserProvider.overrideWith((ref) => authUser),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('AppStrings — yeni hardening sabitleri', () {
    test('feedCommentErrorNetwork tanımlı', () {
      expect(
        AppStrings.feedCommentErrorNetwork,
        'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.',
      );
    });

    test('feedCommentErrorSubmit tanımlı', () {
      expect(
        AppStrings.feedCommentErrorSubmit,
        'Yorum gönderilemedi. Lütfen tekrar dene.',
      );
    });

    test('feedCommentGuestCta tanımlı', () {
      expect(
        AppStrings.feedCommentGuestCta,
        'Yorum yazmak için giriş yap',
      );
    });
  });

  group('Source-level — feed_comment_sheet.dart hardening', () {
    final src = File(
      'lib/features/feed/widgets/feed_comment_sheet.dart',
    ).readAsStringSync();

    test('Inline error state mevcut', () {
      expect(src.contains('String? _inlineError'), isTrue);
    });

    test('_humanizeError helper mevcut + network branch içerir', () {
      expect(src.contains('String _humanizeError'), isTrue);
      expect(src.contains('socketexception'), isTrue,
          reason: 'Network ayrımı yapan branch olmalı');
      expect(src.contains('AppStrings.feedCommentErrorNetwork'), isTrue);
      expect(src.contains('AppStrings.feedCommentErrorSubmit'), isTrue);
    });

    test('_GuestComposerCta widget mevcut', () {
      expect(src.contains('class _GuestComposerCta'), isTrue);
      expect(src.contains('AppStrings.feedCommentGuestCta'), isTrue);
    });

    test('Snackbar kullanımı sheet içinden kaldırıldı', () {
      // Yorum yorumlarında "snackbar" kelimesi geçebilir; sadece gerçek
      // `ScaffoldMessenger.of(context).showSnackBar(` çağrılarını ele al.
      expect(
        src.contains('ScaffoldMessenger.of(context).showSnackBar('),
        isFalse,
        reason: 'Sheet içinde snackbar çağrısı kalmamalı (sheet altında '
            'görünmez); inline error pattern kullanılır',
      );
    });

    test('Başarı sonrası snackbar yok, input clear + provider invalidate var',
        () {
      // _ctrl.clear() + ref.invalidate(feedCommentsProvider(...)) kalmalı
      expect(src.contains('_ctrl.clear()'), isTrue);
      expect(
          src.contains('ref.invalidate(feedCommentsProvider(widget.postId))'),
          isTrue);
    });
  });

  group('Widget — guest composer CTA', () {
    testWidgets(
      'Guest user → "Giriş yap" CTA görünür, TextField yok',
      (tester) async {
        final repo = LocalFeedRepository(seed: false);
        await tester.pumpWidget(_wrap(
          feedRepo: repo,
          authUser: null,
          canWrite: false,
          child: const FeedCommentSheet(postId: 'p1'),
        ));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.feedCommentGuestCta), findsOneWidget);
        expect(find.byType(TextField), findsNothing,
            reason: 'Guest composer\'da TextField olmamalı');
      },
    );

    testWidgets(
      'Signed-in user → TextField + Gönder görünür',
      (tester) async {
        final repo = LocalFeedRepository(seed: false);
        await tester.pumpWidget(_wrap(
          feedRepo: repo,
          authUser: const AuthUser(id: 'u1', email: null),
          child: const FeedCommentSheet(postId: 'p1'),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text(AppStrings.feedCommentSendCta), findsOneWidget);
      },
    );
  });

  group('Widget — inline error on empty submit', () {
    testWidgets(
      'Signed-in user + boş input + Gönder → inline error banner',
      (tester) async {
        final repo = LocalFeedRepository(seed: false);
        await tester.pumpWidget(_wrap(
          feedRepo: repo,
          authUser: const AuthUser(id: 'u1', email: null),
          child: const FeedCommentSheet(postId: 'p1'),
        ));
        await tester.pumpAndSettle();
        // Gönder butonuna bas (input boş).
        await tester.tap(find.text(AppStrings.feedCommentSendCta));
        await tester.pumpAndSettle();
        // Inline error banner mesajı görünür.
        expect(find.text(AppStrings.feedCommentEmptyError), findsOneWidget);
        // SnackBar AÇILMAMIŞ olmalı (sheet altında zaten görünmezdi).
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });
}
