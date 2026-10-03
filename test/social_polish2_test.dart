// Sosyal polish 2 — regresyon testleri.
//
// Kapsam: ortak avatar (feed kartı / yorum / mesaj listesi; baş harf +
// Akademi botu), gönderi detayı ↔ feed kartı ortak kimlik, sohbet ilk
// yükleme durumları (hata → Tekrar dene → başarı; boş ≠ hata), hikaye
// önizleme/izleyici aynı 9:16 kadraj, dar ekran + büyük yazı taşmaması,
// ilk yüklemede iskelet (bildirimler / mesajlar).

import 'dart:async';
import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/error_retry_state.dart';
import 'package:firin_defter/core/widgets/firinnet_avatar.dart';
import 'package:firin_defter/features/academy/data/academy_repository.dart';
import 'package:firin_defter/features/academy/models/academy_bot_profile.dart';
import 'package:firin_defter/features/academy/providers/academy_providers.dart';
import 'package:firin_defter/features/academy/screens/academy_page.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/messages/screens/messages_list_screen.dart';
import 'package:firin_defter/features/messaging/models/conversation.dart';
import 'package:firin_defter/features/messaging/models/message.dart';
import 'package:firin_defter/features/messaging/providers/messaging_providers.dart';
import 'package:firin_defter/features/messaging/repositories/local_messaging_repository.dart';
import 'package:firin_defter/features/messaging/screens/chat_screen.dart';
import 'package:firin_defter/features/notifications/models/app_notification.dart';
import 'package:firin_defter/features/notifications/providers/notification_providers.dart';
import 'package:firin_defter/features/notifications/screens/notifications_screen.dart';
import 'package:firin_defter/features/safety/providers/safety_providers.dart';
import 'package:firin_defter/features/social/comments/comments_page.dart';
import 'package:firin_defter/features/social/models/social_comment.dart';
import 'package:firin_defter/features/social/post/social_post_card.dart';
import 'package:firin_defter/features/social/profile/profile_page.dart';
import 'package:firin_defter/features/social/providers/social_providers.dart';
import 'package:firin_defter/features/social/stories/story_media_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _botId = 'ab010000-0000-4000-8000-000000000001';
const _humanId = 'user-0000-human';

final _bots = [
  const AcademyBotProfile(
    profileId: _botId,
    botKey: 'ekmek_fermantasyon',
    topic: AcademyTopic.ekmekFermantasyon,
    bio: 'bio',
    isHumor: false,
    allowDm: false,
    displayOrder: 10,
  ),
];

FeedPost _post({
  String id = 'p1',
  String owner = _humanId,
  String author = 'Ayşe Nur Kaya',
  String text = 'Kısa bir not.',
  String role = 'Usta / Çalışan',
}) {
  return FeedPost(
    id: id,
    ownerId: owner,
    author: author,
    role: role,
    type: PostType.question,
    text: text,
    tags: const ['ekşimaya'],
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    gradient: const [Color(0xFFFFF3C4), Color(0xFFFFE082)],
  );
}

class _SeedFeedRepo extends LocalFeedRepository {
  _SeedFeedRepo(this.seeded) : super(seed: false);
  final List<FeedPost> seeded;

  @override
  Future<List<FeedPost>> listPostsPageForFollowing({
    required Set<String> followingIds,
    int offset = 0,
    int limit = 20,
  }) async {
    final f = seeded.where((p) => followingIds.contains(p.ownerId)).toList();
    if (offset >= f.length) return const <FeedPost>[];
    return f.sublist(offset, (offset + limit).clamp(0, f.length));
  }
}

/// İlk listMessages çağrısında ağ hatası, sonra başarı (veya boş).
class _FlakyMessagingRepo extends LocalMessagingRepository {
  _FlakyMessagingRepo({this.failFirst = true, this.messages = const []});
  final bool failFirst;
  final List<Message> messages;
  int calls = 0;

  @override
  Future<List<Message>> listMessages(
    String conversationId, {
    int limit = 100,
  }) async {
    calls++;
    if (failFirst && calls == 1) {
      throw const SocketException('offline');
    }
    return messages;
  }
}

List<Override> _baseOverrides({LocalFeedRepository? feed}) => [
  currentAuthUserProvider.overrideWith((_) => null),
  feedRepositoryProvider.overrideWith(
    (_) => feed ?? LocalFeedRepository(seed: false),
  ),
  academyRepositoryProvider.overrideWithValue(
    LocalAcademyRepository(bots: _bots),
  ),
  blockedUserIdsSyncProvider.overrideWithValue(const <String>{}),
];

Widget _app(
  Widget home, {
  List<Override> overrides = const [],
  double width = 390,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: Size(width, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Center(
            child: SizedBox(width: width, child: home),
          ),
        ),
      ),
    ),
  );
}

Widget _scroll(Widget child) =>
    Scaffold(body: SingleChildScrollView(child: child));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('Ortak avatar (FirinNetAvatar) benimsendi', () {
    testWidgets('feed kartı: insan yazar → baş harfler', (tester) async {
      await tester.pumpWidget(
        _app(
          _scroll(SocialPostCard(post: _post())),
          overrides: _baseOverrides(),
        ),
      );
      await _settle(tester);
      final avatar = find.byKey(const ValueKey('post_author_avatar'));
      expect(avatar, findsOneWidget);
      expect(tester.widget<FirinNetAvatar>(avatar).size, FirinNetAvatarSize.m);
      expect(
        find.descendant(of: avatar, matching: find.text('AN')),
        findsOneWidget,
      );
    });

    testWidgets('feed kartı: Akademi botu → marka avatarı', (tester) async {
      await tester.pumpWidget(
        _app(
          _scroll(
            SocialPostCard(
              post: _post(owner: _botId, author: 'FırınNet Ekmek'),
            ),
          ),
          overrides: _baseOverrides(),
        ),
      );
      await _settle(tester);
      final avatar = find.byKey(const ValueKey('post_author_avatar'));
      expect(
        tester.widget<FirinNetAvatar>(avatar).kind,
        FirinNetAvatarKind.academy,
      );
      expect(
        find.descendant(
          of: avatar,
          matching: find.byKey(const ValueKey('avatar_academy')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('yorum satırı: s(32) avatar + baş harfler', (tester) async {
      final post = _post();
      await tester.pumpWidget(
        _app(
          SocialCommentsPage(postId: post.id, initialPost: post),
          overrides: [
            ..._baseOverrides(),
            feedPostByIdProvider(post.id).overrideWith((_) async => post),
            socialCommentsProvider(post.id).overrideWith(
              (_) async => [
                SocialComment(
                  id: 'c1',
                  postId: post.id,
                  ownerId: 'u-2',
                  authorName: 'mehmet ali',
                  authorRole: '',
                  isDeleted: false,
                  text: 'Harika.',
                  createdAt: DateTime.now(),
                ),
              ],
            ),
          ],
        ),
      );
      await _settle(tester);
      final avatar = find.byKey(const ValueKey('comment_author_avatar'));
      expect(avatar, findsOneWidget);
      expect(tester.widget<FirinNetAvatar>(avatar).size, FirinNetAvatarSize.s);
      expect(
        find.descendant(of: avatar, matching: find.text('MA')),
        findsOneWidget,
      );
    });

    testWidgets('mesaj listesi satırı: baş harfli ortak avatar', (
      tester,
    ) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _app(
          _scroll(
            ConversationTile(
              conversation: Conversation(
                id: 'c1',
                type: 'direct',
                contextType: 'profile_direct',
                createdAt: now,
                updatedAt: now,
                otherUserName: 'İsmail Şahin',
                lastMessageContent: 'Merhaba',
                lastMessageCreatedAt: now,
              ),
              onTap: () {},
            ),
          ),
        ),
      );
      final avatar = find.byType(FirinNetAvatar);
      expect(avatar, findsOneWidget);
      expect(
        find.descendant(of: avatar, matching: find.text('İŞ')),
        findsOneWidget,
      );
    });
  });

  group('Gönderi detayı ↔ feed kartı ortak kimlik', () {
    testWidgets('detay başlığı aynı avatar/ad/meta/aksiyon satırını çizer', (
      tester,
    ) async {
      final long = List.filled(
        30,
        'Hamur dinlendirme süresi önemlidir.',
      ).join(' ');
      final post = _post(text: long);
      await tester.pumpWidget(
        _app(
          SocialCommentsPage(postId: post.id, initialPost: post),
          overrides: [
            ..._baseOverrides(),
            feedPostByIdProvider(post.id).overrideWith((_) async => post),
            socialCommentsProvider(
              post.id,
            ).overrideWith((_) async => const <SocialComment>[]),
          ],
        ),
      );
      await _settle(tester);
      final header = find.byKey(const ValueKey('post_detail_header'));
      expect(header, findsOneWidget);
      // Feed kartındaki ortak parçalar.
      expect(
        find.descendant(of: header, matching: find.byType(SocialPostHeader)),
        findsOneWidget,
      );
      for (final key in const [
        'post_author_avatar',
        'post_author_name',
        'post_card_meta',
        'post_time',
        'post_action_row',
      ]) {
        expect(
          find.descendant(of: header, matching: find.byKey(ValueKey(key))),
          findsOneWidget,
          reason: key,
        );
      }
      expect(
        find.descendant(
          of: header,
          matching: find.text(PostType.question.label),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('5 dk önce')),
        findsOneWidget,
      );
      // Detayda caption kesilmez.
      expect(find.text(AppStrings.feedCaptionSeeMore), findsNothing);
      final caption = tester.widget<Text>(
        find.descendant(
          of: header,
          matching: find.byKey(const ValueKey('post_caption')),
        ),
      );
      expect(caption.maxLines, isNull);
      // Final sosyal: detay aynı aile, daha ferah (detailTextStyle).
      expect(caption.style, SocialPostCaption.detailTextStyle);
    });
  });

  group('Sohbet ilk yükleme durumları', () {
    Widget chat(_FlakyMessagingRepo repo) => _app(
      const ChatScreen(conversationId: 'conv-1'),
      overrides: [
        ..._baseOverrides(),
        messagingRepositoryProvider.overrideWithValue(repo),
      ],
    );

    testWidgets('hata → Tekrar dene GERÇEKTEN yeniden çeker → başarı', (
      tester,
    ) async {
      final repo = _FlakyMessagingRepo(
        messages: [
          Message(
            id: 'm1',
            conversationId: 'conv-1',
            senderId: 'other',
            content: 'Selam usta',
            createdAt: DateTime.now(),
          ),
        ],
      );
      await tester.pumpWidget(chat(repo));
      await _settle(tester);
      expect(find.byKey(const ValueKey('chat_load_error')), findsOneWidget);
      expect(find.text(AppStrings.chatLoadErrorTitle), findsOneWidget);
      // Ağ hatası boş sohbet gibi görünmez.
      expect(find.byKey(const ValueKey('chat_empty_state')), findsNothing);

      await tester.tap(find.text(AppStrings.messagingRetryCta));
      await _settle(tester);
      expect(repo.calls, 2);
      expect(find.byKey(const ValueKey('chat_load_error')), findsNothing);
      expect(find.text('Selam usta'), findsOneWidget);
    });

    testWidgets('boş sohbet hata değil: "Henüz mesaj yok"', (tester) async {
      final repo = _FlakyMessagingRepo(failFirst: false);
      await tester.pumpWidget(chat(repo));
      await _settle(tester);
      expect(find.byType(ErrorRetryState), findsNothing);
      expect(find.text(AppStrings.chatEmptyTitle), findsOneWidget);
    });

    testWidgets('yüklenirken hafif iskelet (dev spinner yok)', (tester) async {
      await tester.pumpWidget(chat(_FlakyMessagingRepo(failFirst: false)));
      expect(find.byKey(const ValueKey('chat_loading')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await _settle(tester);
    });
  });

  group('Hikaye kadrajı: önizleme = izleyici', () {
    test('ortak çerçeve 9:16 + cover', () {
      expect(StoryMediaFrame.aspectRatio, 9 / 16);
      expect(StoryMediaFrame.fit, BoxFit.cover);
    });

    test('oluşturma ve izleyici aynı çerçeve/fit kullanır', () {
      final create = File(
        'lib/features/social/stories/story_create_page.dart',
      ).readAsStringSync();
      final viewer = File(
        'lib/features/social/stories/story_viewer_page.dart',
      ).readAsStringSync();
      for (final src in [create, viewer]) {
        expect(src.contains('StoryMediaFrame('), isTrue);
        expect(src.contains('fit: StoryMediaFrame.fit'), isTrue);
        expect(src.contains('BoxFit.contain'), isFalse);
        expect(src.contains('aspectRatio: 9 / 16'), isFalse);
      }
    });

    testWidgets('çerçeve her genişlikte 9:16 kutu çizer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StoryMediaFrame(child: ColoredBox(color: Colors.black)),
          ),
        ),
      );
      final size = tester.getSize(
        find.byKey(const ValueKey('story_media_frame')),
      );
      expect(size.width / size.height, closeTo(9 / 16, 0.001));
    });
  });

  group('Dar ekran (320) + büyük yazı — taşma yok', () {
    for (final scale in const [1.0, 1.3, 1.5]) {
      testWidgets('feed kartı @$scale', (tester) async {
        await tester.pumpWidget(
          _app(
            _scroll(
              SocialPostCard(
                post: _post(
                  author:
                      'Çok Uzun İsimli Fırıncı Ustası Mehmet Ali Yılmazoğlu',
                  role: 'Usta / Çalışan · Ekmek ve hamur işleri',
                ),
              ),
            ),
            overrides: _baseOverrides(),
            width: 320,
            textScale: scale,
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('mesaj listesi @$scale', (tester) async {
        final now = DateTime.now();
        await tester.pumpWidget(
          _app(
            const MessagesListScreen(),
            overrides: [
              ..._baseOverrides(),
              conversationsListProvider.overrideWith(
                (_) async => [
                  Conversation(
                    id: 'c1',
                    type: 'direct',
                    contextType: 'job_offer',
                    createdAt: now,
                    updatedAt: now,
                    otherUserName: 'Çok Uzun İsimli Tedarikçi Firma Ltd. Şti.',
                    lastMessageContent: 'Fiyat teklifi için dönüş bekliyorum',
                    lastMessageCreatedAt: now,
                    unreadCount: 120,
                  ),
                ],
              ),
            ],
            width: 320,
            textScale: scale,
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('profil @$scale', (tester) async {
        await tester.pumpWidget(
          _app(
            const SocialProfilePage(userId: _humanId),
            overrides: _baseOverrides(),
            width: 320,
            textScale: scale,
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Akademi @$scale', (tester) async {
        await tester.pumpWidget(
          _app(
            const AcademyPage(),
            overrides: _baseOverrides(
              feed: _SeedFeedRepo([
                _post(owner: _botId, author: 'FırınNet Ekmek'),
              ]),
            ),
            width: 320,
            textScale: scale,
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('İlk yükleme iskeleti', () {
    testWidgets('bildirimler: iskelet, spinner yok', (tester) async {
      final pending = Completer<List<AppNotification>>();
      await tester.pumpWidget(
        _app(
          const NotificationsScreen(),
          overrides: [
            ..._baseOverrides(),
            notificationsProvider.overrideWith((_) => pending.future),
          ],
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('notifications_skeleton')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      pending.complete(const []);
      await _settle(tester);
    });

    testWidgets('mesajlar: iskelet, spinner yok', (tester) async {
      final pending = Completer<List<Conversation>>();
      await tester.pumpWidget(
        _app(
          const MessagesListScreen(),
          overrides: [
            ..._baseOverrides(),
            conversationsListProvider.overrideWith((_) => pending.future),
          ],
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('messages_skeleton')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      pending.complete(const []);
      await _settle(tester);
    });
  });
}
