// FırınNet P0 — Group Chat Composer Hidden For Real Group Member.
//
// Root cause: `socialGroupRepositoryProvider`, `currentAuthUserProvider`'ın
// AuthUser OBJESİNİ izliyordu. AuthUser'da ==/hashCode override'ı yok; auth
// stream'in her emisyonu (token refresh, app resume, media-path invalidate)
// aynı kullanıcı için yeni instance üretir → repo yeniden yaratılır →
// içindeki sync `_joinedCache` boşalır → grup detayı açıkken DB'de üye olan
// kullanıcının isJoined'ı false'a düşer → composer yerine "Sohbete katıl".
// Buton kurtarmıyordu da: joinGroup duplicate-key (23505) branch'i
// alreadyJoined dönerken cache'i onarmıyor, notify etmiyordu.
//
// Fix:
//   A) Provider yalnız userId izler (select) → aynı id'li yeni instance
//      repo'yu resetlemez; gerçek login/logout yine yeniler.
//   C) 23505 branch'i `_joinedCache.add(id) + _notify()` ile UI'yı
//      joined hâle getirir (source-contract testi).

import 'dart:async';
import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/models/sign_up_result.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/can_write_check_provider.dart';
import 'package:firin_defter/features/auth/repositories/auth_repository.dart';
import 'package:firin_defter/features/social_groups/models/group_category.dart';
import 'package:firin_defter/features/social_groups/providers/social_group_providers.dart';
import 'package:firin_defter/features/social_groups/repositories/local_social_group_repository.dart';
import 'package:firin_defter/features/social_groups/screens/group_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  AuthUser? _user;
  final _ctrl = StreamController<AuthUser?>.broadcast();

  /// Aynı id ile bile çağrılsa YENİ AuthUser instance'ı emit eder —
  /// token refresh / app resume davranışının birebir simülasyonu.
  void emit(String? id) {
    _user = id == null ? null : AuthUser(id: id, email: '$id@firin.net');
    _ctrl.add(_user);
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

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  group('P0 — repo instance stabilitesi (token refresh membership kaybı)',
      () {
    late _FakeAuthRepository fakeAuth;
    late ProviderContainer container;

    setUp(() {
      fakeAuth = _FakeAuthRepository();
      container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        canWriteCheckProvider.overrideWithValue(() => true),
      ]);
      container.listen<AuthUser?>(currentAuthUserProvider, (_, __) {});
    });

    tearDown(() => container.dispose());

    test('aynı userId yeni AuthUser instance → repo AYNI instance kalır',
        () async {
      fakeAuth.emit('u1');
      await _tick();
      final repo1 = container.read(socialGroupRepositoryProvider);

      // Token refresh / app resume: aynı id, yeni AuthUser objesi.
      fakeAuth.emit('u1');
      await _tick();
      final repo2 = container.read(socialGroupRepositoryProvider);

      expect(
        identical(repo1, repo2),
        isTrue,
        reason: 'Aynı kullanıcı için repo (ve joined cache) resetlenmemeli; '
            'grup detayı açıkken composer "Sohbete katıl"a dönüyordu.',
      );
    });

    test('üyelik state aynı-id re-emisyonda korunur (isJoinedProvider)',
        () async {
      fakeAuth.emit('u1');
      await _tick();
      final repo = container.read(socialGroupRepositoryProvider);
      final groups = await repo.listGroups();
      final gid = groups.first.id;
      await repo.joinGroup(gid);
      expect(container.read(isJoinedProvider(gid)), isTrue);

      // Token refresh simülasyonu — üyelik kaybolmamalı.
      fakeAuth.emit('u1');
      await _tick();
      expect(
        container.read(isJoinedProvider(gid)),
        isTrue,
        reason: 'Token refresh/app resume sonrası joined state false\'a '
            'düşmemeli (composer kaybolmamalı).',
      );
    });

    test('FARKLI userId → repo yenilenir (login/logout davranışı korunur)',
        () async {
      fakeAuth.emit('u1');
      await _tick();
      final repo1 = container.read(socialGroupRepositoryProvider);

      fakeAuth.emit('u2');
      await _tick();
      final repo2 = container.read(socialGroupRepositoryProvider);

      expect(identical(repo1, repo2), isFalse,
          reason: 'Gerçek kullanıcı değişiminde repo taze olmalı');

      fakeAuth.emit(null);
      await _tick();
      final repo3 = container.read(socialGroupRepositoryProvider);
      expect(identical(repo2, repo3), isFalse,
          reason: 'Logout\'ta repo yenilenmeli (guest local repo)');
    });
  });

  group('P0 — footer davranışı: üye composer görür, non-member CTA görür',
      () {
    Widget wrap({
      required LocalSocialGroupRepository repo,
      required String uid,
      required Widget child,
    }) {
      return ProviderScope(
        overrides: [
          socialGroupRepositoryProvider.overrideWithValue(repo),
          canWriteCheckProvider.overrideWithValue(() => true),
          currentAuthUserProvider.overrideWith(
            (ref) => AuthUser(id: uid, email: null),
          ),
        ],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('üye (owner değil): composer görünür, "Sohbete katıl" yok',
        (tester) async {
      final repo = LocalSocialGroupRepository(
        seed: true,
        currentUserId: 'member_x',
      );
      // Seed grupların owner'ı member_x değil → join ile sadece üye olur.
      final gid = (await repo.listGroups()).first.id;
      await repo.joinGroup(gid);

      await tester.pumpWidget(wrap(
        repo: repo,
        uid: 'member_x',
        child: GroupDetailScreen(groupId: gid),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget,
          reason: 'DB üyesi kullanıcı composer görmeli');
      expect(find.text(AppStrings.groupJoinNowCta), findsNothing,
          reason: 'Üye kullanıcıya "Sohbete katıl" gösterilmemeli');
    });

    testWidgets('non-member public grup: "Sohbete katıl" görünür, composer yok',
        (tester) async {
      final repo = LocalSocialGroupRepository(
        seed: true,
        currentUserId: 'visitor_y',
      );
      final gid = (await repo.listGroups()).first.id;

      await tester.pumpWidget(wrap(
        repo: repo,
        uid: 'visitor_y',
        child: GroupDetailScreen(groupId: gid),
      ));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.groupJoinNowCta), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('P0 — source contracts', () {
    test('repo provider AuthUser objesini değil userId\'yi izler (select)',
        () {
      final src = File(
        'lib/features/social_groups/providers/social_group_providers.dart',
      ).readAsStringSync();
      expect(
        src.contains('currentAuthUserProvider.select((u) => u?.id)'),
        isTrue,
        reason: 'Token refresh emisyonları repo/cache\'i resetlememeli',
      );
    });

    test('joinGroup 23505 (zaten üye) branch cache onarır + notify eder', () {
      final src = File(
        'lib/features/social_groups/repositories/'
        'supabase_social_group_repository.dart',
      ).readAsStringSync();
      final branch = RegExp(
        r"if \(e\.code == '23505'\) \{[^}]*_joinedCache\.add\(id\);[^}]*_notify\(\);[^}]*alreadyJoined;",
        dotAll: true,
      );
      expect(
        branch.hasMatch(src),
        isTrue,
        reason: 'DB "zaten üye" dediğinde UI joined hâle gelmeli; '
            '"Sohbete katıl" ekranda kalmamalı',
      );
    });
  });
}
