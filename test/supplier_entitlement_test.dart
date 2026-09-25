import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_entitlements.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BusinessEntitlements.fromRow supplier fields', () {
    test('legacy pro row can still be parsed for backward compatibility', () {
      final e = BusinessEntitlements.fromRow(<String, dynamic>{
        'plan': 'free',
        'effective_plan': 'free',
        'supplier_effective_plan': 'pro',
        'supplier_product_limit': 1,
        'supplier_campaign_limit': 0,
        'supplier_monthly_reply_limit': 3,
        'supplier_can_add_product': true,
        'supplier_can_add_campaign': false,
        'supplier_can_reply_quote': true,
        'supplier_listing_fee_exempt': false,
      });
      expect(e.supplierEffectivePlan, BusinessPlan.pro);
      expect(e.supplierProductLimit, 1);
      expect(e.supplierCampaignLimit, 0);
      expect(e.supplierMonthlyReplyLimit, 3);
      expect(e.supplierListingFeeExempt, isFalse);
      expect(e.supplierProductsUnlimited, isFalse);
    });

    test('missing row uses safe free defaults', () {
      final e = BusinessEntitlements.fromRow(<String, dynamic>{});
      expect(e.supplierEffectivePlan, BusinessPlan.free);
      expect(e.supplierProductLimit, 1);
      expect(e.supplierCampaignLimit, 0);
      expect(e.supplierMonthlyReplyLimit, 3);
      expect(e.supplierCanAddCampaign, isFalse);
      expect(e.supplierListingFeeExempt, isFalse);
    });

    test('premium row is unlimited', () {
      final e = BusinessEntitlements.fromRow(<String, dynamic>{
        'supplier_effective_plan': 'premium',
        'supplier_product_limit': -1,
        'supplier_campaign_limit': -1,
        'supplier_monthly_reply_limit': -1,
      });
      expect(e.supplierProductsUnlimited, isTrue);
      expect(e.supplierCampaignsUnlimited, isTrue);
      expect(e.supplierRepliesUnlimited, isTrue);
    });
  });

  group('LocalSubscriptionRepository supplier derivation', () {
    test('free: one product, no campaign, three replies, not exempt', () async {
      final e = await LocalSubscriptionRepository(
        plan: BusinessPlan.free,
      ).myEntitlement();
      expect(e.supplierEffectivePlan, BusinessPlan.free);
      expect(e.supplierProductLimit, 1);
      expect(e.supplierCampaignLimit, 0);
      expect(e.supplierMonthlyReplyLimit, 3);
      expect(e.supplierCanAddCampaign, isFalse);
      expect(e.supplierListingFeeExempt, isFalse);
    });

    test(
      'legacy pro unlocks Premium in the simplified product model',
      () async {
        final e = await LocalSubscriptionRepository(
          plan: BusinessPlan.pro,
        ).myEntitlement();
        expect(e.effectivePlan, BusinessPlan.premium);
        expect(e.supplierEffectivePlan, BusinessPlan.premium);
        expect(e.supplierProductsUnlimited, isTrue);
        expect(e.supplierCampaignsUnlimited, isTrue);
        expect(e.supplierRepliesUnlimited, isTrue);
        expect(e.supplierListingFeeExempt, isTrue);
      },
    );

    test('premium is unlimited and listing exempt', () async {
      final e = await LocalSubscriptionRepository(
        plan: BusinessPlan.premium,
      ).myEntitlement();
      expect(e.supplierProductsUnlimited, isTrue);
      expect(e.supplierCampaignsUnlimited, isTrue);
      expect(e.supplierRepliesUnlimited, isTrue);
      expect(e.supplierListingFeeExempt, isTrue);
    });

    test(
      'personal launch promo does NOT unlock supplier rights '
      '(ortak kampanya bitişi kişisel promoyla uzatılamaz)',
      () async {
        final e = await LocalSubscriptionRepository(
          plan: BusinessPlan.free,
          trialActive: true,
          trialDaysLeft: 30,
        ).myEntitlement();
        // Ticari taraf promodan premium olur (davranış korunur)...
        expect(e.isLaunchPromoActive, isTrue);
        expect(e.effectivePlan, BusinessPlan.premium);
        // ...ama tedarikçi hakları YALNIZ kampanya penceresi veya ödenmiş
        // abonelikle açılır.
        expect(e.supplierEffectivePlan, BusinessPlan.free);
        expect(e.supplierProductsUnlimited, isFalse);
        expect(e.supplierListingFeeExempt, isFalse);
      },
    );
  });

  group('Commercial regression', () {
    test('commercial premium fields are preserved', () async {
      final e = await LocalSubscriptionRepository(
        plan: BusinessPlan.premium,
      ).myEntitlement();
      expect(e.isPremium, isTrue);
      expect(e.canUseBranches, isTrue);
      expect(e.dealersUnlimited, isTrue);
    });

    test('launch promo unlocks commercial premium fields', () async {
      final e = await LocalSubscriptionRepository(
        plan: BusinessPlan.free,
        trialActive: true,
      ).myEntitlement();
      expect(e.effectivePlan, BusinessPlan.premium);
      expect(e.canUseBranches, isTrue);
    });
  });
}
