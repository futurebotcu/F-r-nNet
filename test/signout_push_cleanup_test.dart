// Final audit P0-3 — yarım kalmış profil oturumundan çıkışta push token
// signOut'tan ÖNCE pasifleştirilmeli; push temizliği hata verse/asılı kalsa
// bile çıkış kilitlenmemeli.

import 'dart:async';
import 'dart:io';

import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/models/sign_up_result.dart';
import 'package:firin_defter/features/auth/repositories/auth_repository.dart';
import 'package:firin_defter/features/auth/services/auth_actions.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAuth implements AuthRepository {
  _RecordingAuth(this.log, {this.throwOnSignOut = false});
  final List<String> log;
  final bool throwOnSignOut;

  @override
  Future<void> signOut() async {
    log.add('signOut');
    if (throwOnSignOut) throw Exception('offline');
  }

  @override
  AuthUser? get currentUser => const AuthUser(id: 'u1', email: 'u@t.local');
  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();
  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) => throw UnimplementedError();
  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<void> signInWithApple() => throw UnimplementedError();
  @override
  Future<void> updateEmail(String email) => throw UnimplementedError();
  @override
  Future<void> resetPasswordForEmail(String email) =>
      throw UnimplementedError();
  @override
  Future<void> deleteAccount() => throw UnimplementedError();
}

void main() {
  test('unregister signOut öncesi çağrılır', () async {
    final log = <String>[];
    await signOutWithPushCleanup(
      _RecordingAuth(log),
      unregisterPush: () async => log.add('unregister'),
    );
    expect(log, ['unregister', 'signOut']);
  });

  test('unregister hata verirse signOut yine çalışır', () async {
    final log = <String>[];
    await signOutWithPushCleanup(
      _RecordingAuth(log),
      unregisterPush: () async => throw Exception('rpc fail'),
    );
    expect(log, ['signOut']);
  });

  test('unregister asılı kalırsa timeout sonrası signOut çalışır', () async {
    final log = <String>[];
    await signOutWithPushCleanup(
      _RecordingAuth(log),
      unregisterPush: () => Completer<void>().future,
      pushTimeout: const Duration(milliseconds: 20),
    );
    expect(log, ['signOut']);
  });

  test('signOut hatası yutulur (çağıran local state temizleyebilir)', () async {
    final log = <String>[];
    await signOutWithPushCleanup(
      _RecordingAuth(log, throwOnSignOut: true),
      unregisterPush: () async => log.add('unregister'),
    );
    expect(log, ['unregister', 'signOut']);
  });

  test('CreateProfile incomplete-session çıkışı ortak yardımcıyı kullanır', () {
    final src = File(
      'lib/features/profile/screens/create_profile_screen.dart',
    ).readAsStringSync();
    expect(src, contains('await signOutWithPushCleanup(auth!)'));
    expect(src, isNot(contains('await auth!.signOut()')));
    final actions = File(
      'lib/features/auth/services/auth_actions.dart',
    ).readAsStringSync();
    expect(actions, contains('await signOutWithPushCleanup(auth)'));
  });
}
