// BÖLÜM 1 — Bireysel kullanıcı kişisel Bayi Defteri davranışı.
//
// Regresyon: individual + aktif şoför ataması YOK iken /dealers her zaman
// DriverHomeScreen'e düşüyordu. Düzeltme: individual yalnız AKTİF şoförse
// driverScoped; aksi halde owner (kişisel defter). Şoförler tabı yalnız patron.

import 'package:firin_defter/core/widgets/premium/premium_bottom_nav.dart';
import 'package:firin_defter/features/dealers/models/dealer_driver_invite.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_shell_screen.dart';
import 'package:firin_defter/features/dealers/screens/driver_home_screen.dart';
import 'package:firin_defter/features/dealers/screens/driver_list_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

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

final _invite = DealerDriverInvite(
  id: 'inv1',
  invitedUserId: 'u1',
  driverName: 'Ali',
  status: DealerDriverInviteStatus.pending,
  createdAt: DateTime(2026, 1, 1),
  ownerName: 'Hasan Fırın',
);

GoRouter _router() => GoRouter(
      initialLocation: '/dealers',
      routes: [
        GoRoute(
          path: '/dealers',
          builder: (_, __) => const DealerShellScreen(),
        ),
      ],
    );

Widget _wrap(
  BakeryProfile profile, {
  bool activeDriver = false,
  List<DealerDriverInvite> invites = const [],
}) =>
    ProviderScope(
      overrides: [
        profileControllerProvider
            .overrideWith((ref) => _SeededProfileController(ref, profile)),
        individualActiveDriverProvider.overrideWith((ref) async => activeDriver),
        dealerRepositoryProvider
            .overrideWithValue(LocalDealerRepository(seed: true)),
        myDriverInvitesProvider.overrideWith((ref) async => invites),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    );

Finder _navLabel(String l) => find.descendant(
    of: find.byType(PremiumBottomNav), matching: find.text(l));

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  Future<void> pump(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    await tester.pumpAndSettle();
  }

  group('dealerShellModeProvider', () {
    Future<DealerShellMode> modeFor(
      BakeryProfile p, {
      bool activeDriver = false,
    }) async {
      final c = ProviderContainer(overrides: [
        profileControllerProvider
            .overrideWith((ref) => _SeededProfileController(ref, p)),
        individualActiveDriverProvider
            .overrideWith((ref) async => activeDriver),
      ]);
      addTearDown(c.dispose);
      await c.read(individualActiveDriverProvider.future);
      return c.read(dealerShellModeProvider);
    }

    test('individual + aktif şoför DEĞİL → owner (kişisel defter)', () async {
      expect(await modeFor(_individual, activeDriver: false),
          DealerShellMode.owner);
    });
    test('individual + aktif şoför → driverScoped', () async {
      expect(await modeFor(_individual, activeDriver: true),
          DealerShellMode.driverScoped);
    });
    test('commercial → owner', () async {
      expect(await modeFor(_commercial), DealerShellMode.owner);
    });
    test('wholesaler → owner', () async {
      expect(await modeFor(_wholesaler), DealerShellMode.owner);
    });
  });

  group('DealerShellScreen — rol davranışı', () {
    testWidgets('individual + aktif şoför yok → kişisel defter, Şoförler yok',
        (tester) async {
      await pump(tester, _wrap(_individual, activeDriver: false));
      expect(find.byType(DriverHomeScreen), findsNothing); // şoför ekranı DEĞİL
      expect(_navLabel('Genel Bakış'), findsOneWidget);
      expect(_navLabel('Bayiler'), findsOneWidget);
      expect(_navLabel('Şoförler'), findsNothing); // patron tabı yok
      expect(find.byType(DriverListScreen), findsNothing);
    });

    testWidgets('individual + bekleyen davet → defter + davet banner',
        (tester) async {
      await pump(tester, _wrap(_individual, invites: [_invite]));
      expect(find.byType(MyDriverInvitesCard), findsOneWidget);
      expect(find.text('Kabul Et'), findsOneWidget);
      // Kişisel defter KAYBOLMADI:
      expect(_navLabel('Bayiler'), findsOneWidget);
      expect(_navLabel('Şoförler'), findsNothing);
    });

    testWidgets('commercial → patron shell (Şoförler tabı var)',
        (tester) async {
      await pump(tester, _wrap(_commercial));
      expect(_navLabel('Şoförler'), findsOneWidget);
      expect(_navLabel('Bayiler'), findsOneWidget);
    });

    testWidgets('wholesaler → patron shell (Şoförler + Müşteriler)',
        (tester) async {
      await pump(tester, _wrap(_wholesaler));
      expect(_navLabel('Şoförler'), findsOneWidget);
      expect(_navLabel('Müşteriler'), findsOneWidget);
    });
  });
}
