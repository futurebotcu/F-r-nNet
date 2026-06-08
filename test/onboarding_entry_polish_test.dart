import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/app_primary_button.dart';
import 'package:firin_defter/core/widgets/premium/premium_top_banner.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/screens/auth_entry_screen.dart';
import 'package:firin_defter/features/auth/screens/login_screen.dart';
import 'package:firin_defter/features/onboarding/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: child,
    ),
  );
}

void main() {
  group('Onboarding / entry polish', () {
    testWidgets('Onboarding dört değer mesajını gösterir', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));

      expect(find.text('Hoş geldin\nFırınNet\'e'), findsOneWidget);
      expect(
        find.text('Sektör akışı, gruplar, ilanlar ve bayi takibi tek yerde.'),
        findsOneWidget,
      );
      expect(
        find.text('Fırıncılar, ustalar ve tedarikçilerle aynı akışta buluş.'),
        findsOneWidget,
      );
      expect(
        find.text('Bölgen, ürün tipin veya ihtiyacın için gruplara katıl.'),
        findsOneWidget,
      );
      expect(
        find.text('Ürün, tedarik, iş ve fırsatları tek yerde takip et.'),
        findsOneWidget,
      );
      expect(
        find.text('Bayi, tahsilat, hareket ve gün sonunu düzenli tut.'),
        findsOneWidget,
      );
      expect(find.text('Kayıtsız Devam Et'), findsOneWidget);
    });

    testWidgets('Auth entry top banner ve yeni copy görünür', (tester) async {
      await tester.pumpWidget(_wrap(const AuthEntryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('FırınNet\'e hoş geldin'), findsOneWidget);
      expect(
        find.text(
          'Fırıncılar, ustalar ve tedarikçiler için akış, grup, ilan ve bayi takibi.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Sunucu bağlantısı kapalı. Yine de kayıtsız keşfe devam edebilirsin.',
        ),
        findsOneWidget,
      );
      final primaryButton = tester.widget<AppPrimaryButton>(
        find.byType(AppPrimaryButton),
      );
      expect(primaryButton.label, 'Giriş Yap');
      expect(find.text('Hesap oluştur'), findsOneWidget);
      expect(find.text('Kayıtsız devam et'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('Login ekranı premium giriş alt başlığını gösterir', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.text(
          'Hesabına gir, sektör akışını ve araçlarını kaldığın yerden sürdür.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Sunucu bağlantısı kapalı. Bu sürümde yalnızca misafir deneyimi çalışır.',
        ),
        findsOneWidget,
      );
      expect(find.text(AppStrings.authForgotPassword), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('PremiumTopBanner temel görünüm', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PremiumTopBanner(
                message: 'Kısa, sakin ve premium bir bilgi.',
                tone: PremiumTopBannerTone.success,
                actionLabel: 'Tamam',
                onAction: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kısa, sakin ve premium bir bilgi.'), findsOneWidget);
      expect(find.text('Tamam'), findsOneWidget);
      expect(find.byKey(const ValueKey('premium_top_banner_close')),
          findsOneWidget);
    });
  });
}
