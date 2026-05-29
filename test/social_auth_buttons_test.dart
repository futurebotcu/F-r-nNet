import 'dart:async';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/models/sign_up_result.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/repositories/auth_repository.dart';
import 'package:firin_defter/features/auth/widgets/social_auth_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// V1.4 — SocialAuthButtons platform/visibility contract.
class _StubRepo implements AuthRepository {
  final _ctrl = StreamController<AuthUser?>.broadcast();
  int googleCalls = 0;
  int appleCalls = 0;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => _ctrl.stream;

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
  }

  @override
  Future<void> signInWithApple() async {
    appleCalls++;
  }

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<void> updateEmail(String email) => throw UnimplementedError();

  @override
  Future<void> resetPasswordForEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> deleteAccount() => throw UnimplementedError();
}

Widget _wrap({
  required AuthRepository? repo,
  required TargetPlatform platform,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: ThemeData(platform: platform),
      home: const Scaffold(
        body: SocialAuthButtons(),
      ),
    ),
  );
}

void main() {
  group('App Store Prep Sprint 1 — SocialAuthButtons iOS gizleme', () {
    testWidgets(
        'iOS: kHideSocialLoginOnIos → Google ve Apple tümüyle gizli',
        (tester) async {
      await tester.pumpWidget(
        _wrap(repo: _StubRepo(), platform: TargetPlatform.iOS),
      );
      // Guideline 4.8 + incomplete-feature riski: iOS'ta hiçbir sosyal login
      // butonu render edilmez (yalnız email/şifre + guest caller'da kalır).
      expect(find.text(AppStrings.authContinueWithGoogle), findsNothing);
      expect(find.text(AppStrings.authContinueWithApple), findsNothing);
      expect(find.byKey(const ValueKey('social_btn_google')), findsNothing);
      expect(find.byKey(const ValueKey('social_btn_apple')), findsNothing);
      expect(find.text(AppStrings.authAppleComingSoonBadge), findsNothing);
      expect(find.text(AppStrings.authSocialDivider), findsNothing);
      // Hiç FilledButton çizilmez → widget SizedBox.shrink döner.
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('iOS: kHideSocialLoginOnIos flag açık (regresyon kilidi)',
        (tester) async {
      expect(kHideSocialLoginOnIos, isTrue,
          reason:
              'Apple Sign-In aktive edilene kadar iOS sosyal login gizli kalmalı.');
    });
  });

  group('SocialAuthButtons — Android davranışı korunur', () {
    testWidgets('Android: yalnız Google görünür, Apple gizli', (tester) async {
      await tester.pumpWidget(
        _wrap(repo: _StubRepo(), platform: TargetPlatform.android),
      );
      expect(find.text(AppStrings.authContinueWithGoogle), findsOneWidget);
      expect(find.text(AppStrings.authContinueWithApple), findsNothing);
    });

    testWidgets('Supabase off (repo null, Android) → Google butonu disabled',
        (tester) async {
      await tester.pumpWidget(
        _wrap(repo: null, platform: TargetPlatform.android),
      );
      final google = tester.widget<FilledButton>(
        find.byKey(const ValueKey('social_btn_google')),
      );
      expect(google.onPressed, isNull,
          reason: 'authRepositoryProvider null iken sosyal butonlar tıklanmaz.');
    });

    testWidgets('Android: Compact=false → "veya" ayraç metni görünür',
        (tester) async {
      await tester.pumpWidget(
        _wrap(repo: _StubRepo(), platform: TargetPlatform.android),
      );
      expect(find.text(AppStrings.authSocialDivider), findsOneWidget);
    });

    testWidgets('Android: "Yakında" badge görünmez (Apple zaten gizli)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(repo: _StubRepo(), platform: TargetPlatform.android),
      );
      expect(find.text(AppStrings.authAppleComingSoonBadge), findsNothing);
    });

    testWidgets(
        'Android: Google butonu tıklanır → signInWithGoogle ÇAĞRILIR',
        (tester) async {
      final repo = _StubRepo();
      await tester.pumpWidget(
        _wrap(repo: repo, platform: TargetPlatform.android),
      );
      expect(repo.googleCalls, 0);

      await tester.tap(find.byKey(const ValueKey('social_btn_google')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.googleCalls, 1,
          reason: 'Google butonu aktif; tıklama signInWithGoogle çağırır.');
    });
  });
}
