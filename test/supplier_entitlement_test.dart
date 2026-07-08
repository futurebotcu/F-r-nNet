import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_entitlements.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tedarikçi/Toptancı Ücretlendirme Foundation V1 — client model + Local repo.
/// Server helper/gate mantığının davranışsal aynası; asıl kısıtlar DB'de canlı
/// RLS smoke (7 grup) ile doğrulanmıştır.
void main() {
  group('BusinessEntitlements.fromRow — supplier alanları', () {
    test('wholesaler pro satır tam eşlenir', () {
      final e = BusinessEntitlements.fromRow(<String, dynamic>{
        'plan': 'free',
        'effective_plan': 'free',
        'supplier_effective_plan': 'pro',
        'supplier_product_limit': 5,
        'supplier_campaign_limit': 3,
        'supplier_monthly_reply_limit': 20,
        'supplier_can_add_product': true,
        'supplier_can_add_campaign': true,
        'supplier_can_reply_quote': true,
        'supplier_listing_fee_exempt': true,
      });
      expect(e.supplierEffectivePlan, BusinessPlan.pro);
      expect(e.supplierProductLimit, 5);
      expect(e.supplierCampaignLimit, 3);
      expect(e.supplierMonthlyReplyLimit, 20);
      expect(e.supplierListingFeeExempt, isTrue);
      expect(e.supplierProductsUnlimited, isFalse);
    });

    test('eksik satır → güvenli free defaultları', () {
      final e = BusinessEntitlements.fromRow(<String, dynamic>{});
      expect(e.supplierEffectivePlan, BusinessPlan.free);
      expect(e.supplierProductLimit, 1);
      expect(e.supplierCampaignLimit, 0);
      expect(e.supplierMonthlyReplyLimit, 3);
      expect(e.supplierCanAddCampaign, isFalse);
      expect(e.supplierListingFeeExempt, isFalse);
    });

    test('premium satır → sınırsız', () {
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

  group('LocalSubscriptionRepository — supplier türetimi', () {
    test('free: 1 ürün / 0 kampanya / 3 cevap / muaf değil', () async {
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

    test('pro: 5 / 3 / 20 / muaf', () async {
      final e = await LocalSubscriptionRepository(
        plan: BusinessPlan.pro,
      ).myEntitlement();
      expect(e.supplierEffectivePlan, BusinessPlan.pro);
      expect(e.supplierProductLimit, 5);
      expect(e.supplierCampaignLimit, 3);
      expect(e.supplierMonthlyReplyLimit, 20);
      expect(e.supplierCanAddCampaign, isTrue);
      expect(e.supplierListingFeeExempt, isTrue);
    });

    test('premium: sınırsız / muaf', () async {
      final e = await LocalSubscriptionRepository(
        plan: BusinessPlan.premium,
      ).myEntitlement();
      expect(e.supplierProductsUnlimited, isTrue);
      expect(e.supplierCampaignsUnlimited, isTrue);
      expect(e.supplierRepliesUnlimited, isTrue);
      expect(e.supplierListingFeeExempt, isTrue);
    });

    test('TRIAL = PRO-benzeri (Premium DEĞİL — spam koruması)', () async {
      final e = await LocalSubscriptionRepository(
        plan: BusinessPlan.free,
        trialActive: true,
        trialDaysLeft: 30,
      ).myEntitlement();
      // Ticari effective plan premium ama tedarikçi effective plan PRO.
      expect(e.effectivePlan, BusinessPlan.premium);
      expect(e.supplierEffectivePlan, BusinessPlan.pro);
      expect(e.supplierProductLimit, 5); // sınırsız DEĞİL
      expect(e.supplierCampaignLimit, 3);
      expect(e.supplierMonthlyReplyLimit, 20);
      expect(e.supplierProductsUnlimited, isFalse);
      expect(e.supplierListingFeeExempt, isTrue);
    });
  });

  group('Commercial regresyon — supplier alanları ticari plan\'ı bozmaz', () {
    test('commercial premium: ticari alanlar korunur', () async {
      final e = await LocalSubscriptionRepository(
        plan: BusinessPlan.premium,
      ).myEntitlement();
      expect(e.isPremium, isTrue);
      expect(e.canUseBranches, isTrue);
      expect(e.dealersUnlimited, isTrue);
    });

    test('commercial trial premium davranışı bozulmadı', () async {
      final e = await LocalSubscriptionRepository(
        plan: BusinessPlan.free,
        trialActive: true,
      ).myEntitlement();
      expect(e.effectivePlan, BusinessPlan.premium);
      expect(e.canUseBranches, isTrue);
    });
  });
}
