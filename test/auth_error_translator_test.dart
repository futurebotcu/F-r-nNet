import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/utils/auth_error_translator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// V1.4 — `translateAuthError` Türkçe mapping kontrol — özellikle
/// Supabase Auth tarafından dönen `email_address_invalid` (.test/.example TLD
/// veya disposable domain block list ile reddedilen e-postalar) için.
void main() {
  group('translateAuthError — V1.4 email_address_invalid', () {
    test('code == email_address_invalid → Türkçe mesaj', () {
      final err = AuthApiException(
        'Email address "x@y.test" is invalid',
        code: 'email_address_invalid',
        statusCode: '400',
      );
      expect(translateAuthError(err), AppStrings.authEmailAddressInvalid);
    });

    test('code yoksa ama message "Email address ... invalid" → Türkçe mesaj',
        () {
      final err = AuthApiException(
        'Email address "foo@bar.test" is invalid',
        statusCode: '400',
      );
      expect(translateAuthError(err), AppStrings.authEmailAddressInvalid);
    });

    test('email_address_invalid mesajı düz/teknik İngilizce DEĞİL', () {
      final err = AuthApiException(
        'Email address "x" is invalid',
        code: 'email_address_invalid',
      );
      final out = translateAuthError(err);
      // Kullanıcı görmeli; "Sunucu hatası:" prefix'i veya raw İngilizce metin
      // basılmamalı.
      expect(out, isNot(startsWith('Sunucu hatası')));
      expect(out, isNot(contains('Email address')));
      expect(out, isNot(contains('is invalid')));
      expect(out, AppStrings.authEmailAddressInvalid);
    });
  });

  group('translateAuthError — regression (mevcut mapping korunur)', () {
    test('invalid_credentials Türkçe kalır', () {
      final err = AuthApiException('Invalid login credentials',
          code: 'invalid_credentials');
      expect(translateAuthError(err), 'E-posta veya şifre hatalı.');
    });

    test('email_not_confirmed Türkçe kalır', () {
      final err = AuthApiException('Email not confirmed',
          code: 'email_not_confirmed');
      expect(translateAuthError(err),
          'E-posta adresin henüz onaylanmadı. Gelen kutunu kontrol et.');
    });

    test('user_already_exists Türkçe kalır', () {
      final err = AuthApiException('User already registered',
          code: 'user_already_exists');
      expect(translateAuthError(err),
          'Bu e-posta zaten kayıtlı. Giriş yapmayı dene.');
    });

    test('AuthUnknownException Türkçe kalır', () {
      final err = AuthUnknownException(
        message: 'Failed to decode error response',
        originalError: Exception('x'),
      );
      expect(translateAuthError(err),
          'Sunucu bağlantısı yapılandırılamadı. Lütfen daha sonra tekrar dene.');
    });
  });
}
