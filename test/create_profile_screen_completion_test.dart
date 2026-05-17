import 'dart:async';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/models/sign_up_result.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/repositories/auth_repository.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/profile/screens/create_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// V1.4 — CreateProfileScreen mode contract.
///
/// Üç senaryo:
///   1) authUser != null + profileController null  → completion mode (Google/OAuth
///      sonrası; profile henüz hydrate olmamış).
///   2) authUser == null + profileController null  → signup mode (yeni e-posta).
///   3) authUser != null + profileController hydrate sonra → form pre-fill.
class _StubAuthRepo implements AuthRepository {
  _StubAuthRepo({this.user});
  final AuthUser? user;
  final _ctrl = StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => user;

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
  Future<void> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signInWithApple() => throw UnimplementedError();

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

/// Test-only ProfileController — override profileControllerProvider üzerine
/// otursun diye gerçek `ProfileController` subclass'ı. `_loadFor` test'lerde
/// `profileRepositoryProvider == null` (AppConfig.supabaseEnabled false) yolu
/// ile no-op'a düşer; state'i manuel `emit` ile kontrol ederiz.
class _StubProfileController extends ProfileController {
  _StubProfileController(super.ref, [BakeryProfile? initial]) {
    if (initial != null) state = initial;
  }
  void emit(BakeryProfile? p) => state = p;
}

Widget _wrap({
  required AuthRepository? authRepo,
  BakeryProfile? initialProfile,
  void Function(_StubProfileController)? onCtrl,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      profileControllerProvider.overrideWith((ref) {
        final c = _StubProfileController(ref, initialProfile);
        onCtrl?.call(c);
        return c;
      }),
    ],
    child: const MaterialApp(
      home: CreateProfileScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('V1.4 — CreateProfileScreen mode contract', () {
    testWidgets(
        'authUser != null + profile null → completion mode (şifre + yasal kabul gizli)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          authRepo: _StubAuthRepo(
            user: const AuthUser(id: 'u1', email: 'fatih@gmail.com'),
          ),
        ),
      );
      await tester.pump();

      // Başlık completion mode'a göre değişir.
      expect(find.text('Profili Tamamla'), findsOneWidget,
          reason:
              'Auth user var iken başlık "Profili Tamamla" (signup değil) olmalı.');
      expect(find.text(AppStrings.createProfile), findsNothing);

      // Şifre alanı GİZLİ (signup-only).
      expect(find.text(AppStrings.password), findsNothing,
          reason: 'Completion mode-da şifre alanı render edilmez.');

      // Yasal kabul checkbox GİZLİ.
      expect(find.byType(Checkbox, skipOffstage: false), findsNothing,
          reason: 'Completion mode-da yasal kabul gösterilmez.');

      // Email Google'dan pre-fill — disabled (read-only) gösterilir.
      expect(find.text('fatih@gmail.com'), findsOneWidget);
    });

    testWidgets(
        'authUser == null + profile null → signup mode (şifre + yasal kabul görünür)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(authRepo: _StubAuthRepo()),
      );
      await tester.pump();

      expect(find.text(AppStrings.createProfile), findsOneWidget,
          reason:
              'Auth user yok + profile yok → klasik "Profil Oluştur" signup.');
      expect(find.text('Profili Tamamla'), findsNothing);

      expect(find.text(AppStrings.password), findsOneWidget,
          reason: 'Signup mode-da şifre alanı görünür.');
      // Yasal kabul checkbox ListView'in altında olabilir; offstage dahil ara.
      expect(find.byType(Checkbox, skipOffstage: false), findsOneWidget,
          reason: 'Signup mode-da yasal kabul checkbox render edilir.');
    });

    testWidgets(
        'authUser == null + profile hydrate → completion mode (legacy "incomplete profile" yolu)',
        (tester) async {
      // Eski signed-in fakat profil eksik akış — sadece existing != null.
      await tester.pumpWidget(
        _wrap(
          authRepo: _StubAuthRepo(),
          initialProfile: const BakeryProfile(
            displayName: 'Hasan Usta',
            accountType: AccountType.commercial,
            city: 'Konya',
            roleBadge: 'Usta Fırıncı',
            email: 'hasan@firinnet.test',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Profili Tamamla'), findsOneWidget);
      expect(find.text(AppStrings.password), findsNothing);
      expect(find.text(AppStrings.legalTermsTitle), findsNothing);
      // Pre-fill kanıtı
      expect(find.text('Hasan Usta'), findsOneWidget);
      expect(find.text('Konya'), findsOneWidget);
    });

    testWidgets(
        'Google completion: profileController initState sonrası hydrate → form pre-fill',
        (tester) async {
      late _StubProfileController ctrl;
      await tester.pumpWidget(
        _wrap(
          authRepo: _StubAuthRepo(
            user: const AuthUser(id: 'u1', email: 'fatih@gmail.com'),
          ),
          onCtrl: (c) => ctrl = c,
        ),
      );
      await tester.pump();

      // İlk render: completion mode (authUser var) + email pre-fill (Google'dan).
      expect(find.text('Profili Tamamla'), findsOneWidget);
      expect(find.text('fatih@gmail.com'), findsOneWidget);
      // displayName / city henüz yok.
      expect(find.text('Fatih Kartal'), findsNothing);

      // ProfileController async hydrate olur (handle_new_user trigger sonrası).
      ctrl.emit(const BakeryProfile(
        displayName: 'Fatih Kartal',
        accountType: AccountType.individual,
        city: '', // city eksik (Google vermez); kullanıcı doldurur
        roleBadge: '', // profession_badge eksik
        email: 'fatih@gmail.com',
      ));
      await tester.pump();

      // Form pre-fill çalıştı: displayName Google metadata'sından geldi.
      expect(find.text('Fatih Kartal'), findsOneWidget);
      // Hâlâ completion mode — şifre/yasal kabul gizli.
      expect(find.text(AppStrings.password), findsNothing);
      expect(find.text(AppStrings.legalTermsTitle), findsNothing);
    });

    testWidgets(
        'Hydration user input ezmez (kullanıcı yazdıktan sonra emit gelirse mevcut metin korunur)',
        (tester) async {
      late _StubProfileController ctrl;
      await tester.pumpWidget(
        _wrap(
          authRepo: _StubAuthRepo(
            user: const AuthUser(id: 'u1', email: 'fatih@gmail.com'),
          ),
          onCtrl: (c) => ctrl = c,
        ),
      );
      await tester.pump();

      // Hydrate (ilk transition) → name Google'dan pre-fill.
      ctrl.emit(const BakeryProfile(
        displayName: 'Fatih Kartal',
        accountType: AccountType.individual,
        city: '',
        roleBadge: '',
        email: 'fatih@gmail.com',
      ));
      await tester.pump();
      expect(find.text('Fatih Kartal'), findsOneWidget);

      // Kullanıcı name'i değiştirir.
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Fatih Kartal'), 'Hasan Usta');
      await tester.pump();
      expect(find.text('Hasan Usta'), findsOneWidget);

      // İkinci profile emission gelir (örneğin başka bir profil güncellemesi).
      ctrl.emit(const BakeryProfile(
        displayName: 'Başka İsim',
        accountType: AccountType.individual,
        city: 'Manisa',
        roleBadge: '',
        email: 'fatih@gmail.com',
      ));
      await tester.pump();

      // _profileHydrated = true olduğundan ikinci emission alanları EZMEZ.
      expect(find.text('Hasan Usta'), findsOneWidget,
          reason: 'İkinci hydrate user input\'unu ezmemeli.');
      expect(find.text('Başka İsim'), findsNothing);
    });
  });
}
