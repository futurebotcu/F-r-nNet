import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/models/bakery_profile.dart';
import '../../subscriptions/models/pricing_config.dart';
import '../../subscriptions/providers/subscription_providers.dart';
import '../data/payment_service.dart';
import '../models/store_product_config.dart';
import '../providers/payment_providers.dart';

/// PlansScreen'de store satin alma aksiyonlari. Yeni modelde yalniz Premium
/// aylik/yillik satilir. Store localized price varsa UI onu kullanir; config
/// fiyatlari yalniz fallback'tir.
class PlanPurchaseActions extends ConsumerStatefulWidget {
  const PlanPurchaseActions({super.key, required this.account});

  final AccountType? account;

  @override
  ConsumerState<PlanPurchaseActions> createState() =>
      _PlanPurchaseActionsState();
}

class _PlanPurchaseActionsState extends ConsumerState<PlanPurchaseActions> {
  bool _busy = false;
  Map<String, StorePrice> _prices = const <String, StorePrice>{};

  bool get _isSubscriber =>
      widget.account == AccountType.commercial ||
      widget.account == AccountType.wholesaler;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initAndLoadPrices);
  }

  Future<void> _initAndLoadPrices() async {
    if (!_isSubscriber) return;
    final userId = ref.read(currentAuthUserProvider)?.id;
    if (userId == null) return;
    final service = ref.read(paymentServiceProvider);
    await service.initialize(userId: userId);
    if (!mounted || !service.isAvailable) return;
    try {
      final ids = StoreProductConfig.premiumProductIdsFor(widget.account);
      final prices = await service.fetchStorePrices(ids);
      if (mounted) setState(() => _prices = prices);
    } catch (_) {
      // Fallback labels remain visible; purchase flow will surface real errors.
    }
  }

  Future<void> _purchase(String productId) async {
    if (_busy) return;
    final userId = ref.read(currentAuthUserProvider)?.id;
    if (userId == null) {
      _snack(AppStrings.authGuestDataWriteBlock);
      return;
    }
    setState(() => _busy = true);
    await ref.read(paymentServiceProvider).initialize(userId: userId);
    final result = await ref
        .read(paymentServiceProvider)
        .purchaseProduct(productId: productId);
    if (!mounted) return;
    setState(() => _busy = false);
    _feedback(result);
    if (result == PaymentResult.success || result == PaymentResult.pending) {
      ref.invalidate(myEntitlementProvider);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    final userId = ref.read(currentAuthUserProvider)?.id;
    if (userId == null) {
      _snack(AppStrings.authGuestDataWriteBlock);
      return;
    }
    setState(() => _busy = true);
    final service = ref.read(paymentServiceProvider);
    await service.initialize(userId: userId);
    final result = await service.restorePurchases();
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
    final service = ref.watch(paymentServiceProvider);
    final available = service.isAvailable;

    if (!available) {
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

    final monthly = StoreProductConfig.premiumMonthly;
    final yearly = StoreProductConfig.premiumYearly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buyButton(
          key: 'buy_premium_monthly',
          label: AppStrings.storePurchaseMonthlyCta,
          price:
              _prices[monthly]?.priceLabel ?? PricingConfig.premiumMonthlyLabel,
          onTap: () => _purchase(monthly),
        ),
        const SizedBox(height: AppSpacing.s),
        _buyButton(
          key: 'buy_premium_yearly',
          label: AppStrings.storePurchaseYearlyCta,
          price:
              _prices[yearly]?.priceLabel ?? PricingConfig.premiumYearlyLabel,
          badge: AppStrings.storePurchaseYearlySavings,
          onTap: () => _purchase(yearly),
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
    required String price,
    required VoidCallback onTap,
    String? badge,
  }) {
    return FilledButton(
      key: ValueKey(key),
      onPressed: _busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandInk,
        foregroundColor: AppColors.brandLemon,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '$label · $price',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Text(
              badge,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
