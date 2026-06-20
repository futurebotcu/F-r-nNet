import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_products.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/interactions.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../../core/widgets/product_choice_chips.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/dealer.dart';
import '../models/dealer_balance_summary.dart';
import '../models/dealer_note.dart';
import '../models/dealer_price.dart';
import '../models/dealer_transaction.dart';
import '../providers/dealer_providers.dart';
import '../repositories/driver_permission.dart';
import '../widgets/quick_payment_sheet.dart';

class DealerDetailScreen extends ConsumerWidget {
  const DealerDetailScreen({super.key, required this.dealerId});

  final String dealerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealerAsync = ref.watch(dealerByIdProvider(dealerId));
    final balanceAsync = ref.watch(balanceSummaryProvider(dealerId));
    final txAsync = ref.watch(transactionsByDealerProvider(dealerId));
    final pricesAsync = ref.watch(pricesByDealerProvider(dealerId));
    final notesAsync = ref.watch(notesByDealerProvider(dealerId));

    return PremiumScaffold(
      appBar: AppBar(
        title: dealerAsync.maybeWhen(
          data: (d) => Text(d?.name ?? AppStrings.dealerDetailFallbackTitle),
          orElse: () => const Text(AppStrings.dealerDetailFallbackTitle),
        ),
        actions: [
          dealerAsync.maybeWhen(
            data: (d) => d == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: AppStrings.dealerDetailEditTooltip,
                    onPressed: () => context.push(AppRoutes.dealerEdit(d.id)),
                    icon: const Icon(Icons.edit_rounded),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          dealerAsync.maybeWhen(
            data: (d) => d == null
                ? const SizedBox.shrink()
                : PopupMenuButton<_DealerDetailMenuAction>(
                    tooltip: AppStrings.dealerDetailStatusTooltip,
                    onSelected: (action) {
                      switch (action) {
                        case _DealerDetailMenuAction.toggleActive:
                          _confirmSetActive(context, ref, d);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem<_DealerDetailMenuAction>(
                        value: _DealerDetailMenuAction.toggleActive,
                        child: Text(
                          d.isActive
                              ? AppStrings.dealerDetailSetPassive
                              : AppStrings.dealerDetailSetActive,
                        ),
                      ),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: AppStrings.dealerDetailShareTooltip,
            onPressed: () =>
                context.push('${AppRoutes.dealers}/$dealerId/share'),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: dealerAsync.when(
          // Perf: mutation (edit/aktif-pasif/hareket) sonrası tick bu
          // provider'ı tazeler; eski veri korunur, full-screen spinner flash
          // yok. Spinner yalnız ilk yüklemede görünür.
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _DealerDetailLoadError(
            onRetry: () => ref.invalidate(dealerByIdProvider(dealerId)),
          ),
          data: (d) {
            if (d == null) {
              return const Center(child: Text(AppStrings.dealerDetailNotFound));
            }
            return ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                if (!d.isActive)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      AppSpacing.s,
                      AppSpacing.pageH,
                      0,
                    ),
                    child: _PassiveDealerNotice(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    AppSpacing.s,
                    AppSpacing.pageH,
                    0,
                  ),
                  child: balanceAsync.when(
                    skipLoadingOnReload: true,
                    loading: () => const _HeroLoading(),
                    error: (e, _) => const _SectionError('Bakiye yüklenemedi'),
                    data: (s) => FadeSlideIn(
                      child: _BalanceHero(dealer: d, summary: s),
                    ),
                  ),
                ),
                const SectionLabel(
                  title: AppStrings.dealerDetailSectionActions,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageH,
                  ),
                  child: _ActionsRow(dealerId: d.id),
                ),
                _SectionHeaderWithCta(
                  title: AppStrings.dealerDetailSectionPrices,
                  ctaLabel: AppStrings.dealerActionAddPrice,
                  onCta: () => _openPriceSheet(context, ref, d.id),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageH,
                  ),
                  child: pricesAsync.when(
                    skipLoadingOnReload: true,
                    loading: () => const _MiniLoading(),
                    error: (e, _) => const _SectionError('Fiyatlar yüklenemedi'),
                    data: (p) => _PricesCard(prices: p),
                  ),
                ),
                const SectionLabel(title: AppStrings.dealerDetailSectionTxs),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageH,
                  ),
                  child: txAsync.when(
                    skipLoadingOnReload: true,
                    loading: () => const _MiniLoading(),
                    error: (e, _) => const _SectionError('İşlemler yüklenemedi'),
                    data: (txs) => _TxList(txs: txs),
                  ),
                ),
                const SectionLabel(title: AppStrings.dealerDetailSectionNotes),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageH,
                  ),
                  child: notesAsync.when(
                    skipLoadingOnReload: true,
                    loading: () => const _MiniLoading(),
                    error: (e, _) => const _SectionError('Notlar yüklenemedi'),
                    data: (notes) => NotesCard(dealerId: d.id, notes: notes),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmSetActive(
    BuildContext context,
    WidgetRef ref,
    Dealer dealer,
  ) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }

    final nextActive = !dealer.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          nextActive
              ? AppStrings.dealerStatusActiveTitle
              : AppStrings.dealerStatusPassiveTitle,
        ),
        content: Text(
          nextActive
              ? AppStrings.dealerStatusActiveBody
              : AppStrings.dealerStatusPassiveBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              nextActive
                  ? AppStrings.dealerStatusActiveConfirm
                  : AppStrings.dealerStatusPassiveConfirm,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(dealerRepositoryProvider)
          .setActive(dealer.id, active: nextActive);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.dealerStatusUpdated)),
      );
    } on GuestActionRequiredException {
      if (!context.mounted) return;
      await showAuthRequiredSheet(context, ref);
    } on DriverPermissionException catch (e) {
      // Şoför aktif/pasif (owner) tetikledi → temiz mesaj.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.dealerStatusUpdateError)),
      );
    }
  }

  Future<void> _openPriceSheet(
    BuildContext context,
    WidgetRef ref,
    String dealerId,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => DealerPriceSheet(dealerId: dealerId),
    );
  }
}

enum _DealerDetailMenuAction { toggleActive }

class _PassiveDealerNotice extends StatelessWidget {
  const _PassiveDealerNotice();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      warm: true,
      padding: const EdgeInsets.all(AppSpacing.l),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.pause_circle_outline_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              AppStrings.dealerDetailPassiveInfo,
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _DealerDetailLoadError extends StatelessWidget {
  const _DealerDetailLoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppStrings.dealerDetailLoadError,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.m),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text(AppStrings.dealerRetry),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────── Hero

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.dealer, required this.summary});
  final Dealer dealer;
  final DealerBalanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = summary.currentBalance;
    final balanceColor = balance > 0
        ? AppColors.copper
        : balance < 0
        ? AppColors.success
        : AppColors.softGold;
    final tag = balance > 0
        ? AppStrings.dealerDetailHeroDebt
        : balance < 0
        ? AppStrings.dealerDetailHeroCredit
        : AppStrings.dealerDetailHeroClosed;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroFrom, AppColors.heroTo],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.copper.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: AppShadow.heroGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.dealerDetailHeroLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: balanceColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: balanceColor.withValues(alpha: 0.32),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: balanceColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          AnimatedNumber(
            value: balance.abs(),
            duration: const Duration(milliseconds: 720),
            builder: (_, v) => Text(
              NumberFormatter.currency(v),
              style: theme.textTheme.displaySmall?.copyWith(
                color: balanceColor,
                fontWeight: FontWeight.w800,
                fontSize: 38,
                letterSpacing: -1.2,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (dealer.area.isNotEmpty) dealer.area,
              dealer.workingType.label,
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: AppStrings.dealerDetailMetricDelivery,
                  value: NumberFormatter.currency(summary.totalDelivery),
                  color: AppColors.softGold,
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  label: AppStrings.dealerDetailMetricReturn,
                  value: NumberFormatter.currency(summary.totalReturn),
                  color: AppColors.info,
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  label: AppStrings.dealerDetailMetricPayment,
                  value: NumberFormatter.currency(summary.totalPayment),
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              _ChipMini(
                label: AppStrings.dealerDetailChipWeek,
                value: NumberFormatter.currency(summary.weekDebt),
              ),
              const SizedBox(width: 8),
              _ChipMini(
                label: AppStrings.dealerDetailChipMonth,
                value: NumberFormatter.currency(summary.monthDebt),
              ),
              const SizedBox(width: 8),
              if (summary.lastPayment != null)
                _ChipMini(
                  label: AppStrings.dealerDetailChipLastPayment,
                  value: DateFormat(
                    'd MMM',
                    'tr_TR',
                  ).format(summary.lastPayment!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChipMini extends StatelessWidget {
  const _ChipMini({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.overlay.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.softGold.withValues(alpha: 0.18),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLoading extends StatelessWidget {
  const _HeroLoading();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _MiniLoading extends StatelessWidget {
  const _MiniLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 64,
    child: Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 1.6),
      ),
    ),
  );
}

/// Faz 2 UI — bölüm içi kompakt hata satırı (ham exception sızdırmaz).
class _SectionError extends StatelessWidget {
  const _SectionError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Text(
          message,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────── Section header w/ CTA

class _SectionHeaderWithCta extends StatelessWidget {
  const _SectionHeaderWithCta({
    required this.title,
    required this.ctaLabel,
    required this.onCta,
  });
  final String title;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.xl,
        AppSpacing.pageH,
        AppSpacing.m,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.1,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          InkWell(
            onTap: onCta,
            borderRadius: BorderRadius.circular(AppRadius.s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: AppColors.softGold,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    ctaLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.softGold,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────── Actions

class _ActionsRow extends ConsumerWidget {
  const _ActionsRow({required this.dealerId});
  final String dealerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hızlı Tahsilat chip yalnız borçlu bayide görünür (Sprint 6C kural #1).
    // currentBalance <= 0 ise chip hiç render edilmez — disabled chip yok.
    final balanceAsync = ref.watch(balanceSummaryProvider(dealerId));
    final dealerAsync = ref.watch(dealerByIdProvider(dealerId));
    final hasDebt = balanceAsync.maybeWhen(
      data: (s) => s.currentBalance > 0,
      orElse: () => false,
    );
    final dealerName = dealerAsync.maybeWhen(
      data: (d) => d?.name ?? '',
      orElse: () => '',
    );
    final currentBalance = balanceAsync.maybeWhen(
      data: (s) => s.currentBalance,
      orElse: () => 0.0,
    );

    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        _ActionChip(
          icon: Icons.bakery_dining_rounded,
          label: AppStrings.dealerActionDelivery,
          onTap: () => context.push('${AppRoutes.dealers}/$dealerId/delivery'),
        ),
        _ActionChip(
          icon: Icons.assignment_returned_rounded,
          label: AppStrings.dealerActionReturn,
          accent: AppColors.info,
          onTap: () => context.push('${AppRoutes.dealers}/$dealerId/return'),
        ),
        _ActionChip(
          icon: Icons.payments_rounded,
          label: AppStrings.dealerActionPayment,
          accent: AppColors.success,
          onTap: () => context.push('${AppRoutes.dealers}/$dealerId/payment'),
        ),
        if (hasDebt)
          _ActionChip(
            icon: Icons.flash_on_rounded,
            label: AppStrings.dealerActionQuickPayment,
            accent: AppColors.success,
            onTap: () => QuickPaymentSheet.show(
              context: context,
              dealerId: dealerId,
              dealerName: dealerName,
              currentBalance: currentBalance,
            ),
          ),
        _ActionChip(
          icon: Icons.tune_rounded,
          label: AppStrings.dealerActionAdjustment,
          accent: AppColors.copper,
          onTap: () =>
              context.push('${AppRoutes.dealers}/$dealerId/adjustment'),
        ),
        _ActionChip(
          icon: Icons.analytics_outlined,
          label: AppStrings.dealerActionReport,
          accent: AppColors.info,
          onTap: () => context.push(AppRoutes.dealerReport(dealerId)),
        ),
        _ActionChip(
          icon: Icons.ios_share_rounded,
          label: AppStrings.dealerActionShare,
          accent: AppColors.copper,
          onTap: () => context.push('${AppRoutes.dealers}/$dealerId/share'),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = AppColors.softGold,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.borderHairline, width: 0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────── Prices

class _PricesCard extends StatelessWidget {
  const _PricesCard({required this.prices});
  final List<DealerPrice> prices;

  @override
  Widget build(BuildContext context) {
    if (prices.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: const Row(
          children: [
            Icon(
              Icons.price_change_outlined,
              color: AppColors.textMuted,
              size: 18,
            ),
            SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                AppStrings.dealerPricesEmpty,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < prices.length; i++) ...[
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
              ),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.softGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  color: AppColors.softGold,
                  size: 16,
                ),
              ),
              title: Text(
                prices[i].productName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                '${AppStrings.dealerPriceValidFromLabel}: '
                '${DateFormat('d MMM yyyy', 'tr_TR').format(prices[i].validFrom)}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                ),
              ),
              trailing: Text(
                NumberFormatter.currency(prices[i].unitPrice),
                style: const TextStyle(
                  color: AppColors.softGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ),
            if (i != prices.length - 1)
              const Divider(
                height: 0,
                indent: 60,
                endIndent: AppSpacing.l,
                color: AppColors.borderHairline,
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────── Price sheet (V1.1)

/// V1.4 P1.22 — Widget regresyon testi tarafından doğrudan pump
/// edilebilmesi için library-public (underscore'suz). Sadece bu dosyada
/// `showModalBottomSheet` ile construct ediliyor; UI'a yeni surface
/// eklemiyor.
class DealerPriceSheet extends ConsumerStatefulWidget {
  const DealerPriceSheet({super.key, required this.dealerId});
  final String dealerId;

  @override
  ConsumerState<DealerPriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends ConsumerState<DealerPriceSheet> {
  String? _product;
  final _price = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final productName = _product?.trim() ?? '';
    if (productName.isEmpty) {
      _err(AppStrings.dealerErrPickProduct);
      return;
    }
    final price = NumberFormatter.parseLoose(_price.text);
    if (price <= 0) {
      _err(AppStrings.dealerErrPricePositive);
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final repo = ref.read(dealerRepositoryProvider);
    final now = DateTime.now();
    try {
      await repo.addPrice(
        DealerPrice(
          id: 'p_${now.microsecondsSinceEpoch}',
          dealerId: widget.dealerId,
          productName: productName,
          unitPrice: price,
          validFrom: now,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.dealerPriceSheetSaved}'
            '$productName · ${NumberFormatter.currency(price)}',
          ),
        ),
      );
    } on GuestActionRequiredException {
      // Defense-in-depth: pre-check geçtikten sonra repo katmanı guest
      // exception atarsa sessizce yutmayalım — auth sheet aç.
      if (!mounted) return;
      await showAuthRequiredSheet(context, ref);
    } on DriverPermissionException catch (e) {
      // Şoför "Fiyat ekle" (owner) tetikledi → temiz mesaj, sheet açık kalır.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      // Sheet AÇIK kalır (Navigator.pop çağrılmaz) ki kullanıcı tek tıkla
      // tekrar deneyebilsin. Ham exception UI'a sızmaz.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.dealerPriceSaveError)),
      );
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          border: Border(
            top: BorderSide(color: AppColors.borderHairline, width: 0.6),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          AppSpacing.l,
          AppSpacing.pageH,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.l),
                decoration: BoxDecoration(
                  color: AppColors.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              AppStrings.dealerPriceSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              AppStrings.dealerPriceSheetNoteHint,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: AppSpacing.l),
            const Text(
              AppStrings.dealerPriceSheetProduct,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ProductChoiceChips(
              products: AppProducts.forAccountType(
                ref.watch(profileControllerProvider)?.accountType,
              ),
              selected: _product,
              onSelected: (v) => setState(() => _product = v),
            ),
            const SizedBox(height: AppSpacing.l),
            AppNumberField(
              label: AppStrings.dealerPriceSheetUnitPrice,
              controller: _price,
              suffix: '₺',
            ),
            const SizedBox(height: AppSpacing.l),
            AppPrimaryButton(
              label: AppStrings.dealerPriceSheetSave,
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
            const SizedBox(height: AppSpacing.s),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────── Tx list (V1.1: filtreli)

enum _TxTypeFilter { all, delivery, returned, payment, adjustment }

enum _TxRangeFilter { today, week, month, all }

class _TxList extends StatefulWidget {
  const _TxList({required this.txs});
  final List<DealerTransaction> txs;

  @override
  State<_TxList> createState() => _TxListState();
}

class _TxListState extends State<_TxList> {
  _TxTypeFilter _type = _TxTypeFilter.all;
  _TxRangeFilter _range = _TxRangeFilter.all;

  @override
  Widget build(BuildContext context) {
    if (widget.txs.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: const Row(
          children: [
            Icon(Icons.history_rounded, color: AppColors.textMuted, size: 18),
            SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                AppStrings.dealerTxsEmpty,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _apply(widget.txs);
    final dt = DateFormat('d MMM, HH:mm', 'tr_TR');

    return Column(
      children: [
        _TypeFilterRow(
          value: _type,
          onChanged: (v) => setState(() => _type = v),
        ),
        const SizedBox(height: 6),
        _RangeFilterRow(
          value: _range,
          onChanged: (v) => setState(() => _range = v),
        ),
        const SizedBox(height: AppSpacing.s),
        if (filtered.isEmpty)
          PremiumCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: const Row(
              children: [
                Icon(
                  Icons.filter_alt_off_outlined,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    AppStrings.dealerTxsNoMatch,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  _TxRow(tx: filtered[i], dt: dt),
                  if (i != filtered.length - 1)
                    const Divider(
                      height: 0,
                      indent: 60,
                      endIndent: AppSpacing.l,
                      color: AppColors.borderHairline,
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  List<DealerTransaction> _apply(List<DealerTransaction> src) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    bool typeOk(DealerTransaction t) {
      switch (_type) {
        case _TxTypeFilter.all:
          return true;
        case _TxTypeFilter.delivery:
          return t.type == DealerTransactionType.delivery;
        case _TxTypeFilter.returned:
          return t.type == DealerTransactionType.returned;
        case _TxTypeFilter.payment:
          return t.type == DealerTransactionType.payment;
        case _TxTypeFilter.adjustment:
          return t.type == DealerTransactionType.adjustment;
      }
    }

    bool rangeOk(DealerTransaction t) {
      switch (_range) {
        case _TxRangeFilter.all:
          return true;
        case _TxRangeFilter.today:
          return !t.createdAt.isBefore(today);
        case _TxRangeFilter.week:
          return !t.createdAt.isBefore(weekStart);
        case _TxRangeFilter.month:
          return !t.createdAt.isBefore(monthStart);
      }
    }

    return src.where((t) => typeOk(t) && rangeOk(t)).toList();
  }
}

class _TypeFilterRow extends StatelessWidget {
  const _TypeFilterRow({required this.value, required this.onChanged});
  final _TxTypeFilter value;
  final ValueChanged<_TxTypeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _chip(AppStrings.dealerTxFilterTypeAll, _TxTypeFilter.all),
          const SizedBox(width: 6),
          _chip(AppStrings.dealerTxFilterTypeDelivery, _TxTypeFilter.delivery),
          const SizedBox(width: 6),
          _chip(AppStrings.dealerTxFilterTypeReturn, _TxTypeFilter.returned),
          const SizedBox(width: 6),
          _chip(AppStrings.dealerTxFilterTypePayment, _TxTypeFilter.payment),
          const SizedBox(width: 6),
          _chip(
            AppStrings.dealerTxFilterTypeAdjustment,
            _TxTypeFilter.adjustment,
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _TxTypeFilter v) {
    return ChoiceChip(
      label: Text(label),
      selected: value == v,
      onSelected: (_) => onChanged(v),
    );
  }
}

class _RangeFilterRow extends StatelessWidget {
  const _RangeFilterRow({required this.value, required this.onChanged});
  final _TxRangeFilter value;
  final ValueChanged<_TxRangeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _chip(AppStrings.dealerTxFilterRangeToday, _TxRangeFilter.today),
          const SizedBox(width: 6),
          _chip(AppStrings.dealerTxFilterRangeWeek, _TxRangeFilter.week),
          const SizedBox(width: 6),
          _chip(AppStrings.dealerTxFilterRangeMonth, _TxRangeFilter.month),
          const SizedBox(width: 6),
          _chip(AppStrings.dealerTxFilterRangeAll, _TxRangeFilter.all),
        ],
      ),
    );
  }

  Widget _chip(String label, _TxRangeFilter v) {
    return ChoiceChip(
      label: Text(label),
      selected: value == v,
      onSelected: (_) => onChanged(v),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx, required this.dt});
  final DealerTransaction tx;
  final DateFormat dt;

  @override
  Widget build(BuildContext context) {
    final (icon, color, primary) = _meta(tx);
    final amount = tx.type == DealerTransactionType.delivery
        ? '+${NumberFormatter.currency(tx.amount)}'
        : tx.type == DealerTransactionType.adjustment
        ? '${tx.amount >= 0 ? '+' : '−'}'
              '${NumberFormatter.currency(tx.amount.abs())}'
        : '−${NumberFormatter.currency(tx.amount)}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.m,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  primary,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dt.format(tx.createdAt)}'
                  '${tx.note.isNotEmpty ? " · ${tx.note}" : ""}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _meta(DealerTransaction t) {
    switch (t.type) {
      case DealerTransactionType.delivery:
        return (
          Icons.bakery_dining_rounded,
          AppColors.softGold,
          '${t.productName ?? "Ürün"} x${t.quantity ?? 0}',
        );
      case DealerTransactionType.returned:
        return (
          Icons.assignment_returned_rounded,
          AppColors.info,
          '${AppStrings.dealerTxKindReturn} · '
              '${t.productName ?? "Ürün"} x${t.quantity ?? 0}',
        );
      case DealerTransactionType.payment:
        return (
          Icons.payments_rounded,
          AppColors.success,
          '${AppStrings.dealerTxKindPayment} · '
              '${t.paymentMethod?.label ?? "—"}',
        );
      case DealerTransactionType.adjustment:
        return (
          Icons.tune_rounded,
          AppColors.copper,
          AppStrings.dealerTxKindAdjustment,
        );
    }
  }
}

// ─────────────────────────────────────── Notes

/// V1.4 P1.23 — Widget regresyon testi tarafından doğrudan pump
/// edilebilmesi için sınıf library-public (underscore'suz). Sadece bu
/// dosyada construct ediliyor; UI'a yeni surface eklemiyor.
class NotesCard extends ConsumerStatefulWidget {
  const NotesCard({super.key, required this.dealerId, required this.notes});
  final String dealerId;
  final List<DealerNote> notes;

  @override
  ConsumerState<NotesCard> createState() => _NotesCardState();
}

class _NotesCardState extends ConsumerState<NotesCard> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(dealerRepositoryProvider);
    final now = DateTime.now();
    try {
      await repo.addNote(
        DealerNote(
          id: 'n_${now.microsecondsSinceEpoch}',
          dealerId: widget.dealerId,
          note: t,
          createdAt: now,
        ),
      );
      if (!mounted) return;
      _ctrl.clear();
    } catch (_) {
      if (!mounted) return;
      // Not metni input'ta korunur ki kullanıcı tek tıkla tekrar
      // deneyebilsin. Ham exception UI'a sızmaz.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.dealerNoteAddError)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = DateFormat('d MMM yyyy', 'tr_TR');
    return Column(
      children: [
        if (widget.notes.isEmpty)
          PremiumCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: const Text(
              AppStrings.dealerNotesEmpty,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < widget.notes.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                      vertical: AppSpacing.m,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.sticky_note_2_outlined,
                          size: 16,
                          color: AppColors.softGold,
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.notes[i].note,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dt.format(widget.notes[i].createdAt),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != widget.notes.length - 1)
                    const Divider(
                      height: 0,
                      indent: 50,
                      endIndent: AppSpacing.l,
                      color: AppColors.borderHairline,
                    ),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.s),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: 1,
                decoration: const InputDecoration(
                  hintText: AppStrings.dealerNotesAddHint,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _saving ? null : _add,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.copper,
                  // P0 hijyen — copper zemin üstünde beyaz ikon (standart);
                  // koyu textPrimary kontrastı düşüktü.
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
                child: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
