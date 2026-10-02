// Sosyal/ekran tasarım geçişi — regresyon testleri.
//
// Kapsam: post kartı dar ekran + büyük yazı taşmaması, caption "devamını
// gör", feed görsel hata durumu, mesaj listesi zaman etiketi, bildirim hata
// + yeniden dene, sohbet composer Türkçe ipucu, composer seçili tür çipi
// kontrastı.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/error_retry_state.dart';
import 'package:firin_defter/features/academy/models/academy_bot_profile.dart';
import 'package:firin_defter/features/academy/providers/academy_providers.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/feed/models/feed_media.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/messages/screens/messages_list_screen.dart';
import 'package:firin_defter/features/messaging/models/conversation.dart';
import 'package:firin_defter/features/notifications/models/app_notification.dart';
import 'package:firin_defter/features/notifications/providers/notification_providers.dart';
import 'package:firin_defter/features/notifications/screens/notifications_screen.dart';
import 'package:firin_defter/features/social/post/social_post_card.dart';
import 'package:firin_defter/features/social/post/widgets/feed_post_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ownerId = 'ab010000-0000-4000-8000-000000000001';

FeedPost _post({
  String author = 'FırınNet Akademi',
  String text = 'Kısa bir not.',
  String role = '',
  bool image = false,
}) {
  return FeedPost(
    id: 'p1',
    ownerId: _ownerId,
    author: author,
    role: role,
    type: PostType.announcement,
    text: text,
    tags: const ['ekşimaya', 'taşfırın'],
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    gradient: const [Color(0xFFFFF3C4), Color(0xFFFFE082)],
    mediaList: [
      if (image)
        FeedMedia(
          id: 'm1',
          postId: 'p1',
          ownerId: _ownerId,
          mediaType: 'image',
          storagePath: 'x/card.png',
          publicUrl: 'https://example.invalid/card.png',
          width: 1200,
          height: 675,
          createdAt: DateTime(2026, 10, 1, 10),
        ),
    ],
  );
}

Widget _host(
  Widget child, {
  double width = 390,
  double textScale = 1.0,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      currentAuthUserProvider.overrideWith((_) => null),
      feedRepositoryProvider.overrideWith(
        (_) => LocalFeedRepository(seed: false),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Post kartı — dar ekran + büyük yazı', () {
    testWidgets('320px + 1.3x, uzun isim + tür + AI rozeti taşmaz', (
      tester,
    ) async {
      const bot = AcademyBotProfile(
        profileId: _ownerId,
        botKey: 'ekmek_fermantasyon',
        topic: AcademyTopic.ekmekFermantasyon,
        bio: 'bio',
        isHumor: false,
        allowDm: false,
        displayOrder: 10,
      );
      await tester.pumpWidget(
        _host(
          SocialPostCard(
            post: _post(
              author: 'Çok Uzun İsimli Fırıncı Ustası Mehmet Ali Yılmazoğlu',
              role: 'Usta / Çalışan · Ekmek ve hamur işleri',
            ),
          ),
          width: 320,
          textScale: 1.3,
          overrides: [
            academyBotsByIdProvider.overrideWith(
              (_) async => {_ownerId: bot},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('academy_ai_badge')), findsOneWidget);
      expect(find.text(PostType.announcement.label), findsOneWidget);
      // Rozetler isim satırında değil, meta satırında.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('post_card_meta')),
          matching: find.byKey(const ValueKey('academy_ai_badge')),
        ),
        findsOneWidget,
      );
      expect(find.text('5 dk önce'), findsOneWidget);
    });

    testWidgets('uzun caption kısalır, "devamını gör" ile açılır', (
      tester,
    ) async {
      final long = List.filled(40, 'Hamur dinlendirme süresi önemlidir.')
          .join(' ');
      await tester.pumpWidget(_host(SocialPostCard(post: _post(text: long))));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.feedCaptionSeeMore), findsOneWidget);
      final collapsed = tester.widget<Text>(find.text(long));
      expect(collapsed.maxLines, 6);

      await tester.tap(find.byKey(const ValueKey('post_caption_expand')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.feedCaptionSeeMore), findsNothing);
      expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
    });

    testWidgets('kısa caption için "devamını gör" görünmez', (tester) async {
      await tester.pumpWidget(_host(SocialPostCard(post: _post())));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.feedCaptionSeeMore), findsNothing);
    });
  });

  group('Feed görseli', () {
    testWidgets('hata durumu "Görsel yüklenemedi" gösterir', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(height: 200, child: FeedImageErrorState()),
        ),
      );
      expect(find.text('Görsel yüklenemedi'), findsOneWidget);
      expect(AppStrings.feedPostImageLoadError, 'Görsel yüklenemedi');
    });

    testWidgets('errorWidget ortak hata durumunu, placeholder spinner '
        'olmayan nötr yüzeyi kullanır', (tester) async {
      await tester.pumpWidget(_host(SocialPostCard(post: _post(image: true))));
      await tester.pump();
      final img = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      final ctx = tester.element(find.byType(CachedNetworkImage));
      expect(
        img.errorWidget!(ctx, 'u', Exception('x')),
        isA<FeedImageErrorState>(),
      );
      expect(img.placeholder!(ctx, 'u'), isNot(isA<CircularProgressIndicator>()));
      expect(img.fit, BoxFit.contain);
    });
  });

  group('Mesaj listesi zaman etiketi', () {
    testWidgets('5 dakika önceki mesaj "5 dk" (gün değil)', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _host(
          ConversationTile(
            conversation: Conversation(
              id: 'c1',
              type: 'direct',
              contextType: 'profile_direct',
              createdAt: now,
              updatedAt: now,
              otherUserName: 'Ayşe',
              lastMessageContent: 'Merhaba',
              lastMessageCreatedAt: now.subtract(const Duration(minutes: 5)),
              unreadCount: 2,
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('5 dk'), findsOneWidget);
      expect(find.text('5d'), findsNothing);
    });
  });

  group('Bildirimler', () {
    testWidgets('hata durumunda yeniden dene gösterir', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAuthUserProvider.overrideWith((_) => null),
            notificationsProvider.overrideWith(
              (_) async => throw Exception('boom'),
            ),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ErrorRetryState), findsOneWidget);
      expect(find.text(AppStrings.retry), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('satırda göreli zaman görünür', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAuthUserProvider.overrideWith((_) => null),
            notificationsProvider.overrideWith(
              (_) async => [
                AppNotification(
                  id: 'n1',
                  recipientId: 'me',
                  type: 'group_join_request',
                  title: 'Başlık',
                  body: 'Gövde',
                  createdAt: DateTime.now().subtract(
                    const Duration(hours: 3),
                  ),
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 sa önce'), findsOneWidget);
    });
  });

  group('Kaynak sözleşmeleri', () {
    test('sohbet composer Türkçe ipucu kullanır', () {
      final src = File(
        'lib/features/messaging/screens/chat_screen.dart',
      ).readAsStringSync();
      expect(src.contains('composerBuilder:'), isTrue);
      expect(src.contains('hintText: AppStrings.chatComposerHint'), isTrue);
      expect(AppStrings.chatComposerHint, 'Mesaj yaz…');
    });

    test('sohbet başlığında şikayet/engelle menüsü var', () {
      final src = File(
        'lib/features/messaging/screens/chat_screen.dart',
      ).readAsStringSync();
      expect(src.contains('showReportSheet('), isTrue);
      expect(src.contains('confirmAndBlockUser('), isTrue);
    });

    test('composer seçili tür çipi etiketi limon değil (mürekkep)', () {
      final src = File(
        'lib/features/social/composer/social_composer_page.dart',
      ).readAsStringSync();
      final start = src.indexOf('final selected = t == _type;');
      expect(start, greaterThan(0));
      final block = src.substring(start, start + 2200);
      expect(block.contains('? AppColors.primary'), isFalse);
      expect(block.contains('? AppColors.brandInk'), isTrue);
      expect(block.contains('selectedColor: AppColors.brandLemonPale'), isTrue);
    });
  });
}
