import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_entitlements.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BusinessPlan taxonomy', () {
    test('persistKey round-trip + unknown fallback', () {
      for (final p in BusinessPlan.values) {
        expect(BusinessPlanMeta.fromKey(p.persistKey), p);
      }
      expect(BusinessPlanMeta.fromKey(null), BusinessPlan.free);
      expect(BusinessPlanMeta.fromKey('gold'), BusinessPlan.free);
    });
  });

  group('BusinessEntitlements.fromRow launch promo fields', () {
    test('active promo acts as Premium view model', () {
      final e = BusinessEntitlements.fromRow(<String, dynamic>{
        'plan': 'free',
        'effective_plan': 'premium',
        'is_trial_active': true,
        'trial_ends_at': '2026-12-23T00:00:00Z',
        'days_left': 74,
        'recipe_limit': -1,
        'dealer_limit': -1,
        'can_use_branches': true,
        'can_use_debt_expense': true,
        'can_use_dealer_driver_ops': true,
        'promo_status': 'active',
        'promo_started_at': '2026-09-23T00:00:00Z',
        'promo_expires_at': '2026-12-23T00:00:00Z',
        'can_start_promo': false,
      });
      expect(e.plan, BusinessPlan.free);
      expect(e.effectivePlan, BusinessPlan.premium);
      expect(e.isLaunchPromoActive, isTrue);
      expect(e.canUsePremiumFeature, isTrue);
      expect(e.daysLeft, 74);
      expect(e.canStartPromo, isFalse);
      expect(e.recipesUnlimited, isTrue);
      expect(e.dealersUnlimited, isTrue);
    });

    test('missing row fails closed as free but can start promo', () {
      final e = BusinessEntitlements.fromRow(<String, dynamic>{});
      expect(e.plan, BusinessPlan.free);
      expect(e.effectivePlan, BusinessPlan.free);
      expect(e.canUsePremiumFeature, isFalse);
      expect(e.canStartPromo, isTrue);
      expect(e.recipeLimit, 5);
      expect(e.dealerLimit, 0);
    });
  });

  group('LocalSubscriptionRepository launch promo mirror', () {
    test('free starts locked', () async {
      final repo = LocalSubscriptionRepository(plan: BusinessPlan.free);
      final e = await repo.myEntitlement();
      expect(e.effectivePlan, BusinessPlan.free);
      expect(e.canUseBranches, isFalse);
      expect(e.canUseDebtExpense, isFalse);
      expect(e.canUseDealerDriverOps, isFalse);
      expect(e.canStartPromo, isTrue);
    });

    test('activateLaunchPremiumPromo is idempotent and unlocks Premium', () async {
      final repo = LocalSubscriptionRepository(plan: BusinessPlan.free);
      final first = await repo.activateLaunchPremiumPromo();
      expect(first.effectivePlan, BusinessPlan.premium);
      expect(first.isLaunchPromoActive, isTrue);
      expect(first.canStartPromo, isFalse);
      expect(first.canUseBranches, isTrue);
      expect(first.canUseDebtExpense, isTrue);

      final second = await repo.activateLaunchPremiumPromo();
      expect(second.effectivePlan, BusinessPlan.premium);
      expect(second.daysLeft, first.daysLeft);
      expect(second.canStartPromo, isFalse);
    });

    test('paid Premium stays open', () async {
      final repo = LocalSubscriptionRepository(plan: BusinessPlan.premium);
      final e = await repo.myEntitlement();
      expect(e.isPremium, isTrue);
      expect(e.canUsePremiumFeature, isTrue);
      expect(e.recipesUnlimited, isTrue);
      expect(e.dealersUnlimited, isTrue);
    });
  });
}
