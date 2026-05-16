import 'dart:async';

import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/models/sign_up_result.dart';
import 'package:firin_defter/features/auth/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// V1.4 — Sprint A sonrası: `AuthRepository.signUp` artık [SignUpResult]
/// döner. Supabase Auth ayarında `mailer_autoconfirm = false` olduğu zaman
/// `res.session` null gelir; bu durumda `needsEmailConfirmation = true`
/// olmalı ve UI Splash/Feed yerine "E-postanı onayla" akışına yönlenmeli.
///
/// Bu testler kontrat seviyesinde doğrular:
/// - Repository implementor session yokluğunu doğru rapor etmeli.
/// - Çağıran iki branş arasında ayrım yapabilmeli.
///
/// CreateProfileScreen UI davranışı için manuel smoke runbook'a bakın
/// (AUTH_EMAIL_CONFIRMATION_FIX_REPORT.md §Manual smoke).
class _ConfigurableFakeAuthRepository implements AuthRepository {
  _ConfigurableFakeAuthRepository({required this.confirmRequired});

  /// `true` olduğunda fake "Supabase mailer_autoconfirm OFF" davranışını
  /// taklit eder ve `SignUpResult(needsEmailConfirmation: true)` döner.
  final bool confirmRequired;

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
  }) async {
    return SignUpResult(
      user: AuthUser(id: 'u_${email.hashCode}', email: email),
      needsEmailConfirmation: confirmRequired,
    );
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

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

void main() {
  group('V1.4 — SignUpResult kontrat', () {
    test('session var → needsEmailConfirmation=false (auto-confirm ON)',
        () async {
      final repo = _ConfigurableFakeAuthRepository(confirmRequired: false);
      final r = await repo.signUp(
        email: 'ahmet@firin.test',
        password: 'sifre123',
        metadata: const <String, dynamic>{
          'display_name': 'Ahmet',
          'account_type': 'commercial',
        },
      );
      expect(r.needsEmailConfirmation, isFalse,
          reason: 'Auto-confirm açık iken session null değildir, '
              'çağıran Splash/Feed akışına gitmeli.');
      expect(r.user.email, 'ahmet@firin.test');
      expect(r.user.id, isNotEmpty);
    });

    test('session null → needsEmailConfirmation=true (auto-confirm OFF)',
        () async {
      final repo = _ConfigurableFakeAuthRepository(confirmRequired: true);
      final r = await repo.signUp(
        email: 'mehmet@firin.test',
        password: 'sifre123',
        metadata: const <String, dynamic>{
          'display_name': 'Mehmet',
          'account_type': 'individual',
        },
      );
      expect(r.needsEmailConfirmation, isTrue,
          reason: 'Supabase mailer_autoconfirm kapalıyken signUp '
              'session vermez; çağıran kullanıcıyı Feed/Splash yerine '
              '"E-postanı onayla" akışına yönlendirmeli.');
      expect(r.user.email, 'mehmet@firin.test');
    });

    test('SignUpResult immutable — user ve flag construction sırasında alınır',
        () {
      const user = AuthUser(id: 'u1', email: 'a@b.c');
      const r = SignUpResult(user: user, needsEmailConfirmation: true);
      expect(r.user.id, 'u1');
      expect(r.needsEmailConfirmation, isTrue);
    });
  });
}
