// FırınNet P0 — Media Upload Auth Regression.
//
// Root cause: guard'lar cache'li `currentAuthUserProvider` (onAuthStateChange
// stream'ine bağlı) okuyordu; native picker resume'unda geçici null-session
// emit'i logged-in kullanıcıyı guest sanıyordu → AuthRequiredSheet → login
// (signOut hissi). Fix: guard'lar CANLI `authRepository.currentUser`
// (persist session) okur; upload owner uid'si de canlı session'dan gelir;
// gerçekten oturum yoksa auth sheet, signOut yok. Storage/RLS/network hatası
// upload error olarak gösterilir, auth-required'a map edilmez.

import 'dart:io';

import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/services/auth_required_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthRequiredGuard.canWrite — pure logic (regression matrisi)', () {
    test('Supabase + logged-in (currentUser var) → yazabilir', () {
      expect(
        AuthRequiredGuard.canWrite(
          isGuest: false,
          supabaseEnabled: true,
          currentUser: const AuthUser(id: 'uid-1', email: null),
          profile: null,
        ),
        isTrue,
        reason: 'Logged-in kullanıcı guest gibi algılanmamalı',
      );
    });

    test('Supabase + currentUser null → yazamaz (gerçek unauthenticated)', () {
      expect(
        AuthRequiredGuard.canWrite(
          isGuest: false,
          supabaseEnabled: true,
          currentUser: null,
          profile: null,
        ),
        isFalse,
      );
    });

    test('guestMode true → currentUser olsa bile yazamaz', () {
      expect(
        AuthRequiredGuard.canWrite(
          isGuest: true,
          supabaseEnabled: true,
          currentUser: const AuthUser(id: 'uid-1', email: null),
          profile: null,
        ),
        isFalse,
      );
    });
  });

  group('Guard wiring — CANLI session okunur (cache değil)', () {
    test('canWriteCheckProvider authRepository.currentUser okur', () {
      final src = File(
        'lib/features/auth/providers/can_write_check_provider.dart',
      ).readAsStringSync();
      expect(src.contains('authRepositoryProvider'), isTrue);
      expect(src.contains('.currentUser'), isTrue);
      expect(
        src.contains('currentUser: ref.read(currentAuthUserProvider)'),
        isFalse,
        reason: 'Cache\'li stream provider yerine canlı getter okunmalı',
      );
    });

    test('canWriteWithRef authRepository.currentUser okur', () {
      final src = File(
        'lib/features/auth/services/auth_required_guard.dart',
      ).readAsStringSync();
      expect(
        src.contains('currentUser: ref.read(authRepositoryProvider)?.currentUser'),
        isTrue,
      );
    });
  });

  group('Upload path — canlı uid + signOut yok', () {
    test('ChatScreen upload owner uid canlı session\'dan; signOut yok', () {
      final src = File('lib/features/messaging/screens/chat_screen.dart')
          .readAsStringSync();
      expect(
        src.contains('ref.read(authRepositoryProvider)?.currentUser?.id'),
        isTrue,
      );
      expect(src.contains('signOut('), isFalse,
          reason: 'Upload path kullanıcıyı signOut etmemeli');
      // Storage/network hatası auth-required değil, chatMediaSendError olur.
      expect(src.contains('AppStrings.chatMediaSendError'), isTrue);
    });

    test('GroupComposer upload owner uid canlı session\'dan; signOut yok', () {
      final src =
          File('lib/features/social_groups/screens/group_detail_screen.dart')
              .readAsStringSync();
      expect(
        src.contains('ref.read(authRepositoryProvider)?.currentUser?.id'),
        isTrue,
      );
      expect(src.contains('signOut('), isFalse);
      expect(src.contains('AppStrings.chatMediaSendError'), isTrue);
    });
  });
}
