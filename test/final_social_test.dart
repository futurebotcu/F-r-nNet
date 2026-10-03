// Final sosyal (Android release turu) — regresyon testleri.
//
// Kapsam: feed kartı (yalnız metin + uzun metin), gönderi detayı, profil,
// Akademi, mesaj listesi ve sohbet (başarı durumu) 320/360/390/430 genişlik
// × 1.0/1.3/1.5 yazı ölçeğinde taşmasız; hikaye çerçevesi 9:16 regresyonu;
// feed kartı kanonik ikon kaynağı (more_vert_rounded / share_outlined).

import 'dart:io';

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
import 'package:firin_defter/features/safety/providers/safety_providers.dart';
import 'package:firin_defter/features/social/comments/comments_page.dart';
import 'package:firin_defter/features/social/models/social_comment.dart';
import 'package:firin_defter/features/social/post/social_post_card.dart';
import 'package:firin_defter/features/social/profile/profile_page.dart';
import 'package:firin_defter/features/social/stories/story_media_frame.dart';
import 'package:firin_defter/features/social/providers/social_providers.dart';
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

final _longText = List.filled(
  24,
  'Hamur dinlendirme süresi ve fırın sıcaklığı ekmeğin kabuğunu belirler.',
).join(' ');

FeedPost _post({
  String id = 'p1',
  String owner = _humanId,
  String author = 'Çok Uzun İsimli Fırıncı Ustası Mehmet Ali Yılmazoğlu',
  String text = 'Kısa bir not.',
  String role = 'Usta / Çalışan · Ekmek ve hamur işleri',
  List<String> tags = const ['ekşimaya'],
}) {
  return FeedPost(
    id: id,
    ownerId: owner,
    author: author,
    role: role,
    type: PostType.question,
    text: text,
    tags: tags,
    likeCount: 12400,
    commentCount: 999,
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

class _ChatRepo extends LocalMessagingRepository {
  _ChatRepo(this.messages);
  final List<Message> messages;

  @override
  Future<List<Message>> listMessages(
    String conversationId, {
    int limit = 100,
  }) async => messages;
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

/// Gerçek görünüm boyutu (fiziksel piksel) + yazı ölçeği.
Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required double width,
  required double scale,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = Size(width * 3, 800 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: home,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Widget _scroll(Widget child) =>
    Scaffold(body: SingleChildScrollView(child: child));

const _widths = [320.0, 360.0, 390.0, 430.0];
const _scales = [1.0, 1.3, 1.5];

void main() {
  group('Taşma yok — genişlik × yazı ölçeği matrisi', () {
    for (final w in _widths) {
      for (final s in _scales) {
        final tag = '${w.toInt()}px @${s}x';

        testWidgets('feed kartı (yalnız metin) $tag', (tester) async {
          await _pump(
            tester,
            _scroll(SocialPostCard(post: _post(tags: const []))),
            width: w,
            scale: s,
            overrides: _baseOverrides(),
          );
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('post_caption')), findsOneWidget);
        });

        testWidgets('feed kartı (uzun metin) $tag', (tester) async {
          await _pump(
            tester,
            _scroll(SocialPostCard(post: _post(text: _longText))),
            width: w,
            scale: s,
            overrides: _baseOverrides(),
          );
          expect(tester.takeException(), isNull);
          // Uzun metin akışta kesilir; detay için "devamını gör" var.
          expect(
            find.byKey(const ValueKey('post_caption_expand')),
            findsOneWidget,
          );
        });

        testWidgets('gönderi detayı $tag', (tester) async {
          final post = _post(text: _longText);
          await _pump(
            tester,
            SocialCommentsPage(postId: post.id, initialPost: post),
            width: w,
            scale: s,
            overrides: [
              ..._baseOverrides(),
              feedPostByIdProvider(post.id).overrideWith((_) async => post),
              socialCommentsProvider(post.id).overrideWith(
                (_) async => [
                  SocialComment(
                    id: 'c1',
                    postId: post.id,
                    ownerId: 'u-2',
                    authorName: 'Çok Uzun İsimli Yorumcu Ayşe Nur Kaya',
                    authorRole: '',
                    isDeleted: false,
                    text: 'Harika bir bilgi, teşekkürler usta.',
                    createdAt: DateTime.now(),
                  ),
                ],
              ),
            ],
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('post_detail_header')),
            findsOneWidget,
          );
        });

        testWidgets('profil $tag', (tester) async {
          await _pump(
            tester,
            const SocialProfilePage(userId: _humanId),
            width: w,
            scale: s,
            overrides: _baseOverrides(),
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('Akademi $tag', (tester) async {
          await _pump(
            tester,
            const AcademyPage(),
            width: w,
            scale: s,
            overrides: _baseOverrides(
              feed: _SeedFeedRepo([
                _post(owner: _botId, author: 'FırınNet Ekmek'),
              ]),
            ),
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('mesaj listesi $tag', (tester) async {
          final now = DateTime.now();
          await _pump(
            tester,
            const MessagesListScreen(),
            width: w,
            scale: s,
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
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('sohbet (başarı) $tag', (tester) async {
          final now = DateTime.now();
          await _pump(
            tester,
            const ChatScreen(conversationId: 'conv-1'),
            width: w,
            scale: s,
            overrides: [
              ..._baseOverrides(),
              messagingRepositoryProvider.overrideWithValue(
                _ChatRepo([
                  Message(
                    id: 'm1',
                    conversationId: 'conv-1',
                    senderId: 'other',
                    content:
                        'Selam usta, yarın sabah için 200 ekmek '
                        'hazırlayabilir misin?',
                    createdAt: now,
                  ),
                ]),
              ),
            ],
          );
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('chat_load_error')), findsNothing);
          expect(find.textContaining('Selam usta'), findsOneWidget);
        });
      }
    }
  });

  group('Hikaye çerçevesi regresyonu', () {
    test('9:16 + cover korunur', () {
      expect(StoryMediaFrame.aspectRatio, 9 / 16);
      expect(StoryMediaFrame.fit, BoxFit.cover);
    });
  });

  group('Kanonik ikon kaynağı', () {
    final card = File(
      'lib/features/social/post/social_post_card.dart',
    ).readAsStringSync();

    test('feed kartı: more_vert_rounded + share_outlined, eski ikon yok', () {
      expect(card.contains('Icons.more_vert_rounded'), isTrue);
      expect(card.contains('Icons.share_outlined'), isTrue);
      expect(card.contains('Icons.more_horiz_rounded'), isFalse);
      expect(card.contains('Icons.ios_share_rounded'), isFalse);
    });

    test('aksiyon satırı ikonları eşit boyut (22)', () {
      expect(SocialPostActionRow.iconSize, 22);
      expect(card.contains('size: SocialPostActionRow.iconSize'), isTrue);
    });

    test('kapsamda more_horiz kalmadı', () {
      for (final path in const [
        'lib/features/social/comments/comments_page.dart',
        'lib/features/social/profile/profile_page.dart',
        'lib/features/messaging/screens/chat_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('Icons.more_horiz'), isFalse, reason: path);
      }
    });
  });

  testWidgets('feed kartında ⋮ ikonu kanonik (render)', (tester) async {
    await _pump(
      tester,
      _scroll(SocialPostCard(post: _post())),
      width: 390,
      scale: 1.0,
      overrides: _baseOverrides(),
    );
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
  });
}
