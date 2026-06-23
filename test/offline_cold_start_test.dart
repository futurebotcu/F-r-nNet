// PR-OFFLINE-1 — internet yokken cold-start app açılmalı; profil fetch hatası
// fatal/blank/sonsuz-spinner/logout YAPMAMALI.

import 'dart:async';
import 'dart:io';

import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/models/sign_up_result.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/repositories/auth_repository.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/profile/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

/// Oturum AÇIK kullanıcı (cold-start'ta session restore edilmiş gibi).
class _LoggedInAuthRepo implements AuthRepository {
  final _ctrl = StreamController<AuthUser?>.broadcast();
  @override
  AuthUser? get currentUser => const AuthUser(id: 'u1', email: 'u@e.com');
  @override
  Stream<AuthUser?> authStateChanges() => _ctrl.stream;
  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
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

/// İnternet yok → fetchProfile her zaman atar.
class _OfflineProfileRepo implements ProfileRepository {
  int fetchCalls = 0;
  @override
  Future<BakeryProfile?> fetchProfile(String userId) async {
    fetchCalls++;
    throw Exception('SocketException: Network is unreachable (offline)');
  }

  @override
  Future<BakeryProfile> updateProfile({
    required String userId,
    required BakeryProfile profile,
  }) =>
      throw UnimplementedError();
}

void main() {
  group('Splash offline guard (kaynak sözleşmesi)', () {
    final src = _read('lib/features/onboarding/screens/splash_screen.dart');

    test('fetchProfile timeout + try/catch ile sarılı', () {
      expect(src.contains('.fetchProfile('), isTrue);
      expect(src.contains('.timeout('), isTrue);
      expect(src.contains('catch (e)'), isTrue);
      // Offline catch yorumu → bilinçli offline davranışı.
      expect(src.contains('offline?'), isTrue);
    });

    test('offline\'da logout / session clear YOK', () {
      // Splash hiçbir yerde signOut çağırmaz (offline'da oturum kapanmamalı).
      expect(src.contains('signOut'), isFalse);
    });
  });

  group('ProfileController — offline fetch hatası fatal DEĞİL', () {
    test('fetchProfile throw → crash yok, state korunur (null), logout yok',
        () async {
      final offline = _OfflineProfileRepo();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(_LoggedInAuthRepo()),
        profileRepositoryProvider.overrideWithValue(offline),
      ]);
      addTearDown(container.dispose);

      // Controller construct → _loadFor('u1') → fetchProfile throw → _loadFor
      // try/catch yutar (state null kalır). Senkron throw OLMAMALI.
      expect(
        () => container.read(profileControllerProvider.notifier),
        returnsNormally,
      );
      // async _loadFor tamamlansın
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(offline.fetchCalls, greaterThanOrEqualTo(1));
      // State güvenli (null) — boş profile DÜŞÜRMEDİ ama crash de etmedi.
      expect(container.read(profileControllerProvider), isNull);
    });
  });

  group('main bootstrap — init guard (offline blank screen yok)', () {
    final main = _read('lib/main.dart');
    test('Firebase/Crashlytics guard\'lı servisler + runApp her durumda', () {
      // Bu servisler kendi içinde try/catch guard'lı (config/ağ yoksa no-op);
      // main runApp\'e her zaman ulaşır.
      expect(main.contains('PushNotificationService.initFirebase()'), isTrue);
      expect(main.contains('CrashReportingService.init()'), isTrue);
      expect(main.contains('runApp('), isTrue);
    });
  });
}
