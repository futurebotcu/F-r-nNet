// Profile About Section — bio header yerine ayrı "Hakkımda" bölümünde.
// ProfileAboutSection provider'sız → gerçek widget testi.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/social/profile/widgets/profile_about_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({
  required String? bio,
  required bool isSelf,
  VoidCallback? onAddBio,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ProfileAboutSection(bio: bio, isSelf: isSelf, onAddBio: onAddBio),
    ),
  );
}

void main() {
  group('ProfileAboutSection — Hakkımda', () {
    testWidgets('bio doluysa: başlık + bio metni görünür (self → Hakkımda)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        bio: '20 yıldır ekşi mayalı ekmek üretiyorum.',
        isSelf: true,
      ));
      expect(find.text(AppStrings.profileAboutTitleSelf), findsOneWidget);
      expect(
        find.text('20 yıldır ekşi mayalı ekmek üretiyorum.'),
        findsOneWidget,
      );
      // Boş CTA görünmez.
      expect(find.text(AppStrings.profileAboutAddCta), findsNothing);
    });

    testWidgets('başkasının profilinde bio doluysa "Hakkında" başlığı', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(
        bio: 'Manisa\'da aile fırınıyız.',
        isSelf: false,
      ));
      expect(find.text(AppStrings.profileSectionAbout), findsOneWidget);
      expect(find.text('Manisa\'da aile fırınıyız.'), findsOneWidget);
    });

    testWidgets('başkası + bio boş → bölüm hiç görünmez', (tester) async {
      await tester.pumpWidget(_wrap(bio: null, isSelf: false));
      expect(find.text(AppStrings.profileSectionAbout), findsNothing);
      expect(find.text(AppStrings.profileAboutTitleSelf), findsNothing);
      expect(find.text(AppStrings.profileAboutAddCta), findsNothing);
    });

    testWidgets('self + bio boş → "Kısa tanıtım ekle" CTA, tıklanır',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        bio: '   ',
        isSelf: true,
        onAddBio: () => tapped = true,
      ));
      final cta = find.text(AppStrings.profileAboutAddCta);
      expect(cta, findsOneWidget);
      await tester.tap(cta);
      expect(tapped, isTrue);
    });
  });
}
