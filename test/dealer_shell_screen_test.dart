// Sprint 6A — DealerShellScreen widget testleri.
//
// Mini-app shell: default tab Genel Bakış, 5 tab, Bayiler tab mevcut
// DealerListScreen'i embedler, toptancı /wholesale/customers'a redirect.

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
  setUpAll(() async {
    // IndexedStack tüm tab'ları build eder; DealerActivityScreen
    // DateFormat('d MMM', 'tr_TR') kullandığı için locale init şart.
    await initializeDateFormatting('tr_TR', null);
  });

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

      // Default tab Genel Bakış — Sprint 6B'den sonra DealerOverviewScreen
      // render edilir; AKTİF BAYİ chip ve KPI label'ları görünür.
      expect(
        find.text(AppStrings.dealerOverviewActiveDealersLabel),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerOverviewKpiOpenBalance.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('Ticari: shell render, default tab Genel Bakış', (tester) async {
      await tester.pumpWidget(_wrap(_commercialProfile));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumBottomNav), findsOneWidget);
      expect(
        find.text(AppStrings.dealerOverviewKpiOpenBalance.toUpperCase()),
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

    testWidgets('Hareketler tab → activity screen (Sprint Activity)',
        (tester) async {
      await tester.pumpWidget(_wrap(_individualProfile));
      await tester.pumpAndSettle();

      await _tapNavTab(tester, AppStrings.dealerShellTabActivity);

      // Sprint Activity: placeholder yerine gerçek DealerActivityScreen.
      // AppBar başlığı + search hint + filter chip "Tümü" görünür.
      expect(
        find.text(AppStrings.dealerActivityTitle),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.text(AppStrings.dealerActivitySearchHint),
        findsOneWidget,
      );
    });

    testWidgets('Raporlar tab → DealerReportsTabScreen içerik', (tester) async {
      await tester.pumpWidget(_wrap(_individualProfile));
      await tester.pumpAndSettle();

      await _tapNavTab(tester, AppStrings.dealerShellTabReports);

      // Periyot segmenti + Genel Toplam başlığı görünür (artık placeholder yok).
      expect(find.text(AppStrings.dealerReportsPeriodLast30), findsOneWidget);
      expect(
        find.text(AppStrings.dealerReportsSummaryTitle.toUpperCase()),
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

    testWidgets('Genel Bakış tab içeriği — KPI labels (Sprint 6B)',
        (tester) async {
      await tester.pumpWidget(_wrap(_individualProfile));
      await tester.pumpAndSettle();

      // Sprint 6B: 5 KPI tile label'ı görünür (placeholder upcoming items
      // kaldırıldı, gerçek DealerOverviewScreen render edilir)
      expect(
        find.text(AppStrings.dealerOverviewKpiOpenBalance.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerOverviewKpiTodayDelivery.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerOverviewKpiTodayPayment.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerOverviewKpiMonthNetChange.toUpperCase()),
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
