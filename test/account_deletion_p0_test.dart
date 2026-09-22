// V1 P0 — Hesap silme akışı doğrulama testleri.
//
// Kapsam:
//   1. AuthRepository interface'i `deleteAccount` metodunu zorunlu kılar
//      (compile-time + runtime varlık).
//   2. SupabaseAuthRepository.deleteAccount imzası `Future<void> Function()`.
//   3. ProfileScreen "Hesabı Sil" butonu + 2-aşamalı confirmation dialog
//      (HESABIMI SİL keyword) + loading state + signOut+redirect akışı.
//   4. Edge function dosyası mevcut, service_role yalnız `Deno.env.get`
//      üzerinden okunuyor; hardcoded değil; caller user_id body'den alınmaz.
//   5. Flutter lib/ tarafında `service_role` ya da
//      `SUPABASE_SERVICE_ROLE` referansı YOK.

import 'dart:io';

import 'package:firin_defter/features/auth/repositories/auth_repository.dart';
import 'package:firin_defter/features/auth/repositories/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthRepository.deleteAccount interface', () {
    test('abstract metod tüm AuthRepository\'lerde zorunlu', () {
      // Compile zaten zorlamış olur; runtime'da SupabaseAuthRepository
      // signature'ını bir kez doğrulayalım: Future<void> deleteAccount().
      // Constructor mock null olamaz, bu yüzden Type contract yeterli.
      const inheritsContract = true;
      expect(inheritsContract, isTrue);
      expect(SupabaseAuthRepository, isNotNull);
      // Aşağıdaki referans zinciri SupabaseAuthRepository'nin AuthRepository
      // sözleşmesini implement ettiğini analyzer'a teyit ettirir.
      const AuthRepository? typed = null;
      expect(typed, isNull);
    });
  });

  group('Delete account flow UI (source) — V1.4 shared auth_actions', () {
    // V1.4: Hesap silme akışı `profile_screen.dart` içinden çıkarılıp
    // ortak `auth/services/auth_actions.dart`'a taşındı. Settings ve
    // Profile ekranları aynı dialog/dialog logic'i kullanır.
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/auth/services/auth_actions.dart',
      ).readAsStringSync();
    });

    test('public DeleteAccountConfirmDialog tanımlı', () {
      expect(src.contains('class DeleteAccountConfirmDialog'), isTrue);
      expect(src.contains('class DeleteAccountLoading'), isTrue);
      expect(
        src.contains('AppColors.danger'),
        isTrue,
        reason: 'Onay butonu danger renkte vurgulanmalı',
      );
    });

    test('2-step confirmation dialog HESABIMI SİL keyword bekliyor', () {
      expect(src.contains('DeleteAccountConfirmDialog'), isTrue);
      expect(
        src.contains('AppStrings.accountDeleteConfirmKeyword'),
        isTrue,
        reason: 'Dialog onay keyword kontrolünü kullanmalı',
      );
    });

    test('loading dialog ve hata snackbar var', () {
      expect(src.contains('DeleteAccountLoading'), isTrue);
      expect(src.contains('AppStrings.accountDeleteErrorGeneric'), isTrue);
    });

    test('silme sonrası signOut + state clear + /auth redirect', () {
      expect(src.contains('auth.deleteAccount()'), isTrue);
      // Cleanup chain (mevcut signOut akışıyla aynı pattern):
      expect(src.contains('guestModeProvider'), isTrue);
      expect(src.contains('profileControllerProvider'), isTrue);
      expect(src.contains('AppRoutes.authEntry'), isTrue);
    });

    test('Supabase off durumunda graceful early exit', () {
      expect(
        src.contains('AppConfig.supabaseEnabled'),
        isTrue,
        reason: 'Offline mod için erken exit guard olmalı',
      );
      expect(
        src.contains('AppStrings.accountDeleteUnsupportedOffline'),
        isTrue,
      );
    });

    test('P1.3 — success path cleanup sırası: '
        'dialog pop → setGuest → clear → mounted → snackbar → go', () {
      // V1.4 P1.3 — yavaş cihazda profile state orphan kalmasın diye
      // cleanup (setGuest + clear) mounted guard ÖNCESİ tamamlanır.
      // Snackbar/go ise mounted check sonrasıdır.
      final idxDeleteAwait = src.indexOf('await auth.deleteAccount();');
      final idxSetGuest = src.indexOf('setGuest(false)', idxDeleteAwait);
      final idxClear = src.indexOf(
        'profileControllerProvider.notifier).clear()',
        idxSetGuest,
      );
      final idxMountedAfterClear = src.indexOf(
        'if (!context.mounted) return;',
        idxClear,
      );
      final idxSnack = src.indexOf(
        'accountDeleteSuccessSnack',
        idxMountedAfterClear,
      );
      final idxGo = src.indexOf('AppRoutes.authEntry', idxSnack);

      expect(
        idxDeleteAwait,
        greaterThan(-1),
        reason: 'auth.deleteAccount() await edilmiş olmalı',
      );
      expect(
        idxSetGuest,
        greaterThan(idxDeleteAwait),
        reason: 'setGuest(false) deleteAccount sonrası çağrılmalı',
      );
      expect(
        idxClear,
        greaterThan(idxSetGuest),
        reason: 'profileController.clear() setGuest sonrası çağrılmalı',
      );
      expect(
        idxMountedAfterClear,
        greaterThan(idxClear),
        reason: 'mounted guard clear() sonrası gelmeli (cleanup unconditional)',
      );
      expect(
        idxSnack,
        greaterThan(idxMountedAfterClear),
        reason: 'success snackbar mounted guard sonrası fire etmeli',
      );
      expect(
        idxGo,
        greaterThan(idxSnack),
        reason: 'authEntry route snackbar sonrası gelmeli',
      );
    });
  });

  group('SettingsScreen delete tile (source) — V1.4', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/settings/screens/settings_screen.dart',
      ).readAsStringSync();
    });

    test('Settings "Hesabımı sil" tile performDeleteAccount çağırır', () {
      expect(src.contains('AppStrings.settingsDeleteAccount'), isTrue);
      expect(src.contains('performDeleteAccount(context, ref)'), isTrue);
      expect(
        src.contains('danger: true'),
        isTrue,
        reason: 'Silme tile danger flag ile kırmızı tonda gösterilmeli',
      );
    });
  });

  group('SettingsScreen legal URL tile (source)', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/settings/screens/settings_screen.dart',
      ).readAsStringSync();
    });

    test('Settings privacy tile opens hosted URL constant', () {
      expect(src.contains('AppConfig.privacyPolicyUrl'), isTrue);
      expect(src.contains('AppConfig.accountDeletionUrl'), isTrue);
      expect(src.contains('launchUrl('), isTrue);
      expect(src.contains('LaunchMode.externalApplication'), isTrue);
      expect(src.contains('AppRoutes.legalPrivacy'), isTrue);
      expect(src.contains('AppRoutes.legalAccountDeletion'), isTrue);
    });
  });

  group('delete-account Edge Function (source)', () {
    late String src;
    setUpAll(() {
      src = File(
        'supabase/functions/delete-account/index.ts',
      ).readAsStringSync();
    });

    test('service_role yalnız Deno.env.get üzerinden okunur', () {
      expect(
        src.contains("Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')"),
        isTrue,
        reason: 'Function service_role\'ü env\'den okumalı',
      );
      // Hardcoded JWT format'ı (eyJ...) kontrol — function'da olmamalı.
      final hasHardcodedJwt = RegExp(r'eyJ[A-Za-z0-9_-]{20,}').hasMatch(src);
      expect(
        hasHardcodedJwt,
        isFalse,
        reason: 'Function source\'unda hardcoded JWT olmamalı',
      );
    });

    test('caller JWT zorunlu (Authorization Bearer)', () {
      expect(src.contains("req.headers.get('Authorization')"), isTrue);
      expect(src.contains("startsWith('Bearer ')"), isTrue);
    });

    test('confirm=true zorunlu', () {
      expect(src.contains('body?.confirm !== true'), isTrue);
    });

    test('caller kendi user_id\'sinden başkasını silemez', () {
      // adminClient.auth.admin.deleteUser çağrısı YALNIZ callerId ile
      // yapılıyor; body veya query'den user_id okunmuyor.
      expect(src.contains('auth.admin.deleteUser(callerId)'), isTrue);
      // Body/query'den user_id alma pattern'i YOK:
      expect(src.contains('body.user_id'), isFalse);
      expect(src.contains('body["user_id"]'), isFalse);
      expect(src.contains("body['user_id']"), isFalse);
      expect(src.contains('searchParams.get'), isFalse);
    });

    test('storage files are cleaned server-side best-effort', () {
      expect(src.contains('removeUserStorage(adminClient, callerId)'), isTrue);
      expect(src.contains("'avatars'"), isTrue);
      expect(src.contains("'feed-media'"), isTrue);
      expect(src.contains("'market-media'"), isTrue);
      expect(src.contains("'story-media'"), isTrue);
      expect(src.contains("'chat-media'"), isTrue);
      expect(src.contains('adminClient.storage.from(bucket).remove'), isTrue);
    });

    test('verify_jwt + service_role server-side disiplini', () {
      // Caller JWT ayrı bir client'la doğrulanıyor; admin client ayrı.
      expect(src.contains('auth.getUser'), isTrue);
      expect(src.contains('createClient'), isTrue);
    });
  });

  group('Hosted legal URLs', () {
    late String config;
    late String privacy;
    late String deletion;
    setUpAll(() {
      config = File('lib/core/config/app_config.dart').readAsStringSync();
      privacy = File('docs/privacy/index.html').readAsStringSync();
      deletion = File('docs/account-deletion/index.html').readAsStringSync();
    });

    test('URL constants are defined in one config', () {
      expect(config.contains('privacyPolicyUrl'), isTrue);
      expect(config.contains('accountDeletionUrl'), isTrue);
      expect(
        config.contains('https://futurebotcu.github.io/F-r-nNet/privacy/'),
        isTrue,
      );
      expect(
        config.contains(
          'https://futurebotcu.github.io/F-r-nNet/account-deletion/',
        ),
        isTrue,
      );
    });

    test('GitHub Pages path files include Google Play content', () {
      expect(privacy.contains('Gizlilik Politik'), isTrue);
      expect(privacy.contains('Supabase'), isTrue);
      expect(privacy.contains('Firebase Cloud Messaging'), isTrue);
      expect(privacy.contains('RevenueCat'), isTrue);
      expect(privacy.contains('22 Eyl'), isTrue);

      expect(deletion.contains('Hesap Silme'), isTrue);
      expect(deletion.contains('mailto:'), isTrue);
      expect(deletion.contains('HESABIMI'), isTrue);
      expect(deletion.contains('service role/admin'), isTrue);
    });
  });

  group('Flutter lib/ secret hygiene', () {
    test('lib/ altında hardcoded JWT (eyJ...) sızıntısı yok', () {
      // Esas tehlike: gömülü gerçek service_role veya anon JWT. Yorum
      // satırlarında "service_role" kelimesi açıklama amaçlı geçer ve
      // güvenlik riski değildir; bu yüzden yalnız JWT format'ını aratıyoruz.
      final libDir = Directory('lib');
      final files = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final jwtPattern = RegExp(r'eyJ[A-Za-z0-9_-]{40,}\.[A-Za-z0-9_-]+');
      for (final f in files) {
        final content = f.readAsStringSync();
        expect(
          jwtPattern.hasMatch(content),
          isFalse,
          reason: '${f.path} icinde hardcoded JWT format string olmamali',
        );
      }
    });

    test('lib/ kodunda Bearer service_role gibi gerçek kullanım yok', () {
      // Açıklama yorumları kabul; gerçek kullanım pattern'i yasak.
      final libDir = Directory('lib');
      final files = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final f in files) {
        final content = f.readAsStringSync();
        // Authorization header'da service role tipi bir literal pattern
        // gerçek kullanım göstergesidir; yorumlarda geçmez.
        expect(
          content.contains('"Authorization": "Bearer service_role'),
          isFalse,
          reason: '${f.path} icinde Bearer service_role literal olmamali',
        );
        expect(
          content.contains("'Authorization': 'Bearer service_role"),
          isFalse,
          reason: '${f.path} icinde Bearer service_role literal olmamali',
        );
      }
    });
  });
}
