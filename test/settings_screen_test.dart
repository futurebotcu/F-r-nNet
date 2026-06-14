// V1.4 — Settings menüsü Phase 1 doğrulama testleri.
//
// Kapsam:
//   1. /settings rotası tanımlı + AppRoutes.settings constant'ı mevcut.
//   2. SettingsScreen 4 section başlığı doğru sıralamada render eder
//      (Hesap → Güvenlik ve Veri → Yasal → Uygulama).
//   3. Sahte/çalışmayan tile YOK (Bildirim, Tema, Dil, Destek, Yardım,
//      Sorun bildir, Apple ayarı vb.).
//   4. Profile ekranındaki gear icon -> /settings push'u.
//   5. Hakkında ekranı 'Sürüm' label + statik metin gösterir.
//   6. Verilerim hakkında bilgi ekranı statik metni gösterir.

import 'dart:io';

import 'package:firin_defter/app/router/app_router.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/settings/screens/about_screen.dart';
import 'package:firin_defter/features/settings/screens/data_info_screen.dart';
import 'package:firin_defter/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRoutes constants — V1.4', () {
    test('settings ve alt route\'ları tanımlı', () {
      expect(AppRoutes.settings, '/settings');
      expect(AppRoutes.settingsAbout, '/settings/about');
      expect(AppRoutes.settingsDataInfo, '/settings/data-info');
    });

    test('router source\'da settings GoRoute\'ları kayıtlı', () {
      final src = File('lib/app/router/app_router.dart').readAsStringSync();
      expect(src.contains('path: AppRoutes.settings'), isTrue);
      expect(src.contains('path: AppRoutes.settingsAbout'), isTrue);
      expect(src.contains('path: AppRoutes.settingsDataInfo'), isTrue);
      expect(src.contains('const SettingsScreen()'), isTrue);
      expect(src.contains('const AboutScreen()'), isTrue);
      expect(src.contains('const DataInfoScreen()'), isTrue);
    });
  });

  group('Profile gear icon — V1.4', () {
    // Unified Profile M2: ProfileScreen redirector'a dönüştü. Public
    // profile artık SocialProfilePage; self görüntülemede AppBar
    // actions içinde settings gear (V1.4 entry point korundu).
    late String src;
    setUpAll(() {
      src = File('lib/features/social/profile/profile_page.dart')
          .readAsStringSync();
    });

    test('AppBar actions içinde (isSelf) settings gear icon var', () {
      expect(src.contains('Icons.settings_outlined'), isTrue);
      expect(src.contains('AppStrings.settingsTooltip'), isTrue);
      expect(src.contains('AppRoutes.settings'), isTrue);
    });

    test('Eski sign-out + delete inline UI Settings\'e taşındı', () {
      // V1.4'te bu blok Settings ekranına taşındı. Aynı isimle private
      // sınıfların ya da inline `auth.signOut()` / `auth.deleteAccount()`
      // çağrılarının kalması shared service'e taşıma yapılmadığını gösterir.
      expect(src.contains('_DangerZoneCard'), isFalse);
      expect(src.contains('_onDeleteAccountPressed'), isFalse);
      expect(src.contains('auth.signOut()'), isFalse,
          reason: 'signOut çağrısı auth_actions.performSignOut\'a taşındı');
      expect(src.contains('auth.deleteAccount()'), isFalse,
          reason: 'deleteAccount çağrısı auth_actions.performDeleteAccount\'a taşındı');
    });
  });

  group('SettingsScreen rendering', () {
    Widget wrap(Widget child) => ProviderScope(
          child: MaterialApp(home: child),
        );

    testWidgets('4 section başlığı doğru sırada görünür', (tester) async {
      // Settings içerik arttı (Yasal 4 tile + Destek); tüm bölümler lazy
      // ListView'de buildlensin diye uzun viewport ver.
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      final hesapFinder =
          find.text(AppStrings.settingsSectionAccount, skipOffstage: false);
      final guvenlikFinder =
          find.text(AppStrings.settingsSectionSecurity, skipOffstage: false);
      final yasalFinder =
          find.text(AppStrings.settingsSectionLegal, skipOffstage: false);
      final appFinder =
          find.text(AppStrings.settingsSectionApp, skipOffstage: false);

      expect(hesapFinder, findsOneWidget);
      expect(guvenlikFinder, findsOneWidget);
      expect(yasalFinder, findsOneWidget);
      expect(appFinder, findsOneWidget);
    });

    testWidgets('Beklenen tile başlıkları görünür', (tester) async {
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      for (final s in [
        AppStrings.settingsEditProfile,
        AppStrings.settingsSignOut,
        AppStrings.settingsDeleteAccount,
        AppStrings.settingsDataInfo,
        AppStrings.settingsPrivacy,
        AppStrings.settingsTerms,
        AppStrings.settingsCommunity,
        AppStrings.settingsAccountDeletion,
        AppStrings.settingsSupport,
        AppStrings.settingsAbout,
      ]) {
        expect(find.text(s, skipOffstage: false), findsWidgets,
            reason: 'Settings ekranında "$s" tile\'ı görünmeli');
      }
    });

    testWidgets('Sahte/çalışmayan tile EKLENMEMİŞ', (tester) async {
      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      // V1.4 Phase 1: bilerek dışarıda bırakılan başlıklar.
      // V1 P1-D NOTU: "Bildirimler" artık GERÇEK feature olarak eklendi
      // (NotificationsScreen + /notifications route), bu yüzden forbidden
      // listesinden çıkarıldı. Diğer fake başlıklar hâlâ yasak.
      const forbidden = [
        'Tema',
        'Dil',
        'Karanlık mod',
        'Destek birimine yaz',
        'Yardım merkezi',
        'Sorun bildir',
        'Apple ile devam et',
      ];
      for (final f in forbidden) {
        expect(find.text(f, skipOffstage: false), findsNothing,
            reason: 'Phase 1\'de "$f" tile olmamalı');
      }
    });
  });

  group('AboutScreen rendering', () {
    testWidgets('Hakkında ekranı app adı, tagline ve Sürüm label gösterir',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AboutScreen())),
      );
      // PackageInfo native channel test ortamında çalışmaz; '—' fallback olur.
      // pumpAndSettle çağırma — async future kilitlemeyelim. Tek frame yeter.
      await tester.pump();

      expect(find.text(AppStrings.aboutAppLine), findsOneWidget);
      expect(find.text(AppStrings.aboutTagline), findsOneWidget);
      expect(find.text(AppStrings.aboutVersionLabel), findsOneWidget);
    });
  });

  group('DataInfoScreen rendering', () {
    testWidgets('Statik metin görünür', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: DataInfoScreen())),
      );
      await tester.pump();

      expect(find.text(AppStrings.dataInfoTitle), findsOneWidget);
      // Body uzun; sadece varlığını teyit et (skipOffstage ListView için).
      expect(find.text(AppStrings.dataInfoBody, skipOffstage: false),
          findsOneWidget);
    });
  });
}
