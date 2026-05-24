// Sprint 6A — DealerShellScreen widget testleri.
//
// Mini-app shell: default tab Genel Bakış, 5 tab, Bayiler tab mevcut
// DealerListScreen'i embedler, toptancı /wholesale/customers'a redirect.

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
        // Toptancı redirect hedef sayfası — minimal stub.
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
  group('DealerShellScreen — render & default tab', () {
    testWidgets('Bireysel: shell render, default tab Genel Bakış',
        (tester) async {
      await tester.pumpWidget(_wrap(_individualProfile));
      await tester.pumpAndSettle();

      // PremiumBottomNav + 5 tab label bulunur
      expect(find.byType(PremiumBottomNav), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PremiumBottomNav),
          matching: find.text(AppStrings.dealerShellTabOverview),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PremiumBottomNav),
          matching: find.text(AppStrings.dealerShellTabDealers),
        ),
        findsOneWidget,
      );

      // Default tab Genel Bakış — karşılama metni görünür
      expect(
        find.text(AppStrings.dealerShellOverviewWelcomeBody),
        findsOneWidget,
      );
      expect(find.text(AppStrings.dealerShellTitle), findsOneWidget);
    });

    testWidgets('Ticari: shell render, default tab Genel Bakış', (tester) async {
      await tester.pumpWidget(_wrap(_commercialProfile));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumBottomNav), findsOneWidget);
      expect(
        find.text(AppStrings.dealerShellOverviewWelcomeBody),
        findsOneWidget,
      );
    });

    testWidgets('Toptancı: shell hiç görünmez, /wholesale/customers\'a redirect',
        (tester) async {
      await tester.pumpWidget(_wrap(_wholesalerProfile));
      await tester.pumpAndSettle();

      // Redirect tamamlanmış olmalı — stub sayfa metni görünür
      expect(find.text('Müşteriler — stub'), findsOneWidget);
      // Shell hiç render edilmemiş olmalı
      expect(find.byType(PremiumBottomNav), findsNothing);
    });
  });

  group('DealerShellScreen — tab navigation', () {
    testWidgets('Bayiler tab → embedded DealerListScreen', (tester) async {
      await tester.pumpWidget(_wrap(_individualProfile));
      await tester.pumpAndSettle();

      // İlk açılışta DealerListScreen IndexedStack içinde mevcut ama
      // offstage (default tab Genel Bakış). skipOffstage: false ile ara.
      expect(
        find.byType(DealerListScreen, skipOffstage: false),
        findsOneWidget,
      );

      // Bayiler tab'a geç
      await _tapNavTab(tester, AppStrings.dealerShellTabDealers);

      // DealerListScreen'in kendi AppBar başlığı görünür ("Bayi Yönetimi")
      expect(find.text(AppStrings.dealerListTitle), findsOneWidget);
    });

    testWidgets('Hareketler tab → placeholder', (tester) async {
      await tester.pumpWidget(_wrap(_individualProfile));
      await tester.pumpAndSettle();

      await _tapNavTab(tester, AppStrings.dealerShellTabActivity);

      // AppBar başlığı + placeholder body
      expect(
        find.text(AppStrings.dealerShellPlaceholderActivityBody),
        findsOneWidget,
      );
    });

    testWidgets('Raporlar tab → placeholder', (tester) async {
      await tester.pumpWidget(_wrap(_individualProfile));
      await tester.pumpAndSettle();

      await _tapNavTab(tester, AppStrings.dealerShellTabReports);

      expect(
        find.text(AppStrings.dealerShellPlaceholderReportsBody),
        findsOneWidget,
      );
    });

    testWidgets('Gün Sonu tab → placeholder', (tester) async {
      await tester.pumpWidget(_wrap(_individualProfile));
      await tester.pumpAndSettle();

      await _tapNavTab(tester, AppStrings.dealerShellTabEndOfDay);

      expect(
        find.text(AppStrings.dealerShellPlaceholderEndOfDayBody),
        findsOneWidget,
      );
    });

    testWidgets('Genel Bakış tab içeriği — 4 upcoming item', (tester) async {
      await tester.pumpWidget(_wrap(_individualProfile));
      await tester.pumpAndSettle();

      // 4 planlanan özellik chip'i: Günlük özet / Hızlı eylemler /
      // Son hareketler / Açık alacaklar
      expect(
        find.text(AppStrings.dealerShellOverviewUpcomingSummary),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerShellOverviewUpcomingQuickActions),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerShellOverviewUpcomingRecentActivity),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerShellOverviewUpcomingOpenBalance),
        findsOneWidget,
      );
    });
  });

  group('DealerShellScreen — IndexedStack state preservation', () {
    testWidgets('Tab geçişlerinde tüm child\'lar widget tree\'de kalır',
        (tester) async {
      await tester.pumpWidget(_wrap(_individualProfile));
      await tester.pumpAndSettle();

      // İlk açılışta default Genel Bakış aktif — DealerListScreen offstage
      // (IndexedStack onu Offstage ile gizler).
      expect(
        find.byType(DealerListScreen, skipOffstage: false),
        findsOneWidget,
      );

      // Bayiler tab → Hareketler → tekrar Bayiler
      await _tapNavTab(tester, AppStrings.dealerShellTabDealers);
      expect(find.text(AppStrings.dealerListTitle), findsOneWidget);

      await _tapNavTab(tester, AppStrings.dealerShellTabActivity);
      // Activity tab'da Bayiler tekrar offstage — yine widget tree'de
      expect(
        find.byType(DealerListScreen, skipOffstage: false),
        findsOneWidget,
      );

      await _tapNavTab(tester, AppStrings.dealerShellTabDealers);
      expect(find.byType(DealerListScreen), findsOneWidget);
      expect(find.text(AppStrings.dealerListTitle), findsOneWidget);
    });
  });
}
