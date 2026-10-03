import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_feedback.dart';
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
    try {
      // configure/logIn istisnası (ör. çevrimdışı) yakalanmazsa microtask'ta
      // işlenmemiş hata olur; fiyatlar config fallback'inde kalır.
      await service.initialize(userId: userId);
      if (!mounted || !service.isAvailable) return;
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
    var result = PaymentResult.error;
    try {
      // configure/logIn platform istisnası (ör. çevrimdışı) butonu kalıcı
      // kilitlememeli; başarısız işlem olarak bildirilir (ham hata gösterilmez).
      final service = ref.read(paymentServiceProvider);
      await service.initialize(userId: userId);
      result = await service.purchaseProduct(productId: productId);
    } catch (_) {
      result = PaymentResult.error;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
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
    var result = PaymentResult.error;
    try {
      await service.initialize(userId: userId);
      result = await service.restorePurchases();
    } catch (_) {
      result = PaymentResult.error;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (result == PaymentResult.success) {
      ref.invalidate(myEntitlementProvider);
      AppFeedback.success(context, AppStrings.storePaymentRestored);
    } else {
      _feedback(result);
    }
  }

  void _feedback(PaymentResult result) {
    switch (result) {
      case PaymentResult.success:
      case PaymentResult.pending:
        AppFeedback.success(context, AppStrings.storePaymentSuccess);
      case PaymentResult.unavailable:
        AppFeedback.info(context, AppStrings.storePaymentPreparing);
      case PaymentResult.cancelled:
        AppFeedback.info(context, AppStrings.finalStorePaymentCancelled);
      case PaymentResult.error:
        AppFeedback.error(context, AppStrings.finalStorePaymentFailed);
    }
  }

  void _snack(String msg) => AppFeedback.info(context, msg);

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
        style: AppTypography.infoLabel.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
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
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size.fromHeight(48),
            textStyle: AppTypography.buttonLabel,
          ),
          child: const Text(
            AppStrings.storePaymentRestoreCta,
            textAlign: TextAlign.center,
          ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
      ),
      // Dar ekran / büyük yazıda fiyat kesilmez: etiket 2 satıra iner,
      // rozet alta kayar (Wrap).
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.s,
        runSpacing: 2,
        children: [
          Text(
            '$label · $price',
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.buttonLabel,
          ),
          if (badge != null)
            Text(
              badge,
              style: AppTypography.badge.copyWith(color: AppColors.brandLemon),
            ),
        ],
      ),
    );
  }
}
