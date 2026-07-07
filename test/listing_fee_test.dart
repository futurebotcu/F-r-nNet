import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_entitlements.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/models/listing_fee.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:firin_defter/features/subscriptions/widgets/listing_fee_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// İlan Ücretlendirme V1 — client fee helper + notice widget testleri.
/// Asıl zorlama server-side (RLS smoke 8 faz PASS); bu yalnız UX aynası.
BusinessEntitlements _ent(BusinessPlan plan, {bool trial = false}) =>
    BusinessEntitlements(
      plan: trial ? BusinessPlan.free : plan,
      effectivePlan: trial ? BusinessPlan.premium : plan,
      isTrialActive: trial,
    );

class _FixedProfileController extends ProfileController {
  _FixedProfileController(super.ref, AccountType? account) {
    state = account == null
        ? null
        : BakeryProfile(
            displayName: 'T',
            accountType: account,
            city: 'İstanbul',
            roleBadge: 'Usta',
            email: 't@t.com',
          );
  }
}

void main() {
  group('ListingFee.amountCents', () {
    test('iş arama her zaman ücretsiz', () {
      for (final acc in AccountType.values) {
        expect(
          ListingFee.amountCents(
            kind: ListingKind.jobSeek,
            account: acc,
            entitlements: _ent(BusinessPlan.free),
          ),
          0,
        );
      }
    });

    test('bireysel ekipman/işyeri devri 50 TL', () {
      expect(
        ListingFee.amountCents(
          kind: ListingKind.market,
          account: AccountType.individual,
          entitlements: null,
        ),
        5000,
      );
    });

    test('commercial free işçi/ekipman 50 TL', () {
      for (final k in [ListingKind.jobOffer, ListingKind.market]) {
        expect(
          ListingFee.amountCents(
            kind: k,
            account: AccountType.commercial,
            entitlements: _ent(BusinessPlan.free),
          ),
          5000,
        );
      }
    });

    test('commercial pro/premium/trial ücretsiz', () {
      for (final e in [
        _ent(BusinessPlan.pro),
        _ent(BusinessPlan.premium),
        _ent(BusinessPlan.free, trial: true),
      ]) {
        for (final k in [ListingKind.jobOffer, ListingKind.market]) {
          expect(
            ListingFee.amountCents(
              kind: k,
              account: AccountType.commercial,
              entitlements: e,
            ),
            0,
            reason: '${e.effectivePlan} / $k',
          );
        }
      }
    });

    test('toptancı/tedarikçi 50 TL', () {
      expect(
        ListingFee.amountCents(
          kind: ListingKind.market,
          account: AccountType.wholesaler,
          entitlements: null,
        ),
        5000,
      );
    });

    test('entitlement yüklenmemiş commercial → güvenli tarafta ücretli', () {
      expect(
        ListingFee.amountCents(
          kind: ListingKind.market,
          account: AccountType.commercial,
          entitlements: null,
        ),
        5000,
      );
    });
  });

  group('ListingFeeNotice widget', () {
    Future<void> pump(
      WidgetTester tester,
      ListingKind kind,
      AccountType? account,
      BusinessPlan plan, {
      bool trial = false,
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
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _FixedProfileController(ref, account),
            ),
            subscriptionRepositoryProvider.overrideWithValue(
              LocalSubscriptionRepository(plan: plan, trialActive: trial),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: ListingFeeNotice(kind: kind)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('bireysel iş arama → ücretsiz metni', (tester) async {
      await pump(
        tester,
        ListingKind.jobSeek,
        AccountType.individual,
        BusinessPlan.free,
      );
      expect(find.text(AppStrings.listingFeeFreeSeek), findsOneWidget);
    });

    testWidgets('bireysel ekipman → 50 TL metni', (tester) async {
      await pump(
        tester,
        ListingKind.market,
        AccountType.individual,
        BusinessPlan.free,
      );
      expect(find.text(AppStrings.listingFeePaidTitle), findsOneWidget);
      expect(find.text(AppStrings.listingFeeIndividualBody), findsOneWidget);
    });

    testWidgets('commercial free → ücretli metni', (tester) async {
      await pump(
        tester,
        ListingKind.market,
        AccountType.commercial,
        BusinessPlan.free,
      );
      expect(find.text(AppStrings.listingFeePaidTitle), findsOneWidget);
    });

    testWidgets('commercial pro → ücretsiz metni', (tester) async {
      await pump(
        tester,
        ListingKind.market,
        AccountType.commercial,
        BusinessPlan.pro,
      );
      expect(find.text(AppStrings.listingFeeFreePlan), findsOneWidget);
      expect(find.text(AppStrings.listingFeePaidTitle), findsNothing);
    });

    testWidgets('toptancı → tedarikçi 50 TL metni', (tester) async {
      await pump(
        tester,
        ListingKind.market,
        AccountType.wholesaler,
        BusinessPlan.free,
      );
      expect(find.text(AppStrings.listingFeeSupplierBody), findsOneWidget);
    });

    testWidgets('320dp + 1.3x taşma yapmaz', (tester) async {
      await pump(
        tester,
        ListingKind.market,
        AccountType.individual,
        BusinessPlan.free,
        textScale: 1.3,
        size: const Size(320, 800),
      );
      expect(find.byKey(const ValueKey('listing_fee_notice')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ListingPendingBadge', () {
    testWidgets('ödeme bekliyor rozeti render', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: ListingPendingBadge())),
        ),
      );
      expect(find.text(AppStrings.listingFeePendingBadge), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });
  });
}
