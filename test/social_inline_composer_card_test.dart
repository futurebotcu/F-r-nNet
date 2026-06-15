// Feed Premium Sprint — InlineComposerCard widget testleri.
//
// Twitter/FB tarzı inline composer: üstte avatar + "Bugün ne ürettin?"
// placeholder, altta Medya / Soru / Tarif / Duyuru aksiyonları + Paylaş.
// Medya → modal action sheet (Foto çek / galeriden seç / video çek/seç).
// Soru/Tarif/Duyuru composer'a tür ön-seçimiyle push eder.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/guest_mode_provider.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/social/composer/inline_composer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const BakeryProfile _individualProfile = BakeryProfile(
  displayName: 'Ali Usta',
  accountType: AccountType.individual,
  city: 'Konya',
  roleBadge: 'Usta Fırıncı',
  email: 'ali@example.com',
);

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

GoRouter _testRouter() => GoRouter(
      initialLocation: '/feed',
      routes: [
        GoRoute(
          path: '/feed',
          builder: (_, __) => const Scaffold(
            body: InlineComposerCard(),
          ),
        ),
        GoRoute(
          path: '/social/composer',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('COMPOSER-STUB')),
          ),
        ),
      ],
    );

Widget _wrap({
  required GoRouter router,
  BakeryProfile? profile,
  bool isGuest = false,
}) {
  return ProviderScope(
    overrides: [
      if (profile != null)
        profileControllerProvider.overrideWith(
          (ref) => _SeededProfileController(ref, profile),
        ),
      currentAuthUserProvider.overrideWith((_) => null),
      // canWriteCheck için: isGuest true ise guest mode set edilir →
      // canWriteWithRef false döner → showAuthRequiredSheet açılır.
      guestModeProvider.overrideWith(
        (_) => GuestModeNotifier()..setGuest(isGuest),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('InlineComposerCard — render', () {
    testWidgets('Placeholder + Medya/Soru/Tarif/Duyuru + Paylaş görünür',
        (tester) async {
      await tester.pumpWidget(_wrap(
        router: _testRouter(),
        profile: _individualProfile,
      ));
      await tester.pumpAndSettle();

      // Placeholder
      expect(
        find.text(AppStrings.composerPlaceholderIndividual),
        findsOneWidget,
      );
      // Tek "Medya" aksiyonu — 4 ayrı foto/video butonu DEĞİL.
      expect(find.text(AppStrings.feedComposerActionMedia), findsOneWidget);
      expect(find.text(AppStrings.feedComposerActionQuestion), findsOneWidget);
      expect(find.text(AppStrings.feedComposerActionRecipe), findsOneWidget);
      expect(
        find.text(AppStrings.feedComposerActionAnnouncement),
        findsOneWidget,
      );
      expect(find.text(AppStrings.feedComposerActionShare), findsOneWidget);

      // Medya alt seçenekleri ana ekranda görünmemeli (sheet'e taşındı).
      expect(find.text(AppStrings.mediaSheetCapturePhoto), findsNothing);
      expect(find.text(AppStrings.mediaSheetPickVideo), findsNothing);
    });

    testWidgets('Avatar — kullanıcı initial display name ilk harfi',
        (tester) async {
      await tester.pumpWidget(_wrap(
        router: _testRouter(),
        profile: _individualProfile, // displayName "Ali Usta" → "A"
      ));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('Profile yokken avatar fallback "M"', (tester) async {
      await tester.pumpWidget(_wrap(
        router: _testRouter(),
        profile: null,
      ));
      await tester.pumpAndSettle();
      expect(find.text('M'), findsOneWidget);
    });
  });

  group('InlineComposerCard — interaction', () {
    testWidgets(
        'Placeholder tap → /social/composer route push (canWrite=true)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        router: _testRouter(),
        profile: _individualProfile,
        isGuest: false,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.composerPlaceholderIndividual));
      await tester.pumpAndSettle();

      expect(find.text('COMPOSER-STUB'), findsOneWidget);
    });

    testWidgets(
        'Soru aksiyonu tap → /social/composer route push',
        (tester) async {
      await tester.pumpWidget(_wrap(
        router: _testRouter(),
        profile: _individualProfile,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.feedComposerActionQuestion));
      await tester.pumpAndSettle();

      expect(find.text('COMPOSER-STUB'), findsOneWidget);
    });

    testWidgets(
        'Medya tap → modal action sheet 4 seçenekle açılır (canWrite=true)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        router: _testRouter(),
        profile: _individualProfile,
        isGuest: false,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.feedComposerActionMedia));
      await tester.pumpAndSettle();

      // Action sheet açıldı: 4 mevcut işlev seçeneği görünür.
      expect(find.text(AppStrings.mediaSheetTitle), findsOneWidget);
      expect(find.text(AppStrings.mediaSheetCapturePhoto), findsOneWidget);
      expect(find.text(AppStrings.mediaSheetPickPhoto), findsOneWidget);
      expect(find.text(AppStrings.mediaSheetCaptureVideo), findsOneWidget);
      expect(find.text(AppStrings.mediaSheetPickVideo), findsOneWidget);
      // Composer'a henüz gidilmedi (seçenek seçilince gidilir).
      expect(find.text('COMPOSER-STUB'), findsNothing);
    });

    testWidgets(
        'Guest tap → route push EDİLMEZ (auth guard tetiklenir)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        router: _testRouter(),
        profile: _individualProfile,
        isGuest: true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.composerPlaceholderIndividual));
      await tester.pumpAndSettle();

      // Auth required sheet açılır; composer stub'a yönlenmez.
      expect(find.text('COMPOSER-STUB'), findsNothing);
    });
  });
}
