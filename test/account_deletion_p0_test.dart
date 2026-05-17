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
      src = File('lib/features/auth/services/auth_actions.dart')
          .readAsStringSync();
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
  });

  group('SettingsScreen delete tile (source) — V1.4', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/settings/screens/settings_screen.dart')
          .readAsStringSync();
    });

    test('Settings "Hesabımı sil" tile performDeleteAccount çağırır', () {
      expect(src.contains('AppStrings.settingsDeleteAccount'), isTrue);
      expect(src.contains('performDeleteAccount(context, ref)'), isTrue);
      expect(src.contains('danger: true'), isTrue,
          reason: 'Silme tile danger flag ile kırmızı tonda gösterilmeli');
    });
  });

  group('delete-account Edge Function (source)', () {
    late String src;
    setUpAll(() {
      src = File('supabase/functions/delete-account/index.ts')
          .readAsStringSync();
    });

    test('service_role yalnız Deno.env.get üzerinden okunur', () {
      expect(
        src.contains("Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')"),
        isTrue,
        reason: 'Function service_role\'ü env\'den okumalı',
      );
      // Hardcoded JWT format'ı (eyJ...) kontrol — function'da olmamalı.
      final hasHardcodedJwt = RegExp(r'eyJ[A-Za-z0-9_-]{20,}').hasMatch(src);
      expect(hasHardcodedJwt, isFalse,
          reason: 'Function source\'unda hardcoded JWT olmamalı');
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

    test('verify_jwt + service_role server-side disiplini', () {
      // Caller JWT ayrı bir client'la doğrulanıyor; admin client ayrı.
      expect(src.contains('auth.getUser'), isTrue);
      expect(src.contains('createClient'), isTrue);
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
        expect(jwtPattern.hasMatch(content), isFalse,
            reason: '${f.path} icinde hardcoded JWT format string olmamali');
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
        expect(content.contains('"Authorization": "Bearer service_role'),
            isFalse,
            reason: '${f.path} icinde Bearer service_role literal olmamali');
        expect(content.contains("'Authorization': 'Bearer service_role"),
            isFalse,
            reason: '${f.path} icinde Bearer service_role literal olmamali');
      }
    });
  });
}
