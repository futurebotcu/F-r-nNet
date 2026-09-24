import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/feature_lock.dart';
import '../providers/subscription_providers.dart';

/// Kilitli bir özelliğe basıldığında açılan bilgilendirme sheet'i.
///
/// Ödeme YOK — yalnız hangi paketin açtığını anlatır + Paketler ekranına
/// yönlendirir. Asıl kısıt server-side'da.
Future<void> showPaywallSheet(
  BuildContext context,
  FeatureLock lock, {
  VoidCallback? onUnlocked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => _PaywallSheetBody(
      lock: lock,
      onUnlocked: onUnlocked,
    ),
  );
}

class _PaywallSheetBody extends ConsumerStatefulWidget {
  const _PaywallSheetBody({required this.lock, this.onUnlocked});

  final FeatureLock lock;
  final VoidCallback? onUnlocked;

  @override
  ConsumerState<_PaywallSheetBody> createState() => _PaywallSheetBodyState();
}

class _PaywallSheetBodyState extends ConsumerState<_PaywallSheetBody> {
  bool _busy = false;

  Future<void> _startPromo() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.activateLaunchPremiumPromo();
      ref.invalidate(myEntitlementProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onUnlocked?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.paywallPromoFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(myEntitlementProvider).valueOrNull;
    final showPromo = entitlement?.canStartPromo ?? true;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          key: const ValueKey('paywall_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.brandLemonPale,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 20,
                    color: AppColors.brandInk,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandInk,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    showPromo
                        ? AppStrings.paywallPremiumTag
                        : widget.lock.requiredPlanTag,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandLemon,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              showPromo ? AppStrings.paywallPromoTitle : widget.lock.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              showPromo ? AppStrings.paywallPromoBody : widget.lock.body,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            if (showPromo) ...[
              const SizedBox(height: AppSpacing.s),
              const _PromoBullet(AppStrings.paywallPromoBulletAll),
              const _PromoBullet(AppStrings.paywallPromoBulletCard),
              const _PromoBullet(AppStrings.paywallPromoBulletPayment),
              const _PromoBullet(AppStrings.paywallPromoBulletNoRenew),
            ] else if (widget.lock.priceHint.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              Row(
                children: [
                  const Icon(
                    Icons.sell_outlined,
                    size: 15,
                    color: AppColors.brandInk,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.lock.priceHint,
                    key: const ValueKey('paywall_price_hint'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandInk,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.l),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('paywall_view_plans'),
                onPressed: _busy ? null : () {
                  if (showPromo) {
                    _startPromo();
                  } else {
                    Navigator.of(context).pop();
                    GoRouter.of(context).push(AppRoutes.plans);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.brandInk,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
                child: Text(
                  showPromo
                      ? AppStrings.paywallPromoCta
                      : AppStrings.paywallUpgradeCta,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoBullet extends StatelessWidget {
  const _PromoBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
