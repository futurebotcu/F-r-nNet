import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:firin_defter/features/subscriptions/screens/plans_screen.dart';
import 'package:firin_defter/features/subscriptions/widgets/supplier_launch_gift_sheet.dart';
import 'package:firin_defter/features/subscriptions/widgets/supplier_plan_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FixedProfile extends ProfileController {
  _FixedProfile(super.ref, AccountType account) {
    state = BakeryProfile(
      displayName: 'T',
      accountType: account,
      city: 'Istanbul',
      roleBadge: 'Tedarikci',
      email: 't@t.com',
    );
  }
}

void main() {
  final until = DateTime.utc(2027, 10, 1, 12);
  late String untilLabel;
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    untilLabel = formatSupplierLaunchDate(until);
  });
  setUp(resetSupplierLaunchGiftSessionGuard);

  group('SupplierLaunchGiftSheetBody', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      double textScale = 1.0,
      Size size = const Size(390, 844),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupplierLaunchGiftSheetBody(freeUntil: until),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('başlık, gerçek bitiş tarihi, güvence ve CTA görünür', (
      tester,
    ) async {
      await pumpSheet(tester);
      expect(find.text(AppStrings.supplierLaunchGiftTitle), findsOneWidget);
      expect(
        find.text(
          '$untilLabel ${AppStrings.supplierLaunchGiftFreeSuffix}',
        ),
        findsOneWidget,
      );
      expect(find.text(AppStrings.supplierLaunchGiftBody), findsOneWidget);
      expect(
        find.text(AppStrings.supplierLaunchGiftContinueInfo),
        findsOneWidget,
      );
      expect(find.text(AppStrings.supplierLaunchGiftAssurance), findsOneWidget);
      expect(find.text(AppStrings.supplierLaunchGiftCta), findsOneWidget);
      // Fiyat/satın alma yüzeyi YOK (yalnız bilgilendirme).
      expect(find.textContaining('TL'), findsNothing);
    });

    testWidgets('küçük ekran + 1.3x yazı taşmaz', (tester) async {
      await pumpSheet(tester, textScale: 1.3, size: const Size(320, 700));
      expect(tester.takeException(), isNull);
    });
  });

  group('maybeShowSupplierLaunchGiftSheet', () {
    Future<LocalSubscriptionRepository> pumpHost(
      WidgetTester tester, {
      DateTime? freeUntil,
      bool alreadySeen = false,
    }) async {
      final repo = LocalSubscriptionRepository(
        plan: BusinessPlan.free,
        supplierLaunchFreeUntil: freeUntil,
      )..supplierLaunchNoticeSeen = alreadySeen;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [subscriptionRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(myEntitlementProvider);
                return Scaffold(
                  body: Center(
                    child: FilledButton(
                      key: const ValueKey('trigger'),
                      onPressed: () =>
                          maybeShowSupplierLaunchGiftSheet(context, ref),
                      child: const Text('tetikle'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets(
      'kampanya aktif + görülmemiş → bir kez gösterir ve kalıcı işaretler',
      (tester) async {
        final repo = await pumpHost(
          tester,
          freeUntil: DateTime.now().toUtc().add(const Duration(days: 200)),
        );
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.supplierLaunchGiftTitle), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('supplier_launch_gift_cta')),
        );
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.supplierLaunchGiftTitle), findsNothing);
        expect(repo.supplierLaunchNoticeSeen, isTrue);

        // Aynı oturumda ikinci tetik → açılmaz.
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.supplierLaunchGiftTitle), findsNothing);

        // Yeni oturum (guard sıfır) + server 'görüldü' kaydı → yine açılmaz.
        resetSupplierLaunchGiftSessionGuard();
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.supplierLaunchGiftTitle), findsNothing);
      },
    );

    testWidgets('daha önce görüldüyse (cihaz değişimi) tekrar açılmaz', (
      tester,
    ) async {
      await pumpHost(
        tester,
        freeUntil: DateTime.now().toUtc().add(const Duration(days: 200)),
        alreadySeen: true,
      );
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.supplierLaunchGiftTitle), findsNothing);
    });

    testWidgets('kampanya yok/tarihsiz → hiç gösterilmez', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.supplierLaunchGiftTitle), findsNothing);
    });

    testWidgets('kampanya bitmiş → gösterilmez', (tester) async {
      await pumpHost(
        tester,
        freeUntil: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.supplierLaunchGiftTitle), findsNothing);
    });
  });

  group('SupplierPlanCard kampanya durumu', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      DateTime? freeUntil,
      bool seen = true,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(
              LocalSubscriptionRepository(
                plan: BusinessPlan.free,
                supplierLaunchFreeUntil: freeUntil,
              )..supplierLaunchNoticeSeen = seen,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SupplierPlanCard(productCount: 0, campaignCount: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'kampanyada: Tedarikçi Premium + bitiş tarihi + sınırsız kotalar + '
      'fiyat ipucu yok + detay linki',
      (tester) async {
        await pumpCard(tester, freeUntil: until);
        expect(
          find.text(AppStrings.supplierLaunchPlanTitle),
          findsOneWidget,
        );
        expect(
          find.text(
            '$untilLabel ${AppStrings.supplierLaunchFreeUntilSuffix}',
          ),
          findsOneWidget,
        );
        expect(find.text(AppStrings.supQuotaUnlimited), findsWidgets);
        expect(find.textContaining('499'), findsNothing);
        expect(
          find.byKey(const ValueKey('supplier_launch_details_link')),
          findsOneWidget,
        );
      },
    );

    testWidgets('detay linki kampanya açıklamasını yeniden açar', (
      tester,
    ) async {
      await pumpCard(tester, freeUntil: until);
      await tester.tap(
        find.byKey(const ValueKey('supplier_launch_details_link')),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.supplierLaunchGiftTitle), findsOneWidget);
    });

    testWidgets('kampanya yokken free kart + fiyat ipucu korunur', (
      tester,
    ) async {
      await pumpCard(tester);
      expect(find.text(AppStrings.supPlanFreeTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey('supplier_launch_details_link')),
        findsNothing,
      );
    });
  });

  group('PlansScreen kampanya banner', () {
    Future<void> pumpPlans(
      WidgetTester tester,
      AccountType account, {
      DateTime? freeUntil,
    }) async {
      tester.view.physicalSize = const Size(390, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _FixedProfile(ref, account),
            ),
            subscriptionRepositoryProvider.overrideWithValue(
              LocalSubscriptionRepository(
                plan: BusinessPlan.free,
                supplierLaunchFreeUntil: freeUntil,
              )..supplierLaunchNoticeSeen = true,
            ),
          ],
          child: const MaterialApp(home: PlansScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('wholesaler + kampanya → ücretsiz dönem banner’ı', (
      tester,
    ) async {
      await pumpPlans(tester, AccountType.wholesaler, freeUntil: until);
      expect(
        find.byKey(const ValueKey('plans_supplier_launch_banner')),
        findsOneWidget,
      );
      expect(
        find.text(
          '${AppStrings.supplierLaunchPlanTitle} — $untilLabel '
          '${AppStrings.supplierLaunchFreeUntilSuffix}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('banner tap kampanya açıklamasını açar', (tester) async {
      await pumpPlans(tester, AccountType.wholesaler, freeUntil: until);
      await tester.tap(
        find.byKey(const ValueKey('plans_supplier_launch_banner')),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.supplierLaunchGiftTitle), findsOneWidget);
    });

    testWidgets('kampanya yokken banner yok', (tester) async {
      await pumpPlans(tester, AccountType.wholesaler);
      expect(
        find.byKey(const ValueKey('plans_supplier_launch_banner')),
        findsNothing,
      );
    });

    testWidgets('commercial kampanyadan etkilenmez (banner yok)', (
      tester,
    ) async {
      await pumpPlans(tester, AccountType.commercial, freeUntil: until);
      expect(
        find.byKey(const ValueKey('plans_supplier_launch_banner')),
        findsNothing,
      );
    });
  });
}
