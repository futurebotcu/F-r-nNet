// Final audit P1 — cold-start push routing: getInitialMessage route'u router
// hazır olmadan / Splash kararından önce gelir; Splash'in go(feed)'i hedefi
// ezmemeli. Route bekletilir, Splash oturum kararından sonra feed'in ÜSTÜNE
// açılır (geri → feed).

import 'dart:io';

import 'package:firin_defter/features/notifications/notification_routing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const Text('splash')),
    GoRoute(path: '/feed', builder: (_, __) => const Text('feed')),
    GoRoute(
      path: '/post/:id',
      builder: (_, s) => Text('post ${s.pathParameters['id']}'),
    ),
  ],
);

void main() {
  setUp(PendingNotificationRoute.debugReset);

  test('boot öncesi tap bekletilir, router null olsa bile kaybolmaz', () {
    PendingNotificationRoute.handleTap('/post/42', null);
    expect(PendingNotificationRoute.debugPending, '/post/42');
    expect(PendingNotificationRoute.takeOnBoot(), '/post/42');
    expect(PendingNotificationRoute.debugPending, isNull);
  });

  test('oturumsuz boot bekleyen route\'u düşürür', () {
    PendingNotificationRoute.handleTap('/post/1', null);
    PendingNotificationRoute.discardOnBoot();
    expect(PendingNotificationRoute.takeOnBoot(), isNull);
  });

  testWidgets('cold-start: splash kararı sonrası hedef route korunur, '
      'geri → feed', (tester) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // getInitialMessage splash'tan önce geldi (router hazır olsa da boot yok).
    PendingNotificationRoute.handleTap('/post/42', router);
    await tester.pumpAndSettle();
    expect(find.text('splash'), findsOneWidget);

    goHomeThenPending(router, '/feed');
    await tester.pumpAndSettle();
    expect(find.text('post 42'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('feed'), findsOneWidget);
  });

  testWidgets('boot sonrası (background) tap doğrudan işlenir', (tester) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    goHomeThenPending(router, '/feed');
    await tester.pumpAndSettle();
    PendingNotificationRoute.handleTap('/post/7', router);
    await tester.pumpAndSettle();
    expect(find.text('post 7'), findsOneWidget);
  });

  testWidgets('bekleyen route yoksa normal feed', (tester) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    goHomeThenPending(router, '/feed');
    await tester.pumpAndSettle();
    expect(find.text('feed'), findsOneWidget);
  });

  testWidgets('splash dışı açılış (deep link): tap kuyrukta kalmaz', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/feed',
      routes: [
        GoRoute(path: '/feed', builder: (_, __) => const Text('feed')),
        GoRoute(
          path: '/post/:id',
          builder: (_, s) => Text('post ${s.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    PendingNotificationRoute.handleTap('/post/9', router);
    await tester.pumpAndSettle();
    expect(find.text('post 9'), findsOneWidget);
    expect(PendingNotificationRoute.debugPending, isNull);
  });

  test('Splash oturumlu feed yolları goHomeThenPending kullanır', () {
    final src = File(
      'lib/features/onboarding/screens/splash_screen.dart',
    ).readAsStringSync();
    expect(
      'goHomeThenPending(GoRouter.of(context), AppRoutes.feed)'
          .allMatches(src)
          .length,
      2,
    );
  });
}
