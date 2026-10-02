// Final audit P1 — token refresh / app resume aynı uid için YENİ AuthUser
// örneği üretir. Feed zincirindeki provider'lar (follow → following ids →
// repost owners → paged feed; comments/stories/notification repo'ları) tüm
// nesneyi izlerse feed page 1'e düşer ve gereksiz refetch olur. Yalnız uid
// izlenmeli (select).

import 'dart:async';

import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/models/sign_up_result.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/can_write_check_provider.dart';
import 'package:firin_defter/features/auth/repositories/auth_repository.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/notifications/providers/notification_providers.dart';
import 'package:firin_defter/features/profile/providers/follow_providers.dart';
import 'package:firin_defter/features/social/providers/social_providers.dart';
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
  Future<AuthUser> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) => throw UnimplementedError();

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
  late _FakeAuthRepository fakeAuth;
  late ProviderContainer container;

  setUp(() {
    fakeAuth = _FakeAuthRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        canWriteCheckProvider.overrideWithValue(() => true),
      ],
    );
    container.listen<AuthUser?>(currentAuthUserProvider, (_, __) {});
  });

  tearDown(() => container.dispose());

  test('aynı uid re-emisyonu repo instance’larını resetlemez', () async {
    fakeAuth.emit('u1');
    await _tick();
    final before = [
      container.read(followRepositoryProvider),
      container.read(socialCommentsRepositoryProvider),
      container.read(socialStoriesRepositoryProvider),
      container.read(notificationRepositoryProvider),
      container.read(feedRepositoryProvider),
    ];
    fakeAuth.emit('u1'); // token refresh
    await _tick();
    final after = [
      container.read(followRepositoryProvider),
      container.read(socialCommentsRepositoryProvider),
      container.read(socialStoriesRepositoryProvider),
      container.read(notificationRepositoryProvider),
      container.read(feedRepositoryProvider),
    ];
    for (var i = 0; i < before.length; i++) {
      expect(identical(before[i], after[i]), isTrue, reason: 'index $i');
    }
  });

  test('token refresh paged feed state’ini sıfırlamaz (refetch yok)', () async {
    fakeAuth.emit('u1');
    await _tick();
    container.listen(feedPagedNotifierProvider, (_, __) {});
    final first = await container.read(feedPagedNotifierProvider.future);
    expect(first.posts, isNotEmpty);

    fakeAuth.emit('u1');
    await _tick();
    await _tick();
    final state = container.read(feedPagedNotifierProvider);
    expect(state.isLoading, isFalse, reason: 'page 1 yeniden yüklenmemeli');
    expect(identical(state.valueOrNull, first), isTrue);
  });

  test('gerçek kullanıcı değişimi repo’yu yine yeniler', () async {
    fakeAuth.emit('u1');
    await _tick();
    final r1 = container.read(followRepositoryProvider);
    fakeAuth.emit('u2');
    await _tick();
    expect(identical(r1, container.read(followRepositoryProvider)), isFalse);
  });
}
