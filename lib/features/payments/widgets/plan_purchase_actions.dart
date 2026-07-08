import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/models/bakery_profile.dart';
import '../../subscriptions/models/business_plan.dart';
import '../../subscriptions/providers/subscription_providers.dart';
import '../data/payment_service.dart';
import '../providers/payment_providers.dart';

/// PlansScreen'de store satın alma aksiyonları. Ödeme kullanılamıyorsa
/// (RevenueCat key yok) "hazırlanıyor" gösterir; SAHTE purchase YAPILMAZ.
/// Bireysel hesapta subscription satışı yok → hiçbir şey render etmez.
class PlanPurchaseActions extends ConsumerStatefulWidget {
  const PlanPurchaseActions({super.key, required this.account});

  final AccountType? account;

  @override
  ConsumerState<PlanPurchaseActions> createState() =>
      _PlanPurchaseActionsState();
}

class _PlanPurchaseActionsState extends ConsumerState<PlanPurchaseActions> {
  bool _busy = false;

  bool get _isSubscriber =>
      widget.account == AccountType.commercial ||
      widget.account == AccountType.wholesaler;

  @override
  void initState() {
    super.initState();
    // RevenueCat'i mevcut kullanıcıyla başlat (key yoksa no-op).
    final userId = ref.read(currentAuthUserProvider)?.id;
    ref.read(paymentServiceProvider).initialize(userId: userId);
  }

  Future<void> _purchase(BusinessPlan plan) async {
    final account = widget.account;
    if (account == null || _busy) return;
    setState(() => _busy = true);
    final service = ref.read(paymentServiceProvider);
    final result = await service.purchasePlan(account: account, plan: plan);
    if (!mounted) return;
    setState(() => _busy = false);
    _feedback(result);
    if (result == PaymentResult.success) {
      ref.invalidate(myEntitlementProvider);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await ref.read(paymentServiceProvider).restorePurchases();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == PaymentResult.success) {
      ref.invalidate(myEntitlementProvider);
      _snack(AppStrings.storePaymentRestored);
    } else {
      _feedback(result);
    }
  }

  void _feedback(PaymentResult result) {
    switch (result) {
      case PaymentResult.success:
        _snack(AppStrings.storePaymentSuccess);
      case PaymentResult.pending:
        _snack(AppStrings.storePaymentSuccess);
      case PaymentResult.unavailable:
        _snack(AppStrings.storePaymentPreparing);
      case PaymentResult.cancelled:
      case PaymentResult.error:
        _snack(AppStrings.storePaymentFailed);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSubscriber) return const SizedBox.shrink();
    final available = ref.watch(paymentServiceProvider).isAvailable;

    if (!available) {
      // Ödeme hazır değil → bilgilendirme (fake purchase yok).
      return Text(
        AppStrings.storePaymentPreparing,
        key: const ValueKey('store_payment_preparing'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buyButton(
          key: 'buy_pro',
          label: AppStrings.storePurchaseProCta,
          onTap: () => _purchase(BusinessPlan.pro),
        ),
        const SizedBox(height: AppSpacing.s),
        _buyButton(
          key: 'buy_premium',
          label: AppStrings.storePurchasePremiumCta,
          onTap: () => _purchase(BusinessPlan.premium),
        ),
        const SizedBox(height: AppSpacing.s),
        TextButton(
          key: const ValueKey('restore_purchases'),
          onPressed: _busy ? null : _restore,
          child: const Text(AppStrings.storePaymentRestoreCta),
        ),
      ],
    );
  }

  Widget _buyButton({
    required String key,
    required String label,
    required VoidCallback onTap,
  }) {
    return FilledButton(
      key: ValueKey(key),
      onPressed: _busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandInk,
        foregroundColor: AppColors.brandLemon,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
      ),
    );
  }
}
