import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/models/listing_fee.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:firin_defter/features/subscriptions/widgets/listing_fee_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedProfileController extends ProfileController {
  _FixedProfileController(super.ref, AccountType? account) {
    state = account == null
        ? null
        : BakeryProfile(
            displayName: 'T',
            accountType: account,
            city: 'Istanbul',
            roleBadge: 'Usta',
            email: 't@t.com',
          );
  }
}

void main() {
  group('ListingFee launch period', () {
    test('50 TL product infrastructure remains but launch payments are disabled', () {
      expect(ListingFee.feeCents, 5000);
      expect(ListingFee.launchListingPaymentsEnabled, isFalse);
    });

    test('all listing kinds are free while launch flag is disabled', () {
      for (final kind in ListingKind.values) {
        for (final account in AccountType.values) {
          expect(
            ListingFee.amountCents(
              kind: kind,
              account: account,
              entitlements: null,
            ),
            0,
            reason: '$kind / $account',
          );
        }
      }
    });
  });

  group('ListingFeeNotice widget', () {
    Future<void> pump(
      WidgetTester tester,
      ListingKind kind,
      AccountType? account,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _FixedProfileController(ref, account),
            ),
            subscriptionRepositoryProvider.overrideWithValue(
              LocalSubscriptionRepository(plan: BusinessPlan.free),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: ListingFeeNotice(kind: kind)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('job seek keeps explicit free copy', (tester) async {
      await pump(tester, ListingKind.jobSeek, AccountType.individual);
      expect(find.text(AppStrings.listingFeeFreeSeek), findsOneWidget);
    });

    testWidgets('market/job offer show launch free copy', (tester) async {
      await pump(tester, ListingKind.market, AccountType.individual);
      expect(find.text(AppStrings.listingLaunchFreeBody), findsOneWidget);
      expect(find.text(AppStrings.listingFeePaidTitle), findsNothing);

      await pump(tester, ListingKind.jobOffer, AccountType.commercial);
      expect(find.text(AppStrings.listingLaunchFreeBody), findsOneWidget);
      expect(find.text(AppStrings.listingFeePaidTitle), findsNothing);
    });
  });

  group('ListingPendingBadge', () {
    testWidgets('pending badge still renders for legacy/pending listings', (tester) async {
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
