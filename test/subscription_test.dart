import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_entitlements.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticari İşletme Ücretlendirme Foundation V1 — client model + Local repo.
/// Local repo, server `my_entitlement`/helper türetiminin davranışsal
/// aynasıdır; asıl gate'ler DB'de canlı smoke ile doğrulanmıştır (8 faz PASS).
void main() {
  group('BusinessPlan taksonomisi', () {
    test('persistKey round-trip + bilinmeyen → free', () {
      for (final p in BusinessPlan.values) {
        expect(BusinessPlanMeta.fromKey(p.persistKey), p);
      }
      expect(BusinessPlanMeta.fromKey(null), BusinessPlan.free);
      expect(BusinessPlanMeta.fromKey('gold'), BusinessPlan.free);
    });
  });

  group('BusinessEntitlements.fromRow (my_entitlement RPC eşlemesi)', () {
    test('premium satır tam eşlenir', () {
      final e = BusinessEntitlements.fromRow(<String, dynamic>{
        'plan': 'premium',
        'effective_plan': 'premium',
        'is_trial_active': false,
        'trial_ends_at': null,
        'days_left': 0,
        'recipe_limit': -1,
        'dealer_limit': -1,
        'can_use_branches': true,
        'can_use_debt_expense': true,
        'can_use_dealer_driver_ops': true,
      });
      expect(e.isPremium, isTrue);
      expect(e.recipesUnlimited, isTrue);
      expect(e.dealersUnlimited, isTrue);
      expect(e.canUseBranches, isTrue);
      expect(e.canAddRecipe(999), isTrue);
      expect(e.canAddDealer(50), isTrue);
    });

    test('trial satır: actual free ama effective premium', () {
      final e = BusinessEntitlements.fromRow(<String, dynamic>{
        'plan': 'free',
        'effective_plan': 'premium',
        'is_trial_active': true,
        'trial_ends_at': '2026-08-06T00:00:00Z',
        'days_left': 30,
        'recipe_limit': -1,
        'dealer_limit': -1,
        'can_use_branches': true,
        'can_use_debt_expense': true,
        'can_use_dealer_driver_ops': true,
      });
      expect(e.plan, BusinessPlan.free);
      expect(e.effectivePlan, BusinessPlan.premium);
      expect(e.isTrialActive, isTrue);
      expect(e.daysLeft, 30);
      expect(e.trialEndsAt, isNotNull);
    });

    test('eksik/bozuk satır → güvenli free defaultları', () {
      final e = BusinessEntitlements.fromRow(<String, dynamic>{});
      expect(e.plan, BusinessPlan.free);
      expect(e.recipeLimit, 5);
      expect(e.dealerLimit, 0);
      expect(e.canUseBranches, isFalse);
    });
  });

  group('canAddRecipe / canAddDealer (UX aynası)', () {
    test('free limitleri', () {
      const e = BusinessEntitlements(
        plan: BusinessPlan.free,
        effectivePlan: BusinessPlan.free,
        recipeLimit: 5,
        dealerLimit: 0,
      );
      expect(e.canAddRecipe(4), isTrue);
      expect(e.canAddRecipe(5), isFalse);
      expect(e.canAddDealer(0), isFalse); // free bayi açamaz
    });

    test('pro limitleri: bayi SINIRSIZ (sayı limiti yok), şoför kapalı', () {
      const e = BusinessEntitlements(
        plan: BusinessPlan.pro,
        effectivePlan: BusinessPlan.pro,
        recipeLimit: 50,
        dealerLimit: -1, // Pro sınırsız bayi (fix)
        canUseDebtExpense: true,
      );
      expect(e.canAddRecipe(49), isTrue);
      expect(e.canAddRecipe(50), isFalse);
      // Pro artık sınırsız bayi açar — sayı limiti YOK.
      expect(e.dealerEnabled, isTrue);
      expect(e.dealersUnlimited, isTrue);
      expect(e.canAddDealer(0), isTrue);
      expect(e.canAddDealer(5), isTrue);
      expect(e.canAddDealer(99), isTrue);
      // Pro↔Premium ayrımı: şoförlü operasyon.
      expect(e.canUseDealerDriverOps, isFalse);
      expect(e.canUseDebtExpense, isTrue);
      expect(e.canUseBranches, isFalse);
    });

    test('free: Bayi Defteri kapalı', () {
      const e = BusinessEntitlements(
        plan: BusinessPlan.free,
        effectivePlan: BusinessPlan.free,
        dealerLimit: 0,
      );
      expect(e.dealerEnabled, isFalse);
      expect(e.canAddDealer(0), isFalse);
    });
  });

  group('LocalSubscriptionRepository (server türetimi aynası)', () {
    test(
      'free: limitler + feature\'lar kapalı (Bayi Defteri kapalı)',
      () async {
        final repo = LocalSubscriptionRepository(plan: BusinessPlan.free);
        final e = await repo.myEntitlement();
        expect(e.effectivePlan, BusinessPlan.free);
        expect(e.recipeLimit, 5);
        expect(e.dealerLimit, 0);
        expect(e.dealerEnabled, isFalse);
        expect(e.canUseBranches, isFalse);
        expect(e.canUseDebtExpense, isFalse);
        expect(e.canUseDealerDriverOps, isFalse);
      },
    );

    test('pro: debt+bayi(sınırsız) açık, branches/driver kapalı', () async {
      final repo = LocalSubscriptionRepository(plan: BusinessPlan.pro);
      final e = await repo.myEntitlement();
      expect(e.effectivePlan, BusinessPlan.pro);
      expect(e.dealerLimit, -1); // sınırsız bayi (fix)
      expect(e.dealerEnabled, isTrue);
      expect(e.dealersUnlimited, isTrue);
      expect(e.recipeLimit, 50);
      expect(e.canUseDebtExpense, isTrue);
      expect(e.canUseBranches, isFalse);
      expect(e.canUseDealerDriverOps, isFalse); // şoför Premium
    });

    test('premium: hepsi açık, sınırsız', () async {
      final repo = LocalSubscriptionRepository(plan: BusinessPlan.premium);
      final e = await repo.myEntitlement();
      expect(e.isPremium, isTrue);
      expect(e.recipesUnlimited, isTrue);
      expect(e.dealersUnlimited, isTrue);
      expect(e.canUseBranches, isTrue);
      expect(e.canUseDealerDriverOps, isTrue);
    });

    test('trial aktif: actual free ama effective premium', () async {
      final repo = LocalSubscriptionRepository(
        plan: BusinessPlan.free,
        trialActive: true,
        trialDaysLeft: 21,
      );
      final e = await repo.myEntitlement();
      expect(e.plan, BusinessPlan.free);
      expect(e.effectivePlan, BusinessPlan.premium);
      expect(e.isTrialActive, isTrue);
      expect(e.daysLeft, 21);
      expect(e.canUseBranches, isTrue);
    });

    test('ensureMyEntitlement idempotent çağrı sayacı', () async {
      final repo = LocalSubscriptionRepository();
      await repo.ensureMyEntitlement();
      await repo.ensureMyEntitlement();
      expect(repo.ensureCalls, 2);
    });
  });
}
