import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/services/auth_required_guard.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V1.3.1 — AuthRequiredGuard.canWrite (pure logic)', () {
    const realUser = AuthUser(id: 'u1', email: 'a@b.c');
    const realProfile = BakeryProfile(
      displayName: 'Hasan',
      accountType: AccountType.commercial,
      city: 'Konya',
      roleBadge: 'Usta Fırıncı',
      email: 'a@b.c',
    );

    test('guest=true her durumda yazma engellenir', () {
      expect(
        AuthRequiredGuard.canWrite(
          isGuest: true,
          supabaseEnabled: true,
          currentUser: realUser,
          profile: realProfile,
        ),
        isFalse,
        reason: 'Kullanıcı Kayıtsız Devam Et seçti — write engellenir',
      );
      expect(
        AuthRequiredGuard.canWrite(
          isGuest: true,
          supabaseEnabled: false,
          currentUser: null,
          profile: realProfile,
        ),
        isFalse,
      );
    });

    test('Supabase enabled + signed-in → izin', () {
      expect(
        AuthRequiredGuard.canWrite(
          isGuest: false,
          supabaseEnabled: true,
          currentUser: realUser,
          profile: realProfile,
        ),
        isTrue,
      );
    });

    test('Supabase enabled + user null → engelle', () {
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

    test('Supabase disabled + local non-guest profile → izin (legacy)', () {
      expect(
        AuthRequiredGuard.canWrite(
          isGuest: false,
          supabaseEnabled: false,
          currentUser: null,
          profile: realProfile,
        ),
        isTrue,
        reason: 'Anahtarsız mod + gerçek local profile yazabilmeli',
      );
    });

    test('Supabase disabled + profile null → engelle', () {
      expect(
        AuthRequiredGuard.canWrite(
          isGuest: false,
          supabaseEnabled: false,
          currentUser: null,
          profile: null,
        ),
        isFalse,
      );
    });

    test('Supabase disabled + BakeryProfile.guest → engelle', () {
      expect(
        AuthRequiredGuard.canWrite(
          isGuest: false,
          supabaseEnabled: false,
          currentUser: null,
          profile: BakeryProfile.guest,
        ),
        isFalse,
        reason: 'Misafir profile object yazma yetkisi vermez',
      );
    });
  });
}
