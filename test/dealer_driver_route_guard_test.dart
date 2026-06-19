// PatronDriverGuard — patron şoför yönetimi route'ları deep-link hardening.
//
// Bireysel (şoför) direct /dealers/drivers'a gelse bile patron DriverListScreen
// AÇILMAZ → DriverHomeScreen ("Şoför Paneli"). Ticari/toptancı → erişir.

import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/driver_list_screen.dart';
import 'package:firin_defter/features/dealers/widgets/patron_driver_guard.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

const _commercial = BakeryProfile(
  displayName: 'Hasan', accountType: AccountType.commercial,
  city: 'Konya', roleBadge: 'Fırıncı', email: 'h@e.com',
);
const _individual = BakeryProfile(
  displayName: 'Ali', accountType: AccountType.individual,
  city: 'Konya', roleBadge: 'Usta', email: 'a@e.com',
);
const _wholesaler = BakeryProfile(
  displayName: 'Hasat', accountType: AccountType.wholesaler,
  city: 'Konya', roleBadge: 'Toptancı', email: 'w@e.com',
);

GoRouter _router() => GoRouter(
      initialLocation: '/dealers/drivers',
      routes: [
        GoRoute(
          path: '/dealers/drivers',
          builder: (_, __) =>
              const PatronDriverGuard(child: DriverListScreen()),
        ),
      ],
    );

Widget _wrap(BakeryProfile profile) => ProviderScope(
      overrides: [
        dealerRepositoryProvider
            .overrideWithValue(LocalDealerRepository(seed: true)),
        profileControllerProvider
            .overrideWith((ref) => _SeededProfileController(ref, profile)),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    );

void main() {
  testWidgets('Bireysel direct /dealers/drivers → DriverHomeScreen (patron yok)',
      (tester) async {
    await tester.pumpWidget(_wrap(_individual));
    await tester.pumpAndSettle();
    // Şoför görünümü; patron yönetim listesi DEĞİL.
    expect(find.text('Şoför Paneli'), findsOneWidget);
    expect(find.byType(DriverListScreen), findsNothing);
    expect(find.text('Genel Hesap'), findsNothing);
  });

  testWidgets('Ticari direct /dealers/drivers → DriverListScreen', (tester) async {
    await tester.pumpWidget(_wrap(_commercial));
    await tester.pumpAndSettle();
    expect(find.byType(DriverListScreen), findsOneWidget);
    expect(find.text('Genel Hesap'), findsOneWidget);
  });

  testWidgets('Toptancı direct /dealers/drivers → DriverListScreen',
      (tester) async {
    await tester.pumpWidget(_wrap(_wholesaler));
    await tester.pumpAndSettle();
    expect(find.byType(DriverListScreen), findsOneWidget);
    expect(find.text('Genel Hesap'), findsOneWidget);
  });
}
