// Google-only auth + legal/support batch — yeni ekran render testleri.
//
// Destek ve Yardım (SSS + iletişim CTA), Topluluk Kuralları, Hesap ve Veri
// Silme ekranları ve paylaşılan LegalScaffold'un render olduğunu doğrular.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/app_primary_button.dart';
import 'package:firin_defter/features/legal/screens/account_deletion_screen.dart';
import 'package:firin_defter/features/legal/screens/community_guidelines_screen.dart';
import 'package:firin_defter/features/legal/screens/privacy_screen.dart';
import 'package:firin_defter/features/legal/screens/terms_screen.dart';
import 'package:firin_defter/features/settings/screens/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('Destek ve Yardım', () {
    testWidgets('başlık + SSS + iletişim CTA render olur', (tester) async {
      await tester.pumpWidget(_wrap(const SupportScreen()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.supportTitle), findsWidgets);
      expect(find.text(AppStrings.supportFaqSection), findsOneWidget);
      // İlk SSS sorusu (collapsed ExpansionTile başlığı).
      expect(find.text('FırınNet nedir?'), findsOneWidget);
      expect(find.text('Hesabımı nasıl silebilirim?'), findsOneWidget);
      // İletişim CTA + e-posta alt bölümde — görünür kıl (lazy ListView).
      await tester.scrollUntilVisible(
        find.byType(AppPrimaryButton),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // AppPrimaryButton etiketi uppercase render eder; widget prop'undan oku.
      final cta = tester.widget<AppPrimaryButton>(
        find.byType(AppPrimaryButton),
      );
      expect(cta.label, AppStrings.supportContactCta);
      expect(find.text(AppStrings.supportEmail), findsOneWidget);
    });

    testWidgets('SSS sorusuna dokununca cevap açılır', (tester) async {
      await tester.pumpWidget(_wrap(const SupportScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('FırınNet nedir?'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('dijital sektör'),
        findsWidgets,
      );
    });
  });

  group('Yasal ekranlar', () {
    testWidgets('Topluluk Kuralları render olur', (tester) async {
      await tester.pumpWidget(_wrap(const CommunityGuidelinesScreen()));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.legalCommunityTitle), findsWidgets);
      // İlk bölüm (lazy ListView'de görünür).
      expect(find.text('1. Saygılı ol'), findsOneWidget);
    });

    testWidgets('Hesap ve Veri Silme render olur', (tester) async {
      await tester.pumpWidget(_wrap(const AccountDeletionScreen()));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.legalAccountDeletionTitle), findsWidgets);
      expect(find.text('Nasıl silinir?'), findsOneWidget);
    });

    testWidgets('Privacy + Terms paylaşılan iskelette render olur',
        (tester) async {
      await tester.pumpWidget(_wrap(const PrivacyScreen()));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.legalPrivacyTitle), findsWidgets);
      // Eski "V1 taslaktır" draft banner kaldırıldı.
      expect(find.textContaining('V1 taslaktır'), findsNothing);

      await tester.pumpWidget(_wrap(const TermsScreen()));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.legalTermsTitle), findsWidgets);
      expect(find.textContaining('V1 taslaktır'), findsNothing);
    });
  });
}
