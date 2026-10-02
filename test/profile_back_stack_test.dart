// Final audit P1 — /profile → /u/<id> yönlendirmesi kök yığını ezmemeli:
// Panel'den gelinmişse Android geri Panel'e döner (uygulamadan çıkmaz).

import 'package:firin_defter/app/router/app_router.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/profile/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: AppRoutes.panel,
      builder: (context, _) => Scaffold(
        body: TextButton(
          onPressed: () => context.push(AppRoutes.profile),
          child: const Text('panel'),
        ),
      ),
    ),
    GoRoute(path: AppRoutes.profile, builder: (_, __) => const ProfileScreen()),
    GoRoute(
      path: '${AppRoutes.userPublicProfile}/:id',
      builder: (_, s) => Text('user ${s.pathParameters['id']}'),
    ),
  ],
);

Widget _app(GoRouter router) => ProviderScope(
  overrides: [
    currentAuthUserProvider.overrideWith(
      (_) => const AuthUser(id: 'u1', email: 'u@t.local'),
    ),
  ],
  child: MaterialApp.router(routerConfig: router),
);

void main() {
  testWidgets('Panel → Profil → geri = Panel', (tester) async {
    final router = _router(AppRoutes.panel);
    await tester.pumpWidget(_app(router));
    await tester.tap(find.text('panel'));
    await tester.pumpAndSettle();
    expect(find.text('user u1'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('panel'), findsOneWidget);
  });

  testWidgets('Doğrudan /profile (tek sayfa) → Panel altta, geri = Panel', (
    tester,
  ) async {
    final router = _router(AppRoutes.profile);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    expect(find.text('user u1'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('panel'), findsOneWidget);
  });
}
