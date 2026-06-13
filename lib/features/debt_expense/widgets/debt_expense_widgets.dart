// Borç & Gider Defteri — paylaşılan kart + durum chip'i.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../data/debt_expense_categories.dart';
import '../models/debt_expense_entry.dart';

String deStatusLabel(DebtExpenseStatus s) => switch (s) {
      DebtExpenseStatus.open => AppStrings.deStatusOpen,
      DebtExpenseStatus.partial => AppStrings.deStatusPartial,
      DebtExpenseStatus.paid => AppStrings.deStatusPaid,
      DebtExpenseStatus.overdue => AppStrings.deStatusOverdue,
    };

/// Geciken = sakin amber (panik kırmızı değil — ürün kararı).
Color deStatusColor(DebtExpenseStatus s) => switch (s) {
      DebtExpenseStatus.open => AppColors.textSecondary,
      DebtExpenseStatus.partial => AppColors.brandLemonPressed,
      DebtExpenseStatus.paid => AppColors.success,
      DebtExpenseStatus.overdue => AppColors.warning,
    };

class DebtStatusChip extends StatelessWidget {
  const DebtStatusChip({super.key, required this.status});
  final DebtExpenseStatus status;

  @override
  Widget build(BuildContext context) {
    final c = deStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: c.withValues(alpha: 0.30), width: 0.6),
      ),
      child: Text(
        deStatusLabel(status),
        style: TextStyle(
          color: status == DebtExpenseStatus.partial ? AppColors.brandInk : c,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Borç/gider/personel kaydı kartı. [onTap] detay/düzenle, [onPay] ödeme.
class DebtExpenseEntryCard extends StatelessWidget {
  const DebtExpenseEntryCard({
    super.key,
    required this.entry,
    required this.today,
    this.onTap,
    this.onPay,
  });

  final DebtExpenseEntry entry;
  final DateTime today;
  final VoidCallback? onTap;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final status = entry.statusOn(today);
    final isDebtLike = entry.kind != DebtExpenseKind.expense;
    final showRemaining = isDebtLike && !entry.isClosed && entry.remaining > 0;
    final subtitleParts = <String>[
      if ((entry.category ?? '').isNotEmpty) entry.category!,
      if (entry.kind == DebtExpenseKind.staffPayment &&
          entry.staffPaymentType != null)
        StaffPaymentLabels.of(entry.staffPaymentType!),
      if (entry.dueDate != null)
        '${AppStrings.deDueDate}: ${_fmtDate(entry.dueDate!)}',
    ];

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.title.isEmpty ? '—' : entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DebtStatusChip(status: status),
            ],
          ),
          if (subtitleParts.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              subtitleParts.join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showRemaining
                          ? AppStrings.deRemaining
                          : (entry.kind == DebtExpenseKind.expense
                              ? 'Tutar'
                              : 'Toplam'),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      NumberFormatter.currency(
                          showRemaining ? entry.remaining : entry.totalAmount),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: status == DebtExpenseStatus.overdue
                            ? AppColors.warning
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (isDebtLike && entry.paidAmount > 0 && !entry.isClosed)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Toplam ${NumberFormatter.currency(entry.totalAmount)} · '
                          'Ödenen ${NumberFormatter.currency(entry.paidAmount)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onPay != null && showRemaining)
                OutlinedButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.payments_rounded, size: 16),
                  label: const Text(AppStrings.deAddPayment),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandInk,
                    side: BorderSide(
                      color: AppColors.brandLemonPressed.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
