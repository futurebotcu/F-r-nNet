import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:firin_defter/features/subscriptions/screens/plans_screen.dart';
import 'package:firin_defter/features/subscriptions/widgets/commercial_launch_sheet.dart';
import 'package:firin_defter/features/subscriptions/widgets/plan_status_card.dart';
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
      roleBadge: 'F',
      email: 't@t.com',
    );
  }
}

class _FlakyNoticeRepo extends LocalSubscriptionRepository {
  _FlakyNoticeRepo({super.commercialFreeStartedAt, super.commercialFreeEndsAt});

  int seenChecks = 0;

  @override
  Future<bool> hasSeenCommercialLaunchNotice(String noticeKey) async {
    seenChecks++;
    throw StateError('network down');
  }
}

void main() {
  final priceUntil = DateTime.parse('2027-10-01T00:00:00+03:00');
  late String priceDay;
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    priceDay = formatCommercialLaunchDay(priceUntil); // 30 Eylül 2027
  });
  setUp(resetCommercialLaunchSessionGuard);

  LocalSubscriptionRepository repoWith({
    DateTime? startedAt,
    DateTime? endsAt,
    bool withPrice = true,
  }) => LocalSubscriptionRepository(
    plan: BusinessPlan.free,
    commercialFreeStartedAt: startedAt,
    commercialFreeEndsAt: endsAt,
    launchPriceUntil: withPrice ? priceUntil : null,
  );

  final activeEnds = DateTime.now().toUtc().add(const Duration(days: 20));
  final endingEnds = DateTime.now().toUtc().add(const Duration(days: 2));
  final endedEnds = DateTime.now().toUtc().subtract(const Duration(days: 2));
  final startedAt = DateTime.now().toUtc().subtract(const Duration(days: 10));

  Future<LocalSubscriptionRepository> pumpHost(
    WidgetTester tester, {
    LocalSubscriptionRepository? repo,
    DateTime? endsAt,
    String userId = 'u-test',
  }) async {
    final r = repo ?? repoWith(startedAt: startedAt, endsAt: endsAt);
    await tester.pumpWidget(
      ProviderScope(
        key: ValueKey('scope-$userId-${identityHashCode(r)}'),
        overrides: [
          currentAuthUserProvider.overrideWith(
            (_) => AuthUser(id: userId, email: 't@t.com'),
          ),
          subscriptionRepositoryProvider.overrideWithValue(r),
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
                        maybeShowCommercialLaunchSheet(context, ref),
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
    return r;
  }

  group('maybeShowCommercialLaunchSheet durum seçimi + tekrar koruması', () {
    testWidgets('dönem aktif → hoş geldin; bir kez; kalıcı işaret', (
      tester,
    ) async {
      final repo = await pumpHost(tester, endsAt: activeEnds);
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(AppStrings.commercialWelcomePrefix.trim()),
        findsOneWidget,
      );
      // Temel özellik listesi + fiyat kutusu + güvence.
      expect(
        find.text(AppStrings.commercialBasicsList.first),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('commercial_launch_price_box')),
        findsOneWidget,
      );
      expect(find.textContaining('499,99'), findsOneWidget);
      expect(find.textContaining(priceDay), findsWidgets);
      expect(
        find.textContaining(AppStrings.commercialPriceAssurance),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('commercial_launch_ok')));
      await tester.pumpAndSettle();
      expect(repo.commercialNoticesSeen.contains('welcome_ack'), isTrue);

      // Aynı oturum + yeni oturum → tekrar açılmaz.
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      resetCommercialLaunchSessionGuard();
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('commercial_launch_headline')),
        findsNothing,
      );
    });

    testWidgets('son 3 gün → "ending" içeriği (kalan gün)', (tester) async {
      await pumpHost(tester, endsAt: endingEnds);
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(AppStrings.commercialEndingPrefix),
        findsOneWidget,
      );
    });

    testWidgets('dönem bitti → "ended" + seçenekler; otomatik ücret yok', (
      tester,
    ) async {
      final repo = await pumpHost(tester, endsAt: endedEnds);
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.commercialEndedTitle), findsOneWidget);
      expect(find.text(AppStrings.commercialEndedKeepHeader), findsOneWidget);
      expect(
        find.text(AppStrings.commercialEndedLockedHeader),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.commercialPremiumLockedList.first),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('commercial_launch_continue_premium')),
        findsOneWidget,
      );
      // "Ücretsiz devam et" yalnız kapatır.
      await tester.ensureVisible(
        find.byKey(const ValueKey('commercial_launch_stay_free')),
      );
      await tester.tap(
        find.byKey(const ValueKey('commercial_launch_stay_free')),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.commercialEndedTitle), findsNothing);
      expect(repo.commercialNoticesSeen.contains('ended_ack'), isTrue);
    });

    testWidgets('tarih yapılandırılmamış (ends null) → hiç gösterilmez', (
      tester,
    ) async {
      await pumpHost(tester);
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('commercial_launch_headline')),
        findsNothing,
      );
    });

    testWidgets('hesap değişimi: ikinci kullanıcı kendi pop-up\'ını görür', (
      tester,
    ) async {
      await pumpHost(tester, endsAt: activeEnds, userId: 'user-a');
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('commercial_launch_ok')));
      await tester.pumpAndSettle();

      await pumpHost(tester, endsAt: activeEnds, userId: 'user-b');
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('commercial_launch_headline')),
        findsOneWidget,
      );
    });

    testWidgets(
      'geçici bağlantı hatası kalıcı görüldü sayılmaz; döngü yok',
      (tester) async {
        final flaky = _FlakyNoticeRepo(
          commercialFreeStartedAt: startedAt,
          commercialFreeEndsAt: activeEnds,
        );
        await pumpHost(tester, repo: flaky);
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('commercial_launch_headline')),
          findsNothing,
        );
        expect(flaky.commercialNoticesSeen, isEmpty);
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(flaky.seenChecks, 1);

        resetCommercialLaunchSessionGuard();
        await pumpHost(tester, endsAt: activeEnds);
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('commercial_launch_headline')),
          findsOneWidget,
        );
      },
    );

    testWidgets('küçük ekran + 1.3x taşmaz (ended, en uzun içerik)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final repo = repoWith(startedAt: startedAt, endsAt: endedEnds);
      final ent = await repo.myEntitlement();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommercialLaunchSheetBody(
              notice: CommercialLaunchNotice.ended,
              entitlement: ent,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('PlanStatusCard / PlansScreen ücretsiz dönem durumu', () {
    testWidgets('kart: Ücretsiz Dönem başlığı + rozet + sonrası fiyat', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(
              repoWith(startedAt: startedAt, endsAt: activeEnds),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: PlanStatusCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.commercialFreePeriodTitle), findsOneWidget);
      expect(find.text(AppStrings.commercialFreePeriodBadge), findsOneWidget);
      expect(find.textContaining('499,99'), findsOneWidget);
      expect(find.textContaining(priceDay), findsWidgets);
    });

    testWidgets(
      'PlansScreen (ticari, dönem aktif): banner + Her zaman ücretsiz + '
      'lansman fiyat notu + "3 ay" yok',
      (tester) async {
        tester.view.physicalSize = const Size(390, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileControllerProvider.overrideWith(
                (ref) => _FixedProfile(ref, AccountType.commercial),
              ),
              subscriptionRepositoryProvider.overrideWithValue(
                repoWith(startedAt: startedAt, endsAt: activeEnds),
              ),
            ],
            child: const MaterialApp(home: PlansScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('plans_free_period_banner')),
          findsOneWidget,
        );
        expect(find.text(AppStrings.planFreeAlwaysLabel), findsOneWidget);
        expect(
          find.byKey(const ValueKey('plans_launch_price_note')),
          findsOneWidget,
        );
        expect(find.textContaining('3 ay'), findsNothing);
      },
    );
  });
}
