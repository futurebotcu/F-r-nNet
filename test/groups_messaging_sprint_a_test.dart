// FırınNet Groups & Messaging Sprint A — Trust, Identity, Branded Chat.
//
// Source-level invariants (mevcut messaging_m1_2_ui_test.dart deseniyle
// hizalı). Kapsam:
//   * G-5 — Grup mesaj yazarı artık kör "Misafir" değil; profil display_name.
//   * M-4 — Canlı chat ekranı marka token'lı ChatTheme kullanır.
//   * M-5 — Failed send / retry: optimistic sending/sent/error + üst şerit.
//   * M-7 — Marka-uyumlu boş sohbet state'i.
//   * AppStrings yeni sabitleri.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('G-5 — Grup mesaj yazar kimliği (hardcoded Misafir kaldırıldı)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/social_groups/screens/group_detail_screen.dart')
          .readAsStringSync();
    });

    test('Kör hardcoded authorName: \'Misafir\' sözleşmesi kaldırıldı', () {
      expect(
        src.contains("authorName: 'Misafir'"),
        isFalse,
        reason: 'G-5 — yazar adı artık profil display_name kaynağından gelir',
      );
    });

    test('Yazar adı profil display_name + güvenli fallback ile türetilir', () {
      expect(src.contains('profileControllerProvider'), isTrue);
      expect(src.contains('PublicProfile.fallbackName'), isTrue);
      expect(src.contains('authorName: authorName'), isTrue);
    });

    test('Owner mesajında authorRole "Kurucu" ayrımı', () {
      expect(
        src.contains('widget.isOwner ? AppStrings.groupFounder'),
        isTrue,
      );
    });
  });

  group('M-4 — Canlı chat marka teması', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/messaging/screens/chat_screen.dart')
          .readAsStringSync();
    });

    test('Branded ChatTheme tanımlı ve Chat widget\'a bağlı', () {
      expect(src.contains('_brandChatTheme()'), isTrue);
      expect(src.contains('theme: _brandChatTheme()'), isTrue);
      expect(src.contains('fcc.ChatTheme.light()'), isTrue);
    });

    test('Marka token\'ları (lemon/brandInk/white) bağlandı', () {
      expect(src.contains('AppColors.brandLemon'), isTrue);
      expect(src.contains('AppColors.brandInk'), isTrue);
      expect(src.contains('surfaceContainer:'), isTrue);
    });
  });

  group('M-5 — Failed send / retry (mesaj kaybı yok)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/messaging/screens/chat_screen.dart')
          .readAsStringSync();
    });

    test('Optimistic sending/sent/error durumları', () {
      expect(src.contains('fcc.MessageStatus.sending'), isTrue);
      expect(src.contains('fcc.MessageStatus.sent'), isTrue);
      expect(src.contains('fcc.MessageStatus.error'), isTrue);
    });

    test('Gönderilemeyen mesaj metni saklanır (kaybolmaz)', () {
      expect(src.contains('_pendingText'), isTrue);
      expect(src.contains('_trySend'), isTrue);
    });

    test('Hata → üst şerit "Tekrar dene" + bubble tap retry', () {
      expect(src.contains('PremiumTopBannerController.show'), isTrue);
      expect(src.contains('AppStrings.messagingRetryCta'), isTrue);
      expect(src.contains('PremiumTopBannerTone.danger'), isTrue);
      expect(src.contains('onMessageTap: _onMessageTap'), isTrue);
    });

    test('onMessageSend: _onSend sözleşmesi korunur', () {
      expect(src.contains('onMessageSend: _onSend'), isTrue);
    });
  });

  group('M-7 — Marka-uyumlu boş sohbet state', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/messaging/screens/chat_screen.dart')
          .readAsStringSync();
    });

    test('emptyChatListBuilder + _ChatEmptyState', () {
      expect(src.contains('emptyChatListBuilder'), isTrue);
      expect(src.contains('_ChatEmptyState'), isTrue);
    });
  });

  group('Sprint A — AppStrings yeni sabitleri', () {
    test('Empty/retry sabitleri tanımlı ve dolu', () {
      expect(AppStrings.messagingEmptyTitle, isNotEmpty);
      expect(AppStrings.messagingEmptySubtitle, isNotEmpty);
      expect(AppStrings.messagingRetryCta, isNotEmpty);
    });
  });
}
