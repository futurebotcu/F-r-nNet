import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/stat_card.dart';
import '../models/daily_summary.dart';
import '../providers/bakery_providers.dart';

class EndOfDayScreen extends ConsumerWidget {
  const EndOfDayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySummaryProvider);
    final df = DateFormat('d MMMM yyyy, EEEE', 'tr_TR');

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.endOfDay)),
      body: SafeArea(
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetryState(
            onRetry: () => ref.invalidate(todaySummaryProvider),
          ),
          data: (DailySummary s) {
            if (s.isEmpty) {
              return EmptyState(
                title: AppStrings.emptyDay,
                subtitle:
                    'Üretim, bayi veya fire girişi yaptığında burada özetleyeceğim.',
                icon: Icons.nightlight_outlined,
                actionLabel: 'Üretim Gir',
                onAction: () => GoRouter.of(context).push(AppRoutes.production),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                0,
                AppSpacing.pageH,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  df.format(s.day).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                StatCard(
                  warm: true,
                  hero: true,
                  icon: Icons.summarize_outlined,
                  label: 'Net özet',
                  value: NumberFormatter.currency(s.netAmount),
                  helper: 'Bayi tutarı – tahmini zarar',
                  accent: AppColors.softGold,
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.bakery_dining_outlined,
                        label: 'Üretim',
                        value:
                            '${NumberFormatter.integer(s.totalProduction)} adet',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: StatCard(
                        icon: Icons.local_shipping_outlined,
                        label: 'Bayi',
                        value:
                            '${NumberFormatter.integer(s.totalDelivered)} adet',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.payments_outlined,
                        label: 'Bayi tutarı',
                        value: NumberFormatter.currency(s.totalDealerAmount),
                        accent: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: StatCard(
                        icon: Icons.delete_sweep_outlined,
                        label: 'Fire',
                        value: '${NumberFormatter.integer(s.totalWaste)} adet',
                        accent: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                StatCard(
                  icon: Icons.trending_down_outlined,
                  label: 'Tahmini zarar',
                  value: NumberFormatter.currency(s.totalEstimatedLoss),
                  accent: AppColors.danger,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
