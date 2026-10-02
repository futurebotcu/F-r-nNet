// Final audit P2 temizliği regresyonları: composer önizlemesi feed ile aynı
// (contain, kırpmasız), Akademi içinden Akademi tekrar push edilmez, yatay
// şeritler sayfalamayı tetiklemez, Türkçe router hata sayfası.

import 'dart:io';

import 'package:firin_defter/app/router/app_router.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/academy/academy_navigation.dart';
import 'package:firin_defter/features/academy/data/academy_repository.dart';
import 'package:firin_defter/features/academy/models/academy_bot_profile.dart';
import 'package:firin_defter/features/academy/providers/academy_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _bot = 'ab010000-0000-4000-8000-000000000001';

void main() {
  test('composer görsel önizlemesi FeedPostImage ile aynı: contain + oran', () {
    final src = File(
      'lib/features/social/composer/social_composer_page.dart',
    ).readAsStringSync();
    expect(src.contains('Image.memory(bytes, fit: BoxFit.cover)'), isFalse);
    expect(
      src.contains('Image.memory(widget.bytes, fit: BoxFit.contain)'),
      isTrue,
    );
    expect(src.contains('FeedPostImage.clampAspect('), isTrue);
  });

  test('Akademi dikey liste dışındaki scroll loadMore tetiklemez', () {
    final src = File(
      'lib/features/academy/screens/academy_page.dart',
    ).readAsStringSync();
    expect(
      src.contains('n.depth != 0 || n.metrics.axis != Axis.vertical'),
      isTrue,
    );
  });

  testWidgets('Akademi sayfasındayken bot yazarına dokunuş tekrar push etmez', (
    tester,
  ) async {
    var academyBuilds = 0;
    late WidgetRef capturedRef;
    final router = GoRouter(
      initialLocation: AppRoutes.academy,
      routes: [
        GoRoute(
          path: AppRoutes.academy,
          builder: (_, __) {
            academyBuilds++;
            return Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                ref.watch(academyBotsByIdProvider);
                return TextButton(
                  onPressed: () => openUserProfileOrAcademy(context, ref, _bot),
                  child: const Text('author'),
                );
              },
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.userPublicProfile}/:id',
          builder: (_, __) => const Text('profile'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          academyRepositoryProvider.overrideWithValue(
            LocalAcademyRepository(
              bots: const [
                AcademyBotProfile(
                  profileId: _bot,
                  botKey: 'hijyen',
                  topic: AcademyTopic.hijyen,
                  bio: '',
                  isHumor: false,
                  allowDm: false,
                  displayOrder: 1,
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(capturedRef.read(academyBotsByIdProvider).valueOrNull, isNotEmpty);
    final before = academyBuilds;
    await tester.tap(find.text('author'));
    await tester.pumpAndSettle();
    expect(router.canPop(), isFalse, reason: 'Akademi tekrar push edilmedi');
    expect(find.text('profile'), findsNothing);
    expect(academyBuilds, before);
  });

  testWidgets('router errorBuilder Türkçe sayfa', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RouteNotFoundScreen()));
    expect(find.text(AppStrings.routeNotFoundTitle), findsOneWidget);
    expect(find.text(AppStrings.routeNotFoundCta), findsOneWidget);
  });

  test('post zaman etiketi: <60 dk hepsi "şimdi" değil', () {
    final src = File(
      'lib/features/social/post/social_post_card.dart',
    ).readAsStringSync();
    expect(src.contains("if (d.inMinutes < 1) return 'şimdi';"), isTrue);
    expect(src.contains(r"return '${d.inMinutes} dk önce';"), isTrue);
  });
}
