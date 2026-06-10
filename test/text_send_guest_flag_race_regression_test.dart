// FırınNet P0 — Email login user "hesap aç / hesap gerekli" regresyonu.
//
// Root cause (text send): GuestModeNotifier constructor'ı `_load()`'u
// unawaited başlatır. Login başarısında çağrılan `setGuest(false)`
// (login_screen.dart:87) provider'a İLK erişimse sıralama deterministik
// olarak bozulur:
//   1. ctor → _load() → `await _storage.read()` askıya alınır (stale TRUE
//      okuyacak — storage'da eski "Kayıtsız Devam Et" bayrağı var).
//   2. setGuest(false) → state=false (sync) → write(false) askıya alınır.
//   3. microtask: _load devam eder → state = TRUE  ← login'in false'unu EZER.
//   4. write(false) → storage false olur ama state TRUE kalır.
// Sonuç: oturum açık kullanıcıda guestModeProvider tüm session boyunca true
// kalır; AuthRequiredGuard.canWrite ilk satırda (isGuest) keser → generic +
// group TEXT send (ve tüm yazımlar) AuthRequiredSheet'e düşer. Splash'ın
// defensive guard'ı storage'ı okuduğu (false) için durumu düzeltemez.
//
// Fix: setGuest çağrıldıysa _load'un geç gelen snapshot'ı state'i ezmez.

import 'dart:async';

import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/models/sign_up_result.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/guest_mode_provider.dart';
import 'package:firin_defter/features/auth/repositories/auth_repository.dart';
import 'package:firin_defter/features/auth/services/auth_required_guard.dart';
import 'package:firin_defter/features/auth/services/guest_mode_storage.dart';
import 'package:firin_defter/features/messaging/repositories/guarded_messaging_repository.dart';
import 'package:firin_defter/features/messaging/repositories/local_messaging_repository.dart';
import 'package:firin_defter/features/social_groups/models/group_category.dart';
import 'package:firin_defter/features/social_groups/models/group_message.dart';
import 'package:firin_defter/features/social_groups/repositories/guarded_social_group_repository.dart';
import 'package:firin_defter/features/social_groups/repositories/local_social_group_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  AuthUser? _user;
  final _ctrl = StreamController<AuthUser?>.broadcast();

  void simulateSignIn(AuthUser u) {
    _user = u;
    _ctrl.add(u);
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

/// Async storage round-trip'lerinin (prefs.getInstance + _load devamı)
/// tamamlanması için event queue'yu boşaltır.
Future<void> _flushAsync() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0 — stale guest flag + login: setGuest(false) kalıcı olmalı', () {
    setUp(() {
      // Kullanıcı geçmişte "Kayıtsız Devam Et" seçmiş → storage'da bayrak var.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'firinnet.guest_mode': true,
      });
      GuestModeStorage.resetForTest();
    });

    test(
        'login_screen pattern: provider\'a İLK erişim setGuest(false) ise '
        '_load stale TRUE ile ezemez', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // login_screen.dart:87 — signIn başarısı sonrası ilk provider erişimi.
      await container.read(guestModeProvider.notifier).setGuest(false);
      await _flushAsync();

      expect(
        container.read(guestModeProvider),
        isFalse,
        reason: 'E-posta ile giriş yapan kullanıcı guest sayılmamalı; '
            '_load()\'un stale storage snapshot\'ı login\'in setGuest(false) '
            'kararını ezmemeli (text send "hesap gerekli"ye düşüyordu).',
      );

      // Storage da temiz olmalı (sonraki cold start'ı kirletmesin).
      expect(await GuestModeStorage.instance.read(), isFalse);
    });

    test(
        'splash defensive guard pattern: user != null + stale guest → '
        'setGuest(false) kalıcı', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // splash_screen.dart:89 — aynı çağrı, ilk erişim splash'ta olursa.
      await container.read(guestModeProvider.notifier).setGuest(false);
      await _flushAsync();

      expect(container.read(guestModeProvider), isFalse);
    });

    test(
        'fix sonrası zincir: canWrite true + generic/group text send '
        'guard\'a takılmaz', () async {
      final fakeAuth = _FakeAuthRepository();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
      ]);
      addTearDown(container.dispose);
      container.listen<AuthUser?>(currentAuthUserProvider, (_, __) {});

      // E-posta/şifre girişi: SDK currentUser doldurur + stream emit eder.
      fakeAuth
          .simulateSignIn(const AuthUser(id: 'u1', email: 'user@firin.net'));
      await container.read(guestModeProvider.notifier).setGuest(false);
      await _flushAsync();

      // Guard'ın prod (Supabase enabled) kararı — app'in send anında
      // okuduğu değerlerle birebir.
      bool canWriteNow() => AuthRequiredGuard.canWrite(
            isGuest: container.read(guestModeProvider),
            supabaseEnabled: true,
            currentUser: container.read(currentAuthUserProvider),
            profile: null,
          );
      expect(canWriteNow(), isTrue,
          reason: 'Oturum açık + guest değil → yazma serbest olmalı');

      // Generic ChatScreen text send (GuardedMessagingRepository).
      final messaging = GuardedMessagingRepository(
        inner: LocalMessagingRepository(),
        canWriteCheck: canWriteNow,
      );
      final convId = await messaging.findOrCreateDirectConversation(
        otherUserId: 'u2',
      );
      final msg = await messaging.sendTextMessage(
        conversationId: convId,
        content: 'merhaba',
      );
      expect(msg.content, 'merhaba');

      // Group chat text send (GuardedSocialGroupRepository.postMessage).
      final groups = GuardedSocialGroupRepository(
        inner: LocalSocialGroupRepository(seed: false),
        canWriteCheck: canWriteNow,
      );
      final group = await groups.createGroup(
        name: 'Test Grubu',
        description: 'P0 regresyon',
        category: GroupCategory.bakers,
      );
      await groups.postMessage(
        GroupMessage(
          id: 'gm_1',
          groupId: group.id,
          authorName: 'Test',
          authorRole: 'Üye',
          text: 'grup mesajı',
          createdAt: DateTime(2026, 6, 10),
        ),
      );
    });

    test('gerçek guest (login yok, setGuest çağrısı yok) → guard görür',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // İlk erişim plain read (canWriteCheck pattern) — _load storage'dan
      // TRUE yükler; setGuest çağrılmadığı için yüklenen değer geçerli kalır.
      container.read(guestModeProvider);
      await _flushAsync();
      expect(container.read(guestModeProvider), isTrue,
          reason: 'Gerçek guest oturumunda persisted bayrak korunmalı');

      bool canWriteNow() => AuthRequiredGuard.canWrite(
            isGuest: container.read(guestModeProvider),
            supabaseEnabled: true,
            currentUser: null,
            profile: null,
          );
      final messaging = GuardedMessagingRepository(
        inner: LocalMessagingRepository(),
        canWriteCheck: canWriteNow,
      );
      expect(
        () => messaging.sendTextMessage(conversationId: 'c1', content: 'x'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });
  });

  group('P0 — simetrik yön: setGuest(true) de _load tarafından ezilmemeli',
      () {
    test('fresh install + "Kayıtsız Devam Et": state true kalır', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      GuestModeStorage.resetForTest();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // auth_entry_screen.dart:171 — ilk erişim setGuest(true).
      await container.read(guestModeProvider.notifier).setGuest(true);
      await _flushAsync();

      expect(container.read(guestModeProvider), isTrue,
          reason: '_load()\'un stale FALSE okuması bilinçli guest seçimini '
              'ezmemeli');
    });
  });
}
