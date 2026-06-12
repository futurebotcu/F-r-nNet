// Faz 2 UI Pass 3 — 3 sayfalık intro onboarding render + akış + seen-flag.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/app_primary_button.dart';
import 'package:firin_defter/features/onboarding/screens/onboarding_intro_screen.dart';
import 'package:firin_defter/features/onboarding/services/onboarding_seen_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _read(String p) => File(p).readAsStringSync();

GoRouter _router() => GoRouter(
      initialLocation: '/intro',
      routes: [
        GoRoute(
          path: '/intro',
          builder: (_, __) => const OnboardingIntroScreen(),
        ),
        GoRoute(
          path: '/auth',
          builder: (_, __) => const Scaffold(body: Text('AUTH_REACHED')),
        ),
      ],
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    OnboardingSeenStorage.resetForTest();
  });

  testWidgets('İlk sayfa Topluluk değer mesajını + Atla/Devam gösterir',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: _router()),
    ));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.introP1Title), findsOneWidget);
    expect(find.text(AppStrings.introP1Body), findsOneWidget);
    expect(find.text(AppStrings.introSkip), findsOneWidget);
    // AppPrimaryButton etiketi (uppercase render eder) — widget prop'undan.
    final btn = tester.widget<AppPrimaryButton>(find.byType(AppPrimaryButton));
    expect(btn.label, AppStrings.introNext);
  });

  testWidgets('Devam ile son sayfaya gelince Başla görünür + /auth\'a gider',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: _router()),
    ));
    await tester.pumpAndSettle();

    // 2 kez Devam → 3. sayfa (primary button widget'ı).
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.introP3Title), findsOneWidget);
    final btn = tester.widget<AppPrimaryButton>(find.byType(AppPrimaryButton));
    expect(btn.label, AppStrings.introStart);

    // Başla → seen flag + /auth.
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();
    expect(find.text('AUTH_REACHED'), findsOneWidget);
    expect(await OnboardingSeenStorage.instance.read(), isTrue);
  });

  testWidgets('Atla → seen flag set + /auth', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: _router()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.introSkip));
    await tester.pumpAndSettle();
    expect(find.text('AUTH_REACHED'), findsOneWidget);
    expect(await OnboardingSeenStorage.instance.read(), isTrue);
  });

  test('OnboardingSeenStorage read/markSeen (fake prefs)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    OnboardingSeenStorage.resetForTest();
    expect(await OnboardingSeenStorage.instance.read(), isFalse);
    await OnboardingSeenStorage.instance.markSeen();
    expect(await OnboardingSeenStorage.instance.read(), isTrue);
  });

  test('Splash ilk açılışta /intro gate eder (kaynak sözleşmesi)', () {
    final src =
        _read('lib/features/onboarding/screens/splash_screen.dart');
    // guest/login akışı korunur; yalnız auth kararı intro'dan geçer.
    expect(src.contains('_goAuthOrIntro'), isTrue);
    expect(src.contains('OnboardingSeenStorage'), isTrue);
    expect(src.contains('AppRoutes.intro'), isTrue);
  });
}
