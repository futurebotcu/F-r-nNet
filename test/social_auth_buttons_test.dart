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
    // Test: yalnız çağrılabilir olmalı; gerçek OAuth tetiklenmez.
  }

  @override
  Future<void> signInWithApple() async {
    // Test: yalnız çağrılabilir olmalı; gerçek OAuth tetiklenmez.
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
  group('V1.4 — SocialAuthButtons', () {
    testWidgets('iOS: Google ve Apple butonu birlikte görünür',
        (tester) async {
      await tester.pumpWidget(
        _wrap(repo: _StubRepo(), platform: TargetPlatform.iOS),
      );
      expect(find.text(AppStrings.authContinueWithGoogle), findsOneWidget);
      expect(find.text(AppStrings.authContinueWithApple), findsOneWidget);
    });

    testWidgets('Android: yalnız Google görünür, Apple gizli', (tester) async {
      await tester.pumpWidget(
        _wrap(repo: _StubRepo(), platform: TargetPlatform.android),
      );
      expect(find.text(AppStrings.authContinueWithGoogle), findsOneWidget);
      expect(find.text(AppStrings.authContinueWithApple), findsNothing);
    });

    testWidgets('Supabase off (repo null) → Google butonu disabled',
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

    testWidgets('iOS + Supabase aktif → Google ve Apple butonu enabled',
        (tester) async {
      await tester.pumpWidget(
        _wrap(repo: _StubRepo(), platform: TargetPlatform.iOS),
      );
      final google = tester.widget<FilledButton>(
        find.byKey(const ValueKey('social_btn_google')),
      );
      final apple = tester.widget<FilledButton>(
        find.byKey(const ValueKey('social_btn_apple')),
      );
      expect(google.onPressed, isNotNull);
      expect(apple.onPressed, isNotNull);
    });

    testWidgets('Compact=false → "veya" ayraç metni görünür', (tester) async {
      await tester.pumpWidget(
        _wrap(repo: _StubRepo(), platform: TargetPlatform.android),
      );
      expect(find.text(AppStrings.authSocialDivider), findsOneWidget);
    });
  });
}
