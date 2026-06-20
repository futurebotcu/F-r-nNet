// DealerShellScreen widget testleri (UI placement güncellemesi sonrası).
//
// Ürün modeli: bireysel = ŞOFÖR → "Şoför Paneli" görünümü (patron shell
// DEĞİL). Ticari (commercial) → patron shell (5 tab: Genel Bakış/Bayiler/
// Hareketler/Raporlar/Şoförler; Gün Sonu Raporlar içine taşındı). Toptancı →
// AYNI shell (fix/wholesaler-dealer-shell-parity): liste tabı "Müşteriler" +
// wholesale_customer scope, redirect YOK.

import 'package:intl/date_symbol_data_local.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/premium/premium_bottom_nav.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/screens/dealer_list_screen.dart';
import 'package:firin_defter/features/dealers/screens/dealer_shell_screen.dart';
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

const _commercialProfile = BakeryProfile(
  displayName: 'Hasan Usta',
  accountType: AccountType.commercial,
  city: 'Konya',
  roleBadge: 'Fırıncı',
  email: 'hasan@example.com',
);

const _individualProfile = BakeryProfile(
  displayName: 'Ali Usta',
  accountType: AccountType.individual,
  city: 'Konya',
  roleBadge: 'Usta Fırıncı',
  email: 'ali@example.com',
);

const _wholesalerProfile = BakeryProfile(
  displayName: 'Hasat Bakery',
  accountType: AccountType.wholesaler,
  city: 'Konya',
  roleBadge: 'Toptancı',
  email: 'hasat@example.com',
);

GoRouter _testRouter() => GoRouter(
      initialLocation: '/dealers',
      routes: [
        GoRoute(
          path: '/dealers',
          builder: (_, __) => const DealerShellScreen(),
        ),
        GoRoute(
          path: '/wholesale/customers',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('Müşteriler — stub')),
          ),
        ),
      ],
    );

Widget _wrap(BakeryProfile profile) {
  return ProviderScope(
    overrides: [
      dealerRepositoryProvider
          .overrideWithValue(LocalDealerRepository(seed: true)),
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, profile),
      ),
    ],
    child: MaterialApp.router(routerConfig: _testRouter()),
  );
}

Future<void> _tapNavTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
    of: find.byType(PremiumBottomNav),
    matching: find.text(label),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  group('DealerShellScreen — rol gating', () {
    testWidgets('Ticari: patron shell render, default tab Genel Bakış',
        (tester) async {
      await tester.pumpWidget(_wrap(_commercialProfile));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumBottomNav), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PremiumBottomNav),
          matching: find.text(AppStrings.dealerShellTabOverview),
        ),
        findsOneWidget,
      );
      // Şoförler tabı patron (ticari) için görünür.
      expect(
        find.descendant(
          of: find.byType(PremiumBottomNav),
          matching: find.text('Şoförler'),
        ),
        findsOneWidget,
      );
      // Gün Sonu artık ayrı tab DEĞİL.
      expect(
        find.descendant(
          of: find.byType(PremiumBottomNav),
          matching: find.text(AppStrings.dealerShellTabEndOfDay),
        ),
        findsNothing,
      );
      expect(
        find.text(AppStrings.dealerOverviewKpiOpenBalance.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('Bireysel: şoför görünümü (patron shell DEĞİL)',
        (tester) async {
      await tester.pumpWidget(_wrap(_individualProfile));
      await tester.pumpAndSettle();

      // Atama yok (currentUserId set değil) → henüz atanmamış şoför: başlık
      // "Bayi Yönetimi", "Şoför Paneli" yok, patron bottom-nav yok.
      expect(find.text('Bayi Yönetimi'), findsOneWidget);
      expect(find.text('Şoför Paneli'), findsNothing);
      expect(find.byType(PremiumBottomNav), findsNothing);
    });

    testWidgets(
        'Toptancı: AYNI shell render (redirect YOK), liste tabı "Müşteriler"',
        (tester) async {
      await tester.pumpWidget(_wrap(_wholesalerProfile));
      await tester.pumpAndSettle();

      // Parity: eski redirect kaldırıldı → shell + bottom-nav görünür.
      expect(find.text('Müşteriler — stub'), findsNothing);
      expect(find.byType(PremiumBottomNav), findsOneWidget);

      // Liste tabı "Müşteriler" etiketiyle; "Bayiler" görünmez.
      expect(
        find.descendant(
          of: find.byType(PremiumBottomNav),
          matching: find.text('Müşteriler'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PremiumBottomNav),
          matching: find.text(AppStrings.dealerShellTabDealers),
        ),
        findsNothing,
      );
      // Şoförler tabı toptancıda açık (owner).
      expect(
        find.descendant(
          of: find.byType(PremiumBottomNav),
          matching: find.text('Şoförler'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'Toptancı: Müşteriler tabı wholesale_customer scope (bakery sızmaz)',
        (tester) async {
      await tester.pumpWidget(_wrap(_wholesalerProfile));
      await tester.pumpAndSettle();

      await _tapNavTab(tester, 'Müşteriler');
      // Seed yalnız bakery_dealer içerir → toptancı scope'unda görünmez.
      expect(find.text('Köşe Pide Evi'), findsNothing);
      // Liste ekranı toptancı dilinde başlıkla render olur.
      expect(find.text('Müşteriler'), findsAtLeastNWidgets(1));
    });
  });

  group('DealerShellScreen — patron tab navigation (ticari)', () {
    testWidgets('Bayiler tab → embedded DealerListScreen', (tester) async {
      await tester.pumpWidget(_wrap(_commercialProfile));
      await tester.pumpAndSettle();

      expect(
        find.byType(DealerListScreen, skipOffstage: false),
        findsOneWidget,
      );
      await _tapNavTab(tester, AppStrings.dealerShellTabDealers);
      expect(find.text(AppStrings.dealerListTitle), findsOneWidget);
    });

    testWidgets('Hareketler tab → activity screen', (tester) async {
      await tester.pumpWidget(_wrap(_commercialProfile));
      await tester.pumpAndSettle();
      await _tapNavTab(tester, AppStrings.dealerShellTabActivity);
      expect(find.text(AppStrings.dealerActivityTitle), findsAtLeastNWidgets(1));
      expect(find.text(AppStrings.dealerActivitySearchHint), findsOneWidget);
    });

    testWidgets('Raporlar tab → rapor + Gün Sonu kartı', (tester) async {
      await tester.pumpWidget(_wrap(_commercialProfile));
      await tester.pumpAndSettle();
      await _tapNavTab(tester, AppStrings.dealerShellTabReports);
      expect(find.text(AppStrings.dealerReportsPeriodLast30), findsOneWidget);
      // Gün Sonu artık Raporlar içinde bir kart.
      expect(find.text('Gün Sonu'), findsOneWidget);
    });

    testWidgets('Şoförler tab → DriverListScreen (Genel Hesap)',
        (tester) async {
      await tester.pumpWidget(_wrap(_commercialProfile));
      await tester.pumpAndSettle();
      await _tapNavTab(tester, 'Şoförler');
      // Şoför yönetim listesi: Genel Hesap kartı + Şoför Ekle.
      expect(find.text('Genel Hesap'), findsOneWidget);
      expect(find.text('Şoför Ekle'), findsAtLeastNWidgets(1));
    });
  });

  group('DealerShellScreen — IndexedStack state preservation (ticari)', () {
    testWidgets('Tab geçişlerinde child\'lar widget tree\'de kalır',
        (tester) async {
      await tester.pumpWidget(_wrap(_commercialProfile));
      await tester.pumpAndSettle();

      expect(
        find.byType(DealerListScreen, skipOffstage: false),
        findsOneWidget,
      );
      await _tapNavTab(tester, AppStrings.dealerShellTabDealers);
      expect(find.text(AppStrings.dealerListTitle), findsOneWidget);
      await _tapNavTab(tester, AppStrings.dealerShellTabActivity);
      expect(
        find.byType(DealerListScreen, skipOffstage: false),
        findsOneWidget,
      );
      await _tapNavTab(tester, AppStrings.dealerShellTabDealers);
      expect(find.text(AppStrings.dealerListTitle), findsOneWidget);
    });
  });
}
