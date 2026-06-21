import 'package:firin_defter/app/router/app_router.dart';
import 'package:firin_defter/core/constants/app_products.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/providers/guest_mode_provider.dart';
import 'package:firin_defter/features/auth/services/guest_mode_storage.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GuestModeStorage.resetForTest();
  });

  group('V1.3 — Guest mode persistence', () {
    test('default: guest flag false', () async {
      final v = await GuestModeStorage.instance.read();
      expect(v, isFalse);
    });

    test('write(true) → read true; restart sonrası bile korunur', () async {
      await GuestModeStorage.instance.write(true);
      // Yeni storage instance — restart simülasyonu
      GuestModeStorage.resetForTest();
      final v = await GuestModeStorage.instance.read();
      expect(v, isTrue);
    });

    test('logout → clear() → guest flag false', () async {
      await GuestModeStorage.instance.write(true);
      await GuestModeStorage.instance.clear();
      final v = await GuestModeStorage.instance.read();
      expect(v, isFalse);
    });

    test('GuestModeNotifier setGuest persist eder', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Notifier'i HEMEN materialize et (yoksa _load constructor sonrası
      // async çalışırken setGuest ile race olur).
      final notifier = container.read(guestModeProvider.notifier);
      // _load() tamamlanana kadar bekle — SharedPreferences boş, false döner.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(guestModeProvider), isFalse);

      await notifier.setGuest(true);
      expect(container.read(guestModeProvider), isTrue);

      // SharedPreferences'a yazıldı mı?
      GuestModeStorage.resetForTest();
      final persisted = await GuestModeStorage.instance.read();
      expect(persisted, isTrue);
    });
  });

  group('V1.3 — BakeryProfile.isComplete contract', () {
    test('tüm zorunlu alanlar dolu → complete', () {
      const p = BakeryProfile(
        displayName: 'Hasan',
        accountType: AccountType.commercial,
        city: 'Konya',
        roleBadge: 'Usta Fırıncı',
        email: 'h@x.com',
      );
      expect(p.isComplete, isTrue);
    });

    test('displayName boş → incomplete', () {
      const p = BakeryProfile(
        displayName: '',
        accountType: AccountType.commercial,
        city: 'Konya',
        roleBadge: 'Usta Fırıncı',
        email: 'h@x.com',
      );
      expect(p.isComplete, isFalse);
    });

    test('city boş → incomplete', () {
      const p = BakeryProfile(
        displayName: 'Hasan',
        accountType: AccountType.commercial,
        city: '',
        roleBadge: 'Usta Fırıncı',
        email: 'h@x.com',
      );
      expect(p.isComplete, isFalse);
    });

    test('roleBadge boş → incomplete', () {
      const p = BakeryProfile(
        displayName: 'Hasan',
        accountType: AccountType.commercial,
        city: 'Konya',
        roleBadge: '',
        email: 'h@x.com',
      );
      expect(p.isComplete, isFalse);
    });

    test('BakeryProfile.guest → incomplete (city + roleBadge boş)', () {
      expect(BakeryProfile.guest.isComplete, isFalse);
    });
  });

  group('V1.3 — Role bazlı meslek rozetleri', () {
    test('Ticari: Usta Fırıncı, Fırın Sahibi, İşletmeci, Pastacı, Diğer', () {
      expect(RoleBadges.commercial, hasLength(5));
      expect(RoleBadges.commercial.first, 'Usta Fırıncı');
      expect(RoleBadges.commercial, contains('İşletmeci'));
      expect(RoleBadges.commercial.last, 'Diğer');
    });

    test('Bireysel: usta/mayacı/hamurcu/simitçi/.../çırak/kalfa', () {
      expect(RoleBadges.individual, contains('Mayacı'));
      expect(RoleBadges.individual, contains('Hamurcu'));
      expect(RoleBadges.individual, contains('Simitçi'));
      expect(RoleBadges.individual, contains('Çırak'));
      expect(RoleBadges.individual, contains('Kalfa'));
    });

    test('Toptancı: Toptancı/Uncu/Susamcı/Ekipman Satıcısı/Diğer', () {
      expect(RoleBadges.wholesaler.first, 'Toptancı');
      expect(RoleBadges.wholesaler, contains('Uncu'));
      expect(RoleBadges.wholesaler, contains('Susamcı'));
      expect(RoleBadges.wholesaler, contains('Ekipman Satıcısı'));
    });

    test('RoleBadges.all (legacy) korundu — geriye dönük uyumluluk', () {
      expect(RoleBadges.all, isNotEmpty);
      expect(RoleBadges.all, contains('Usta Fırıncı'));
    });
  });

  group('V1.3 — Route sözleşmesi', () {
    test('AppRoutes.authEntry = /auth', () {
      expect(AppRoutes.authEntry, '/auth');
    });

    test('AppRoutes.roleSelect = /auth/role-select', () {
      expect(AppRoutes.roleSelect, '/auth/role-select');
    });

    test('AppRoutes.createProfile = /profile/create', () {
      expect(AppRoutes.createProfile, '/profile/create');
    });

    test('AppRoutes.login = /login (push ile auth entry\'den)', () {
      expect(AppRoutes.login, '/login');
    });
  });

  group('V1.3 — Auth entry stringleri (UI sözleşmesi)', () {
    test('3 buton metni mevcut', () {
      expect(AppStrings.authEntrySignIn, 'Giriş Yap');
      expect(AppStrings.authEntrySignUp, 'Hesabım yok, üye ol');
      expect(AppStrings.authEntryGuest, 'Kayıtsız devam et');
    });

    test('Backend off uyarı metni mevcut', () {
      expect(AppStrings.authEntryBackendOff,
          contains('Kayıtsız devam edebilirsin'));
    });

    test('Role select rol açıklamaları mevcut', () {
      // Rol standardı: commercial→Fırın/İşletme, individual→Usta/Çalışan,
      // wholesaler→Tedarikçi/Toptancı (app-wide naming standardization).
      expect(AppStrings.roleCommercialTitle, 'Fırın / İşletme');
      expect(AppStrings.roleCommercialSub, contains('Fırın'));
      expect(AppStrings.roleIndividualTitle, 'Usta / Çalışan');
      expect(AppStrings.roleIndividualSub, contains('Usta'));
      expect(AppStrings.roleWholesalerTitle, 'Tedarikçi / Toptancı');
      expect(AppStrings.roleWholesalerSub, contains('Müşteri'));
    });
  });
}
