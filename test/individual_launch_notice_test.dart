import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/payments/data/fake_payment_service.dart';
import 'package:firin_defter/features/payments/providers/payment_providers.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:firin_defter/features/subscriptions/screens/plans_screen.dart';
import 'package:firin_defter/features/subscriptions/widgets/individual_launch_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FixedProfile extends ProfileController {
  _FixedProfile(super.ref, AccountType account) {
    state = BakeryProfile(
      displayName: 'B',
      accountType: account,
      city: 'Istanbul',
      roleBadge: 'Usta',
      email: 'b@t.com',
    );
  }
}

/// Geçici bağlantı hatası simülasyonu: "görüldü" okuma başarısız.
class _FlakyNoticeRepo extends LocalSubscriptionRepository {
  _FlakyNoticeRepo({super.individualFreeUntil});

  int seenChecks = 0;

  @override
  Future<bool> hasSeenIndividualLaunchNotice() async {
    seenChecks++;
    throw StateError('network down');
  }
}

void main() {
  // KESİN KURAL: sunucu sınırı 2027-10-01T00:00:00+03:00 (bu an hariç) →
  // kullanıcıya "30 Eylül 2027 günü sonuna kadar" gösterilir.
  final until = DateTime.parse('2027-10-01T00:00:00+03:00');
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });
  setUp(resetIndividualLaunchSessionGuard);

  test('bitiş günü İstanbul saatine göre 30 Eylül; cihaz dilimi etkisiz', () {
    expect(formatIndividualLaunchDate(until), '30 Eylül 2027');
    expect(formatIndividualLaunchDate(until.toUtc()), '30 Eylül 2027');
  });

  group('IndividualLaunchSheetBody', () {
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
          home: Scaffold(body: IndividualLaunchSheetBody(freeUntil: until)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('başlık, açık bitiş metni, güvence ve tek CTA görünür', (
      tester,
    ) async {
      await pumpSheet(tester);
      expect(find.text(AppStrings.individualLaunchTitle), findsOneWidget);
      expect(
        find.text('30 Eylül 2027 ${AppStrings.individualLaunchFreeSuffix}'),
        findsOneWidget,
      );
      expect(find.text(AppStrings.individualLaunchBody), findsOneWidget);
      expect(find.text(AppStrings.individualLaunchAssurance), findsOneWidget);
      expect(find.text(AppStrings.individualLaunchCta), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      // Fiyat/satın alma yüzeyi YOK (yalnız bilgilendirme).
      expect(find.textContaining('TL'), findsNothing);
      expect(find.textContaining('499'), findsNothing);
    });

    testWidgets('küçük ekran + 1.3x yazı taşmaz', (tester) async {
      await pumpSheet(tester, textScale: 1.3, size: const Size(320, 700));
      expect(tester.takeException(), isNull);
    });
  });

  group('maybeShowIndividualLaunchSheet', () {
    Future<LocalSubscriptionRepository> pumpHost(
      WidgetTester tester, {
      DateTime? freeUntil,
      bool alreadySeen = false,
      String userId = 'u-test',
      LocalSubscriptionRepository? repoOverride,
    }) async {
      final repo = repoOverride ??
          (LocalSubscriptionRepository(individualFreeUntil: freeUntil)
            ..individualLaunchNoticeSeen = alreadySeen);
      await tester.pumpWidget(
        ProviderScope(
          // Aynı testte ikinci pumpHost (hesap değişimi / yeni oturum)
          // ESKİ ProviderScope container'ını yeniden kullanmasın diye
          // repo örneğine bağlı key → taze override'lar.
          key: ValueKey('scope-$userId-${identityHashCode(repo)}'),
          overrides: [
            currentAuthUserProvider.overrideWith(
              (_) => AuthUser(id: userId, email: 'b@t.com'),
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
                          maybeShowIndividualLaunchSheet(context, ref),
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
      'tarih yapılandırılmış + görülmemiş → bir kez gösterir ve kalıcı '
      'işaretler',
      (tester) async {
        final repo = await pumpHost(tester, freeUntil: activeUntil);
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.individualLaunchTitle), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('individual_launch_cta')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.individualLaunchTitle), findsNothing);
        expect(repo.individualLaunchNoticeSeen, isTrue);

        // Aynı oturumda ikinci tetik → açılmaz.
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.individualLaunchTitle), findsNothing);

        // Yeni oturum (guard sıfır) + server 'görüldü' kaydı → yine açılmaz.
        resetIndividualLaunchSessionGuard();
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.individualLaunchTitle), findsNothing);
      },
    );

    testWidgets(
      'aynı cihazda hesap değişimi: ikinci kullanıcı bilgilendirmeyi görür',
      (tester) async {
        await pumpHost(tester, freeUntil: activeUntil, userId: 'user-a');
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.individualLaunchTitle), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('individual_launch_cta')));
        await tester.pumpAndSettle();

        // Oturum guard'ı SIFIRLANMADAN kullanıcı değişir (user-b, kendi
        // server kaydı görülmemiş) → pop-up yeniden gösterilir.
        await pumpHost(tester, freeUntil: activeUntil, userId: 'user-b');
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.individualLaunchTitle), findsOneWidget);
      },
    );

    testWidgets(
      'geçici bağlantı hatası: kalıcı görüldü sayılmaz, oturum içinde '
      'kontrolsüz döngü oluşmaz',
      (tester) async {
        final flaky = _FlakyNoticeRepo(individualFreeUntil: activeUntil);
        await pumpHost(tester, repoOverride: flaky);
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.individualLaunchTitle), findsNothing);
        expect(flaky.individualLaunchNoticeSeen, isFalse);
        // Aynı oturumda tekrar tetik → yeni deneme YOK (döngü koruması).
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(flaky.seenChecks, 1);

        // Bağlantı düzelen YENİ oturumda pop-up gösterilir (kalıcı görüldü
        // yazılmamıştı).
        resetIndividualLaunchSessionGuard();
        await pumpHost(tester, freeUntil: activeUntil);
        await tester.tap(find.byKey(const ValueKey('trigger')));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.individualLaunchTitle), findsOneWidget);
      },
    );

    testWidgets('daha önce görüldüyse (cihaz değişimi) tekrar açılmaz', (
      tester,
    ) async {
      await pumpHost(tester, freeUntil: activeUntil, alreadySeen: true);
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.individualLaunchTitle), findsNothing);
    });

    testWidgets('tarih yapılandırılmamış (eski backend) → hiç gösterilmez', (
      tester,
    ) async {
      await pumpHost(tester);
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.individualLaunchTitle), findsNothing);
    });

    testWidgets('dönem bitmiş → gösterilmez', (tester) async {
      await pumpHost(
        tester,
        freeUntil: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.individualLaunchTitle), findsNothing);
    });
  });

  group('PlansScreen kalıcı not', () {
    Future<void> pumpPlans(
      WidgetTester tester, {
      required AccountType account,
      required LocalSubscriptionRepository repo,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAuthUserProvider.overrideWith(
              (_) => const AuthUser(id: 'u-test', email: 'b@t.com'),
            ),
            profileControllerProvider.overrideWith(
              (ref) => _FixedProfile(ref, account),
            ),
            subscriptionRepositoryProvider.overrideWithValue(repo),
            paymentServiceProvider.overrideWithValue(
              FakePaymentService(available: false),
            ),
          ],
          child: const MaterialApp(home: PlansScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'bireysel: not görünür; satın alma/mağaza/promo dili görünmez',
      (tester) async {
        await pumpPlans(
          tester,
          account: AccountType.individual,
          repo: LocalSubscriptionRepository(
            individualFreeUntil: until,
            subscriptionPurchaseAllowed: false,
          ),
        );
        expect(
          find.byKey(const ValueKey('plans_individual_free_note')),
          findsOneWidget,
        );
        expect(find.textContaining('30 Eylül 2027'), findsOneWidget);
        // Ücret çağrışımlı yüzeyler yok: mağaza notu, satın alma, promo CTA.
        expect(find.text(AppStrings.plansStoreReady), findsNothing);
        expect(find.byKey(const ValueKey('buy_premium_monthly')), findsNothing);
        expect(find.text(AppStrings.plansLaunchTrialCta), findsNothing);
        expect(find.text(AppStrings.plansLaunchSubtitle), findsNothing);
      },
    );

    testWidgets('ticari: bireysel notu görünmez (davranış değişmedi)', (
      tester,
    ) async {
      await pumpPlans(
        tester,
        account: AccountType.commercial,
        repo: LocalSubscriptionRepository(),
      );
      expect(
        find.byKey(const ValueKey('plans_individual_free_note')),
        findsNothing,
      );
      // Ticari promo dili aynen durur.
      expect(find.text(AppStrings.plansLaunchSubtitle), findsOneWidget);
    });

    testWidgets('tedarikçi: bireysel notu görünmez', (tester) async {
      await pumpPlans(
        tester,
        account: AccountType.wholesaler,
        repo: LocalSubscriptionRepository(
          subscriptionPurchaseAllowed: false,
        ),
      );
      expect(
        find.byKey(const ValueKey('plans_individual_free_note')),
        findsNothing,
      );
    });
  });
}
