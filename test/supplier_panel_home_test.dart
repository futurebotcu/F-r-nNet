// Tedarikçi Paneli S1 — Panel ana ekranı (SupplierPanelHome) testleri.
//
// Kapsam: tamamlanma hesabı, kampanya süresi, Pazar sekme çözümü, wholesaler
// Panel kartları (yanlış hedefler kalktı), widget durumları (mağaza var /
// yok / hata), paywall aynası, dar ekran + büyük yazı taşma kontrolü.

import 'package:firin_defter/app/router/app_router.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/error_retry_state.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_campaign.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_product.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_store.dart';
import 'package:firin_defter/features/b2b_market/models/supplier_requests_inbox.dart';
import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/screens/b2b_shell_screen.dart';
import 'package:firin_defter/features/dashboard/screens/role_dashboard_screen.dart';
import 'package:firin_defter/features/dashboard/services/role_panel_cards.dart';
import 'package:firin_defter/features/dashboard/widgets/supplier_panel_home.dart';
import 'package:firin_defter/features/messaging/providers/messaging_providers.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _WholesalerProfile extends ProfileController {
  _WholesalerProfile(super.ref) {
    state = const BakeryProfile(
      displayName: 'Anadolu Un',
      accountType: AccountType.wholesaler,
      city: 'Konya',
      roleBadge: 'Toptancı',
      email: 't@t.com',
    );
  }
}

/// Mağazası henüz olmayan tedarikçi (Supabase myStore boş vitrin döner).
class _NoStoreRepo extends LocalB2bRepository {
  @override
  Future<B2bStore> myStore() async => const B2bStore(
    id: '',
    name: '',
    monogram: '?',
    tagline: '',
    description: '',
    categories: [],
    serviceRegions: [],
    productCount: 0,
    campaignCount: 0,
    isMine: true,
  );
}

Future<void> _setSurface(
  WidgetTester tester, {
  double width = 320,
  double height = 2400,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

List<FlutterErrorDetails> _captureOverflows() {
  final overflows = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) {
      overflows.add(details);
    } else {
      // Taşma dışı hatalar sessizce yutulmasın — logda görünsün.
      debugPrint('[test] non-overflow error: ${details.exceptionAsString()}');
      previous?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
  return overflows;
}

Widget _panel({
  List<Override> extra = const [],
  BusinessPlan plan = BusinessPlan.premium,
}) {
  return ProviderScope(
    overrides: [
      profileControllerProvider.overrideWith((ref) => _WholesalerProfile(ref)),
      totalUnreadMessagesProvider.overrideWith((ref) => 0),
      subscriptionRepositoryProvider.overrideWithValue(
        LocalSubscriptionRepository(plan: plan),
      ),
      b2bRepositoryProvider.overrideWithValue(LocalB2bRepository()),
      ...extra,
    ],
    child: const MaterialApp(home: RoleDashboardScreen()),
  );
}

B2bProduct _product({bool published = true}) => B2bProduct(
  id: 'p',
  name: 'Un',
  supplierId: 's1',
  supplierName: 'X',
  category: 'Un',
  minOrder: '-',
  deliveryRegion: '-',
  published: published,
  isMine: true,
);

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('SupplierStoreCompletion', () {
    test('5 adım: logo/açıklama/bölge/kategori/yayında ürün', () {
      const empty = B2bStore(
        id: 's',
        name: 'A',
        monogram: 'A',
        tagline: '',
        description: '',
        categories: [],
        serviceRegions: [],
        productCount: 0,
        campaignCount: 0,
      );
      final c0 = SupplierStoreCompletion.of(empty, const []);
      expect(c0.done, 0);
      expect(c0.total, 5);
      expect(c0.complete, isFalse);

      const full = B2bStore(
        id: 's',
        name: 'A',
        monogram: 'A',
        tagline: '',
        description: 'Açıklama',
        categories: ['Un'],
        serviceRegions: ['Marmara'],
        productCount: 1,
        campaignCount: 0,
        logoUrl: 'https://x/logo.png',
      );
      // Taslak ürün "yayında ürün" adımını saymaz.
      final c4 = SupplierStoreCompletion.of(full, [_product(published: false)]);
      expect(c4.done, 4);
      final c5 = SupplierStoreCompletion.of(full, [_product()]);
      expect(c5.done, 5);
      expect(c5.complete, isTrue);
      expect(c5.ratio, 1.0);
    });
  });

  group('B2bCampaign.isExpiredAt', () {
    B2bCampaign c(String until) => B2bCampaign(
      id: 'c',
      title: 'K',
      supplierId: 's1',
      supplierName: 'X',
      category: 'Un',
      region: '-',
      minPurchase: '-',
      validUntil: until,
    );
    final now = DateTime(2026, 10, 16, 15);

    test('ISO tarih dünse süresi dolmuş, bugün/yarınsa dolmamış', () {
      expect(c('2026-10-15').isExpiredAt(now), isTrue);
      expect(c('2026-10-16').isExpiredAt(now), isFalse);
      expect(c('2026-10-17').isExpiredAt(now), isFalse);
    });

    test('"Süresiz" ve serbest metin asla süresi dolmuş sayılmaz', () {
      expect(c('Süresiz').isExpiredAt(now), isFalse);
      expect(c('30 Haziran 2026').isExpiredAt(now), isFalse);
      expect(c('').isExpiredAt(now), isFalse);
    });

    test('isActive = published && !expired', () {
      expect(c('2030-01-01').isActive, isTrue);
      expect(c('2020-01-01').isActive, isFalse);
      expect(c('Süresiz').copyWith(published: false).isActive, isFalse);
    });
  });

  group('B2bShellScreen.resolveTab (?tab=)', () {
    test('tedarikçi anahtarları sırayla; bilinmeyen/null → 0', () {
      expect(B2bShellScreen.resolveTab(null, isSupplier: true), 0);
      expect(B2bShellScreen.resolveTab('magazam', isSupplier: true), 0);
      expect(B2bShellScreen.resolveTab('urunler', isSupplier: true), 1);
      expect(B2bShellScreen.resolveTab('kampanyalar', isSupplier: true), 2);
      expect(B2bShellScreen.resolveTab('talepler', isSupplier: true), 3);
      expect(B2bShellScreen.resolveTab('yok', isSupplier: true), 0);
    });

    test('alıcı anahtarları', () {
      expect(B2bShellScreen.resolveTab('tekliflerim', isSupplier: false), 3);
      expect(B2bShellScreen.resolveTab('talepler', isSupplier: false), 0);
    });

    test('AppRoutes.pazarTab query üretir', () {
      expect(
        AppRoutes.pazarTab(AppRoutes.pazarTabRequests),
        '/pazar?tab=talepler',
      );
      expect(AppRoutes.pazarTab(AppRoutes.pazarTabStore), '/pazar?tab=magazam');
    });
  });

  group('Wholesaler panel kartları (S1)', () {
    test('yanlış hedefler ve "Yakında" kartı kalktı; Müşteriler ilk kart', () {
      final cards = RolePanelCards.forAccount(AccountType.wholesaler);
      final routes = cards.map((c) => c.route).whereType<String>().toList();
      expect(cards.first.route, AppRoutes.dealers);
      expect(cards.first.label, AppStrings.cardWholesaleCustomersPanel);
      expect(routes, contains(AppRoutes.messages));
      expect(routes, contains(AppRoutes.partners));
      // Ekipman ilan formu (B2B ürün değildi) ve sosyal profil (mağaza
      // değildi) artık panel kartı değil; B2B girişleri SupplierPanelHome'da.
      expect(routes, isNot(contains(AppRoutes.marketListingNew)));
      expect(routes, isNot(contains(AppRoutes.profile)));
      expect(cards.any((c) => c.comingSoon), isFalse);
      // Ticari/bireysel listeler değişmedi.
      expect(
        RolePanelCards.forAccount(AccountType.commercial).first.route,
        AppRoutes.bakeryPanel,
      );
      expect(
        RolePanelCards.forAccount(AccountType.individual).first.route,
        AppRoutes.profile,
      );
    });
  });

  group('SupplierPanelHome widget', () {
    testWidgets(
      'mağaza varken: durum kartı, 4 KPI, 4 hızlı işlem, kart listesi',
      (tester) async {
        await _setSurface(tester, width: 360);
        await tester.pumpWidget(_panel());
        await tester.pumpAndSettle();

        expect(find.byType(SupplierPanelHome), findsOneWidget);
        expect(
          find.byKey(const ValueKey('supplier_panel_store_card')),
          findsOneWidget,
        );
        expect(find.text('Anadolu Un & Maya'), findsOneWidget);
        for (final k in const [
          'supplier_kpi_requests',
          'supplier_kpi_products',
          'supplier_kpi_campaigns',
          'supplier_kpi_leads',
          'supplier_quick_add_product',
          'supplier_quick_add_campaign',
          'supplier_quick_requests',
          'supplier_quick_edit_store',
        ]) {
          expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
        }
        expect(find.text(AppStrings.supPanelSectionStore), findsOneWidget);
        expect(find.text(AppStrings.supPanelSectionKpi), findsOneWidget);
        expect(find.text(AppStrings.supPanelSectionQuick), findsOneWidget);
        expect(find.text(AppStrings.supPanelSectionTools), findsOneWidget);
        // Boş vaat / yanlış hedef kartları yok.
        expect(find.text('Duyuru / Fiyat Listesi'), findsNothing);
        expect(find.text('Ürün/Hizmet İlanı Ver'), findsNothing);
        expect(find.text('Firma Profilim'), findsNothing);
        expect(find.text(AppStrings.comingSoon), findsNothing);
        // Diğer araçlar kartları duruyor.
        expect(
          find.text(AppStrings.cardWholesaleCustomersPanel),
          findsOneWidget,
        );
        expect(find.text(AppStrings.cardIncomingMessages), findsOneWidget);
        // S2: "Yanıt bekleyen" = yanıtlamadığım aktif talepler (gelen kutusu).
        final seed = LocalB2bRepository();
        final box = SupplierRequestsInbox.build(
          openRequests: await seed.listOpenQuoteRequests(),
          myReplies: await seed.listMyQuoteReplies(),
          leads: await seed.leadsForMySupplierShop(),
        );
        expect(box.fresh, isNotEmpty);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('supplier_kpi_requests')),
            matching: find.text('${box.fresh.length}'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('mağaza yokken: tek CTA kartı, durum kartı yok', (
      tester,
    ) async {
      await _setSurface(tester, width: 360);
      await tester.pumpWidget(
        _panel(
          extra: [b2bRepositoryProvider.overrideWithValue(_NoStoreRepo())],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('supplier_panel_no_store')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('supplier_panel_no_store_cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('supplier_panel_store_card')),
        findsNothing,
      );
      expect(find.text(AppStrings.supPanelOpenStore), findsNothing);
      // KPI ve hızlı işlemler yine var (ürün ekle vb. mağaza oluşturmaya götürür).
      expect(
        find.byKey(const ValueKey('supplier_kpi_products')),
        findsOneWidget,
      );
    });

    testWidgets(
      'mağaza yüklenemezse ErrorRetryState; diğer paneller etkilenmez',
      (tester) async {
        await _setSurface(tester, width: 360);
        await tester.pumpWidget(
          _panel(
            extra: [
              b2bMyStoreProvider.overrideWith(
                (ref) async => throw StateError('offline'),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('supplier_panel_error')),
          findsOneWidget,
        );
        expect(find.byType(ErrorRetryState), findsOneWidget);
        expect(find.text(AppStrings.supPanelErrorTitle), findsOneWidget);
        expect(
          find.text(AppStrings.cardWholesaleCustomersPanel),
          findsOneWidget,
        );
      },
    );

    testWidgets('Free planda ürün limiti doluysa "Ürün ekle" paywall açar', (
      tester,
    ) async {
      await _setSurface(tester, width: 360);
      // Mock seed'de s1 mağazasının ürünleri var (>= 1) → Free limit (1) dolu.
      await tester.pumpWidget(_panel(plan: BusinessPlan.free));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('supplier_quick_add_product')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paywall_sheet')), findsOneWidget);
    });

    testWidgets(
      'Free planda kampanya (limit 0) "Kampanya oluştur" paywall açar',
      (tester) async {
        await _setSurface(tester, width: 360);
        await tester.pumpWidget(_panel(plan: BusinessPlan.free));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('supplier_quick_add_campaign')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('paywall_sheet')), findsOneWidget);
      },
    );

    testWidgets('ticari ve bireysel panelde SupplierPanelHome yok', (
      tester,
    ) async {
      await _setSurface(tester, width: 360);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            totalUnreadMessagesProvider.overrideWith((ref) => 0),
            subscriptionRepositoryProvider.overrideWithValue(
              LocalSubscriptionRepository(plan: BusinessPlan.free),
            ),
          ],
          child: const MaterialApp(home: RoleDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      // Profil yok → bireysel varsayılan.
      expect(find.byType(SupplierPanelHome), findsNothing);
    });

    for (final scale in const [1.0, 1.3, 1.5]) {
      testWidgets('320px · ${scale}x taşma yok', (tester) async {
        await _setSurface(tester, textScale: scale, height: 3000);
        final overflows = _captureOverflows();
        await tester.pumpWidget(_panel());
        await tester.pumpAndSettle();
        expect(find.byType(SupplierPanelHome), findsOneWidget);
        expect(overflows, isEmpty);
      });
    }
  });
}
