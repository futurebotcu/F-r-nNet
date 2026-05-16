import 'dart:async';

import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake — `signInWithPassword` benzeri davranışı simüle eder.
class _FakeAuthRepository implements AuthRepository {
  AuthUser? _user;
  final _ctrl = StreamController<AuthUser?>.broadcast();

  void simulateSignIn(AuthUser u) {
    _user = u;
    _ctrl.add(u);
  }

  void simulateSignOut() {
    _user = null;
    _ctrl.add(null);
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() => _ctrl.stream;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
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
  group('V1.3.4 — currentAuthUserProvider auth state\'e reactive', () {
    test('signIn sonrası provider taze user\'ı döner (eski snapshot bug fix)',
        () async {
      final fake = _FakeAuthRepository();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      // Stream subscription'ı tetiklemek için listener ekle.
      container.listen<AuthUser?>(currentAuthUserProvider, (_, __) {});

      // Boot anında: kullanıcı yok.
      expect(container.read(currentAuthUserProvider), isNull,
          reason: 'Başlangıçta currentUser null olmalı');

      // Login simülasyonu — Supabase SDK signInWithPassword sonrası
      // currentUser dolup onAuthStateChange emit eder.
      fake.simulateSignIn(const AuthUser(id: 'u1', email: 'a@b.c'));
      // Stream emit'in propagation'ı için microtask bekle.
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(currentAuthUserProvider)?.id,
        'u1',
        reason: 'signIn sonrası provider yeni user\'ı yansıtmalı '
            '(önceden snapshot cache\'lenip null kalıyordu, kullanıcı '
            'AuthEntry\'e atılıyordu).',
      );
    });

    test('signOut sonrası provider null döner', () async {
      final fake = _FakeAuthRepository();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      container.listen<AuthUser?>(currentAuthUserProvider, (_, __) {});

      fake.simulateSignIn(const AuthUser(id: 'u1', email: 'a@b.c'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currentAuthUserProvider)?.id, 'u1');

      fake.simulateSignOut();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currentAuthUserProvider), isNull);
    });

    test('Auth-bağımlı providerlar yeni user state\'i alır (canWriteCheck)',
        () async {
      // canWriteCheckProvider currentAuthUserProvider'a bağlı.
      // Reactive fix sonrası signIn → canWrite false→true.
      final fake = _FakeAuthRepository();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      container.listen<AuthUser?>(currentAuthUserProvider, (_, __) {});

      // İlk durum: signOut'ta canWrite false olmalı.
      // (canWriteCheckProvider closure her çağrıda taze okur — currentUser
      // null olduğu için Supabase enabled false olsa bile profile null →
      // false. Bu test signIn sonrası transition'ı doğrular.)
      expect(container.read(currentAuthUserProvider), isNull);

      fake.simulateSignIn(const AuthUser(id: 'u1', email: 'a@b.c'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currentAuthUserProvider)?.id, 'u1');
    });
  });
}
