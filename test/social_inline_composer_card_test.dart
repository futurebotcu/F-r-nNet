// Social UI Polish Sprint 1 — InlineComposerCard widget testleri.
//
// Feed'in üstünde "Ne paylaşmak istersin?" inline composer kartı.
// Tap → mevcut composer route'una push (preselect type Sprint 2'ye).

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
        // Auth required sheet'in pop sonrası ekrana dönüş için bir dummy
        // route.
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
    testWidgets('Placeholder + 3 hızlı ikon görünür', (tester) async {
      await tester.pumpWidget(_wrap(
        router: _testRouter(),
        profile: _individualProfile,
      ));
      await tester.pumpAndSettle();

      // Placeholder
      expect(
        find.text(AppStrings.feedComposerInlinePlaceholder),
        findsOneWidget,
      );
      // 3 hızlı ikon label
      expect(find.text(AppStrings.feedComposerInlineCtaPhoto), findsOneWidget);
      expect(
        find.text(AppStrings.feedComposerInlineCtaQuestion),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.feedComposerInlineCtaProduction),
        findsOneWidget,
      );
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
        'Kart tap → /social/composer route push (canWrite=true)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        router: _testRouter(),
        profile: _individualProfile,
        isGuest: false,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.feedComposerInlinePlaceholder));
      await tester.pumpAndSettle();

      expect(find.text('COMPOSER-STUB'), findsOneWidget);
    });

    testWidgets(
        'Fotoğraf hızlı ikon tap → /social/composer route push',
        (tester) async {
      await tester.pumpWidget(_wrap(
        router: _testRouter(),
        profile: _individualProfile,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.feedComposerInlineCtaPhoto));
      await tester.pumpAndSettle();

      expect(find.text('COMPOSER-STUB'), findsOneWidget);
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

      await tester.tap(find.text(AppStrings.feedComposerInlinePlaceholder));
      await tester.pumpAndSettle();

      // Auth required sheet açılır; composer stub'a yönlenmez.
      expect(find.text('COMPOSER-STUB'), findsNothing);
    });
  });
}
