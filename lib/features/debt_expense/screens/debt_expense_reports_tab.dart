// Borç & Gider — Raporlar: basit özet (gider/borç/personel/kapanan/vade/
// geciken). Büyük finansal rapor/PDF V1 kapsamında değil.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../providers/debt_expense_providers.dart';

class DebtExpenseReportsTab extends ConsumerWidget {
  const DebtExpenseReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(debtExpenseSummaryProvider);
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const FirinNetHeader(
              title: AppStrings.deTabReports,
              subtitle: 'Borç, gider ve personel özeti',
              showLogo: false,
            ),
            const Divider(height: 1, color: AppColors.borderHairline),
            Expanded(
              child: summaryAsync.when(
                skipLoadingOnReload: true,
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
                data: (s) => ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    AppSpacing.l,
                    AppSpacing.pageH,
                    AppSpacing.xxl,
                  ),
                  children: [
                    _ReportRow(
                      icon: Icons.trending_down_rounded,
                      label: AppStrings.deThisMonthExpense,
                      value: NumberFormatter.currency(s.thisMonthExpense),
                    ),
                    _ReportRow(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Açık borç toplamı',
                      value: NumberFormatter.currency(s.openDebtTotal),
                    ),
                    _ReportRow(
                      icon: Icons.badge_rounded,
                      label: 'Ödenecek personel',
                      value: NumberFormatter.currency(s.staffPayableTotal),
                    ),
                    _ReportRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Kapanan borç sayısı',
                      value: '${s.closedDebtCount}',
                      accent: AppColors.success,
                    ),
                    _ReportRow(
                      icon: Icons.event_available_rounded,
                      label: 'Bu hafta vade',
                      value: '${s.upcomingThisWeek}',
                    ),
                    _ReportRow(
                      icon: Icons.schedule_rounded,
                      label: 'Geciken ödeme',
                      value: s.overdueCount == 0
                          ? '0'
                          : '${s.overdueCount} · ${NumberFormatter.currency(s.overdueTotal)}',
                      accent: s.overdueCount > 0 ? AppColors.warning : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.brandInk;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (accent ?? AppColors.brandLemonPressed)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              child: Icon(icon, color: c, size: 19),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
