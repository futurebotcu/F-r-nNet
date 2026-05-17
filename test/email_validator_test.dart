import 'package:firin_defter/features/auth/utils/email_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// V1.4 — Reserved test TLD email guard (Supabase Auth `email_address_invalid`
/// reddini client-side baştan engellemek için).
void main() {
  group('isReservedTestTldEmail', () {
    test('.test TLD reddedilir', () {
      expect(isReservedTestTldEmail('a@firinnet.test'), isTrue);
    });

    test('.example TLD reddedilir', () {
      expect(isReservedTestTldEmail('a@foo.example'), isTrue);
    });

    test('.invalid TLD reddedilir', () {
      expect(isReservedTestTldEmail('a@foo.invalid'), isTrue);
    });

    test('.localhost TLD reddedilir', () {
      expect(isReservedTestTldEmail('a@foo.localhost'), isTrue);
    });

    test('case-insensitive', () {
      expect(isReservedTestTldEmail('A@FOO.TEST'), isTrue);
      expect(isReservedTestTldEmail('A@FOO.Example'), isTrue);
    });

    test('whitespace trim edilir', () {
      expect(isReservedTestTldEmail('  a@x.test  '), isTrue);
    });

    test('boş string false döner', () {
      expect(isReservedTestTldEmail(''), isFalse);
      expect(isReservedTestTldEmail('   '), isFalse);
    });

    test('gerçek public domain false döner', () {
      expect(isReservedTestTldEmail('user@gmail.com'), isFalse);
      expect(isReservedTestTldEmail('user@firinnet.com.tr'), isFalse);
      expect(isReservedTestTldEmail('user@outlook.com'), isFalse);
    });

    test('TLD substring olarak ortada geçen domain false döner', () {
      // .test başka TLD'nin substring'i olarak görünmemeli
      expect(isReservedTestTldEmail('user@test.com'), isFalse);
      expect(isReservedTestTldEmail('user@example.com'), isFalse);
    });
  });
}
