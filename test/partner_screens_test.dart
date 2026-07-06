import 'dart:async';

import 'package:firin_defter/app/router/app_router.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/branches/providers/branch_providers.dart';
import 'package:firin_defter/features/branches/repositories/local_branch_repository.dart';
import 'package:firin_defter/features/dashboard/screens/role_dashboard_screen.dart';
import 'package:firin_defter/features/messaging/providers/messaging_providers.dart';
import 'package:firin_defter/features/partners/data/local_partner_business_repository.dart';
import 'package:firin_defter/features/partners/data/partner_business_repository.dart';
import 'package:firin_defter/features/partners/models/partner_business.dart';
import 'package:firin_defter/features/partners/models/partner_business_application.dart';
import 'package:firin_defter/features/partners/providers/partner_business_providers.dart';
import 'package:firin_defter/features/partners/screens/partner_business_application_screen.dart';
import 'package:firin_defter/features/partners/screens/partner_business_detail_screen.dart';
import 'package:firin_defter/features/partners/screens/partner_businesses_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Anlaşmalı İş Yerleri V1 — ekran/görünürlük testleri.
class _FixedProfileController extends ProfileController {
  _FixedProfileController(super.ref, BakeryProfile? profile) {
    state = profile;
  }
}

BakeryProfile _profile(AccountType type) => BakeryProfile(
  displayName: 'Test',
  accountType: type,
  city: 'Ankara',
  roleBadge: 'Usta',
  email: 't@t.com',
);

Widget _wrap(
  Widget home, {
  required PartnerBusinessRepository repo,
  AccountType account = AccountType.commercial,
}) {
  return ProviderScope(
    overrides: [
      partnerBusinessRepositoryProvider.overrideWithValue(repo),
      branchRepositoryProvider.overrideWithValue(LocalBranchRepository()),
      profileControllerProvider.overrideWith(
        (ref) => _FixedProfileController(ref, _profile(account)),
      ),
      totalUnreadMessagesProvider.overrideWith((ref) => 0),
    ],
    child: MaterialApp(home: home),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required PartnerBusinessRepository repo,
  AccountType account = AccountType.commercial,
  Size size = const Size(1200, 3200),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(_wrap(home, repo: repo, account: account));
  await tester.pumpAndSettle();
}

void main() {
  group('PartnerBusinessesScreen — liste durumları', () {
    testWidgets('success: kartlar + arama + filtre barı render olur', (
      tester,
    ) async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      await _pump(tester, const PartnerBusinessesScreen(), repo: repo);
      expect(find.text(AppStrings.partnersTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('partner_search')), findsOneWidget);
      expect(find.text('Fırın Makina Servis'), findsOneWidget);
      expect(find.text('Un Deposu Toptan'), findsOneWidget);
      expect(find.text('Marmara Ambalaj'), findsOneWidget);
      // Pasif kayıt hiç görünmez.
      expect(find.text('Pasif İş Yeri'), findsNothing);
      // Kart alanları: şehir/ilçe + avantaj + aksiyonlar.
      expect(find.text('Ankara / Çankaya'), findsOneWidget);
      expect(
        find.text('FırınNet üyelerine bakımda %15 indirim'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('partner_call_partner-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('partner_map_partner-1')),
        findsOneWidget,
      );
      // Telefonu olmayan kartta Ara yok.
      expect(
        find.byKey(const ValueKey('partner_call_partner-3')),
        findsNothing,
      );
    });

    testWidgets('empty: boş durum metinleri + başvuru yönlendirmesi', (
      tester,
    ) async {
      final repo = LocalPartnerBusinessRepository(); // seed yok
      await _pump(tester, const PartnerBusinessesScreen(), repo: repo);
      expect(find.text(AppStrings.partnersEmptyTitle), findsOneWidget);
      expect(find.text(AppStrings.partnersEmptyBody), findsOneWidget);
    });

    testWidgets('error: retry görünür ve yeniden dener', (tester) async {
      final repo = _FailingPartnerRepository();
      await _pump(tester, const PartnerBusinessesScreen(), repo: repo);
      expect(find.text(AppStrings.partnersListError), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text(AppStrings.retry));
      await tester.pumpAndSettle();
      expect(find.text('Fırın Makina Servis'), findsOneWidget);
    });

    testWidgets('320dp + 1.3x taşma yapmaz', (tester) async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      await _pump(
        tester,
        const PartnerBusinessesScreen(),
        repo: repo,
        size: const Size(320, 4000),
        textScale: 1.3,
      );
      expect(find.text('Fırın Makina Servis'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PartnerFilterBar — filtreleme', () {
    testWidgets('arama listeyi daraltır; temizle geri getirir', (tester) async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      await _pump(tester, const PartnerBusinessesScreen(), repo: repo);
      await tester.enterText(
        find.byKey(const ValueKey('partner_search')),
        'ambalaj',
      );
      await tester.pumpAndSettle();
      expect(find.text('Marmara Ambalaj'), findsOneWidget);
      expect(find.text('Fırın Makina Servis'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('partner_filter_clear')));
      await tester.pumpAndSettle();
      expect(find.text('Fırın Makina Servis'), findsOneWidget);
    });

    testWidgets('şehir filtresi + şehre bağlı ilçe seçenekleri', (
      tester,
    ) async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      await _pump(tester, const PartnerBusinessesScreen(), repo: repo);
      await tester.tap(find.byKey(const ValueKey('partner_filter_city')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İstanbul').last);
      await tester.pumpAndSettle();
      expect(find.text('Marmara Ambalaj'), findsOneWidget);
      expect(find.text('Un Deposu Toptan'), findsNothing);
      // İlçe seçenekleri artık yalnız İstanbul ilçeleri.
      await tester.tap(find.byKey(const ValueKey('partner_filter_district')));
      await tester.pumpAndSettle();
      expect(find.text('Bayrampaşa'), findsWidgets);
      expect(find.text('Keçiören'), findsNothing);
    });

    testWidgets('kategori filtresi çalışır', (tester) async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      await _pump(tester, const PartnerBusinessesScreen(), repo: repo);
      await tester.tap(find.byKey(const ValueKey('partner_filter_category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paketleme').last);
      await tester.pumpAndSettle();
      expect(find.text('Marmara Ambalaj'), findsOneWidget);
      expect(find.text('Fırın Makina Servis'), findsNothing);
    });
  });

  group('detay ekranı', () {
    testWidgets('rozet + avantaj + iletişim alanları doğru render olur', (
      tester,
    ) async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      await _pump(
        tester,
        const PartnerBusinessDetailScreen(partnerId: 'partner-1'),
        repo: repo,
      );
      expect(find.text(AppStrings.partnersBadge), findsOneWidget);
      expect(find.text('Fırın Makina Servis'), findsWidgets);
      expect(find.text('Teknik servis · Ankara / Çankaya'), findsOneWidget);
      expect(find.text('Sanayi Cad. No:12'), findsOneWidget);
      expect(
        find.text('FırınNet üyelerine bakımda %15 indirim'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('partner_detail_call')), findsOneWidget);
      expect(find.byKey(const ValueKey('partner_detail_map')), findsOneWidget);
      // Web sitesi yok → satır render edilmez.
      expect(
        find.byKey(const ValueKey('partner_detail_website')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('partner_detail_report')),
        findsOneWidget,
      );
    });

    testWidgets('listeden Detay → detay ekranı açılır (route)', (tester) async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      final router = GoRouter(
        initialLocation: AppRoutes.partners,
        routes: [
          GoRoute(
            path: AppRoutes.partners,
            builder: (_, __) => const PartnerBusinessesScreen(),
          ),
          GoRoute(
            path: '${AppRoutes.partners}/:partnerId',
            builder: (_, state) => PartnerBusinessDetailScreen(
              partnerId: state.pathParameters['partnerId']!,
            ),
          ),
        ],
      );
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            partnerBusinessRepositoryProvider.overrideWithValue(repo),
            profileControllerProvider.overrideWith(
              (ref) => _FixedProfileController(
                ref,
                _profile(AccountType.individual),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('partner_detail_partner-2')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.partnersBadge), findsOneWidget);
      expect(find.text('Un Deposu Toptan'), findsWidgets);
    });
  });

  group('başvuru formu', () {
    testWidgets('zorunlu alan validasyonu: boş submit hata gösterir', (
      tester,
    ) async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      await _pump(tester, const PartnerBusinessApplicationScreen(), repo: repo);
      await tester.tap(find.byKey(const ValueKey('partner_apply_submit')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.partnersApplyRequired), findsOneWidget);
      expect(repo.submittedApplications, isEmpty);
    });

    testWidgets('dolu form submit → başarı mesajı + kayıt', (tester) async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      await _pump(tester, const PartnerBusinessApplicationScreen(), repo: repo);
      await tester.enterText(
        find.byKey(const ValueKey('partner_apply_business')),
        'Test Ekipman A.Ş.',
      );
      await tester.enterText(
        find.byKey(const ValueKey('partner_apply_contact')),
        'Ali Veli',
      );
      await tester.enterText(
        find.byKey(const ValueKey('partner_apply_phone')),
        '05001112233',
      );
      await tester.enterText(
        find.byKey(const ValueKey('partner_apply_city')),
        'Ankara',
      );
      await tester.enterText(
        find.byKey(const ValueKey('partner_apply_district')),
        'Çankaya',
      );
      await tester.tap(
        find.byKey(const ValueKey('partner_category_Teknik servis')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('partner_apply_submit')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.partnersApplySuccess), findsOneWidget);
      expect(repo.submittedApplications, hasLength(1));
      expect(repo.submittedApplications.single.category, 'Teknik servis');
    });

    testWidgets('çift submit engellenir (tek başvuru kaydı)', (tester) async {
      final repo = _SlowPartnerRepository();
      await _pump(tester, const PartnerBusinessApplicationScreen(), repo: repo);
      await tester.enterText(
        find.byKey(const ValueKey('partner_apply_business')),
        'Çift Tık A.Ş.',
      );
      await tester.enterText(
        find.byKey(const ValueKey('partner_apply_contact')),
        'Ali',
      );
      await tester.enterText(
        find.byKey(const ValueKey('partner_apply_phone')),
        '05001112233',
      );
      await tester.enterText(
        find.byKey(const ValueKey('partner_apply_city')),
        'Ankara',
      );
      await tester.enterText(
        find.byKey(const ValueKey('partner_apply_district')),
        'Çankaya',
      );
      await tester.tap(find.byKey(const ValueKey('partner_category_Diğer')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('partner_apply_submit')));
      await tester.pump();
      // İkinci tık: buton disabled (saving) — kayıt tekrarlanmamalı.
      await tester.tap(
        find.byKey(const ValueKey('partner_apply_submit')),
        warnIfMissed: false,
      );
      await tester.pump();
      repo.completer.complete('application-1');
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 1);
    });

    testWidgets('320dp + 1.3x başvuru formu taşma yapmaz', (tester) async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      await _pump(
        tester,
        const PartnerBusinessApplicationScreen(),
        repo: repo,
        size: const Size(320, 4000),
        textScale: 1.3,
      );
      expect(find.text(AppStrings.partnersApplyTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('panel kartı — tüm kullanıcı türleri', () {
    for (final account in AccountType.values) {
      testWidgets('${account.name} panelinde Anlaşmalı İş Yerleri kartı var', (
        tester,
      ) async {
        final repo = LocalPartnerBusinessRepository(seed: true);
        await _pump(
          tester,
          const RoleDashboardScreen(),
          repo: repo,
          account: account,
        );
        expect(find.text(AppStrings.partnersTitle), findsOneWidget);
        expect(find.text(AppStrings.partnersCardSub), findsOneWidget);
      });
    }
  });
}

/// Hata durumu aynası: [fail] true iken liste yüklenemez (retry testi).
class _FailingPartnerRepository extends LocalPartnerBusinessRepository {
  _FailingPartnerRepository() : super(seed: true);

  bool fail = true;

  @override
  Future<List<PartnerBusiness>> activePartners({int limit = 50}) {
    if (fail) return Future.error(StateError('network'));
    return super.activePartners(limit: limit);
  }
}

/// Gecikmeli submit — çift-submit guard'ını sınamak için.
class _SlowPartnerRepository extends LocalPartnerBusinessRepository {
  _SlowPartnerRepository() : super(seed: true);

  final completer = Completer<String>();
  int submitCalls = 0;

  @override
  Future<String> submitApplication(PartnerBusinessApplicationDraft draft) {
    submitCalls++;
    return completer.future;
  }
}
