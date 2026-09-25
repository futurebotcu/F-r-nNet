import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/payments/data/fake_payment_service.dart';
import 'package:firin_defter/features/payments/data/payment_service.dart';
import 'package:firin_defter/features/payments/models/store_product_config.dart';
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

/// Geçici bağlantı hatası simülasyonu: "görüldü" okuma/yazma başarısız.
class _FlakyNoticeRepo extends LocalSubscriptionRepository {
  _FlakyNoticeRepo({super.supplierLaunchFreeUntil});

  int seenChecks = 0;

  @override
  Future<bool> hasSeenSupplierLaunchNotice() async {
    seenChecks++;
    throw StateError('network down');
  }
}

void main() {
  // KESİN KURAL: sunucu bitişi 2027-10-01T00:00:00+03:00 (bu an hariç) →
  // kullanıcıya "30 Eylül 2027 günü sonuna kadar" gösterilir.
  final until = DateTime.parse('2027-10-01T00:00:00+03:00');
  late String untilLabel;
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    untilLabel = formatSupplierLaunchDate(until);
  });
  setUp(resetSupplierLaunchGiftSessionGuard);

  const authOverrideUser = AuthUser(id: 'u-test', email: 't@t.com');

  test('bitiş günü İstanbul saatine göre 30 Eylül; cihaz dilimi etkisiz', () {
    expect(untilLabel, '30 Eylül 2027');
    // Aynı anın farklı gösterimleri (UTC / +12) aynı günü üretir.
    expect(
      formatSupplierLaunchDate(until.toUtc()),
      '30 Eylül 2027',
    );
  });

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

    testWidgets('başlık, açık bitiş metni, güvence ve CTA görünür', (
      tester,
    ) async {
      await pumpSheet(tester);
      expect(find.text(AppStrings.supplierLaunchGiftTitle), findsOneWidget);
      expect(
        find.text(
          '30 Eylül 2027 ${AppStrings.supplierLaunchGiftFreeSuffix}',
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
      expect(find.textContaining('499'), findsNothing);
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
      String userId = 'u-test',
      LocalSubscriptionRepository? repoOverride,
    }) async {
      final repo = repoOverride ??
          (LocalSubscriptionRepository(
            plan: BusinessPlan.free,
            supplierLaunchFreeUntil: freeUntil,
          )..supplierLaunchNoticeSeen = alreadySeen);
      await tester.pumpWidget(
        ProviderScope(
          // Aynı testte ikinci pumpHost (hesap değişimi / yeni oturum)
          // ESKİ ProviderScope container'ını yeniden kullanmasın diye
          // repo örneğine bağlı key → taze override'lar.
          key: ValueKey('scope-$userId-${identityHashCode(repo)}'),
          overrides: [
            currentAuthUserProvider.overrideWith(
              (_) => AuthUser(id: userId, email: 't@t.com'),
            ),
            subscriptionRepositoryProvider.overrideWithValue(repo),
          ],
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

    final activeUntil = DateTime.now().toUtc().add(const Duration(days: 200));

    testWidgets(
      'kampanya aktif + görülmemiş → bir kez gösterir ve kalıcı işaretler',
      (tester) async {
        final repo = await pumpHost(tester, freeUntil: activeUntil);
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

    testWidgets(
      'aynı cihazda hesap değişimi: ikinci kullanıcı bilgilendirmeyi görür',
      (tester) async {
        await pumpHost(tester, freeUntil: activeUntil, userId: 'user-a');
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.supplierLaunchGiftTitle), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('supplier_launch_gift_cta')),
        );
        await tester.pumpAndSettle();

        // Oturum guard'ı SIFIRLANMADAN kullanıcı değişir (user-b, kendi
        // server kaydı görülmemiş) → pop-up yeniden gösterilir.
        await pumpHost(tester, freeUntil: activeUntil, userId: 'user-b');
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.supplierLaunchGiftTitle), findsOneWidget);
      },
    );

    testWidgets(
      'geçici bağlantı hatası: kalıcı görüldü sayılmaz, oturum içinde '
      'kontrolsüz döngü oluşmaz',
      (tester) async {
        final flaky = _FlakyNoticeRepo(supplierLaunchFreeUntil: activeUntil);
        await pumpHost(tester, repoOverride: flaky);
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.supplierLaunchGiftTitle), findsNothing);
        expect(flaky.supplierLaunchNoticeSeen, isFalse);
        // Aynı oturumda tekrar tetik → yeni deneme YOK (döngü koruması).
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(flaky.seenChecks, 1);

        // Bağlantı düzelen YENİ oturumda pop-up gösterilir (kalıcı görüldü
        // yazılmamıştı).
        resetSupplierLaunchGiftSessionGuard();
        await pumpHost(tester, freeUntil: activeUntil);
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.supplierLaunchGiftTitle), findsOneWidget);
      },
    );

    testWidgets('daha önce görüldüyse (cihaz değişimi) tekrar açılmaz', (
      tester,
    ) async {
      await pumpHost(tester, freeUntil: activeUntil, alreadySeen: true);
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
            currentAuthUserProvider.overrideWith((_) => authOverrideUser),
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
      'kampanyada: Tedarikçi Premium + açık bitiş + sınırsız kotalar + '
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

    testWidgets('kampanya yokken free kart korunur', (tester) async {
      await pumpCard(tester);
      expect(find.text(AppStrings.supPlanFreeTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey('supplier_launch_details_link')),
        findsNothing,
      );
    });
  });

  group('PlansScreen tedarikçi görünümü', () {
    Future<void> pumpPlans(
      WidgetTester tester,
      AccountType account, {
      DateTime? freeUntil,
      bool purchaseAllowed = true,
    }) async {
      tester.view.physicalSize = const Size(390, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAuthUserProvider.overrideWith((_) => authOverrideUser),
            profileControllerProvider.overrideWith(
              (ref) => _FixedProfile(ref, account),
            ),
            subscriptionRepositoryProvider.overrideWithValue(
              LocalSubscriptionRepository(
                plan: BusinessPlan.free,
                supplierLaunchFreeUntil: freeUntil,
                subscriptionPurchaseAllowed: purchaseAllowed,
              )..supplierLaunchNoticeSeen = true,
            ),
          ],
          child: const MaterialApp(home: PlansScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'wholesaler + kampanya → banner + fiyat/satın alma/"3 ay" YOK',
      (tester) async {
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
        // Ortak 499 fiyatı, mağaza CTA'ları ve "3 ay ücretsiz" dili yok.
        expect(find.textContaining('499'), findsNothing);
        expect(find.byKey(const ValueKey('buy_premium_monthly')), findsNothing);
        expect(
          find.byKey(const ValueKey('store_payment_preparing')),
          findsNothing,
        );
        expect(find.text(AppStrings.plansLaunchSubtitle), findsNothing);
        expect(find.text(AppStrings.plansLaunchTrialCta), findsNothing);
        expect(
          find.text(AppStrings.supplierPriceComingSoon),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'wholesaler + paketler yayımlanmamış (kampanya dışı) → fiyat yok',
      (tester) async {
        await pumpPlans(
          tester,
          AccountType.wholesaler,
          purchaseAllowed: false,
        );
        expect(find.textContaining('499'), findsNothing);
        expect(find.byKey(const ValueKey('buy_premium_monthly')), findsNothing);
        expect(find.text(AppStrings.supplierPriceComingSoon), findsOneWidget);
      },
    );

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

    testWidgets('commercial davranışı korunur (banner yok, fiyat var)', (
      tester,
    ) async {
      await pumpPlans(tester, AccountType.commercial, freeUntil: until);
      expect(
        find.byKey(const ValueKey('plans_supplier_launch_banner')),
        findsNothing,
      );
      expect(find.text(AppStrings.plansLaunchSubtitle), findsOneWidget);
      expect(find.textContaining('499'), findsWidgets);
    });
  });

  group('Ödeme servisi satın alma uygunluğu (server kararı)', () {
    test('uygun değilken abonelik mağaza çağrısına ULAŞMAZ', () async {
      final svc = FakePaymentService(
        available: true,
        subscriptionPurchaseAllowed: false,
      );
      final r = await svc.purchaseProduct(
        productId: StoreProductConfig.premiumMonthly,
      );
      expect(r, PaymentResult.unavailable);
      expect(svc.purchaseCalls, 0);

      final r2 = await svc.purchasePlan(
        account: AccountType.wholesaler,
        plan: BusinessPlan.premium,
      );
      expect(r2, PaymentResult.unavailable);
      expect(svc.purchaseCalls, 0);
    });

    test('uygunken abonelik satın alma çalışmaya devam eder', () async {
      final svc = FakePaymentService(available: true);
      final r = await svc.purchaseProduct(
        productId: StoreProductConfig.premiumMonthly,
      );
      expect(r, PaymentResult.success);
      expect(svc.purchaseCalls, 1);
    });

    test('ilan ücreti akışı abonelik gate’inden bağımsız', () async {
      final svc = FakePaymentService(
        available: true,
        subscriptionPurchaseAllowed: false,
      );
      final r = await svc.purchaseProduct(
        productId: StoreProductConfig.listingFee,
      );
      expect(r, PaymentResult.success);
      expect(svc.purchaseCalls, 1);
    });
  });
}
