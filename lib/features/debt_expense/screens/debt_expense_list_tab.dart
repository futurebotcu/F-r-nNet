// Borç & Gider — tür bazlı liste tab'ı (Borçlar / Giderler / Personel).
// skipLoadingOnReload + premium boş/hata state + kart aksiyonları.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/debt_expense_entry.dart';
import '../providers/debt_expense_providers.dart';
import '../widgets/debt_expense_widgets.dart';
import 'debt_expense_entry_form_screen.dart';
import 'debt_payment_sheet.dart';

class DebtExpenseListTab extends ConsumerWidget {
  const DebtExpenseListTab({super.key, required this.kind});
  final DebtExpenseKind kind;

  String get _title => switch (kind) {
        DebtExpenseKind.debt => AppStrings.deTabDebts,
        DebtExpenseKind.expense => AppStrings.deTabExpenses,
        DebtExpenseKind.staffPayment => AppStrings.deTabStaff,
      };

  String get _addLabel => switch (kind) {
        DebtExpenseKind.debt => AppStrings.deAddDebt,
        DebtExpenseKind.expense => AppStrings.deAddExpense,
        DebtExpenseKind.staffPayment => AppStrings.deAddStaff,
      };

  void _openForm(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DebtExpenseEntryFormScreen(kind: kind),
    ));
  }

  Future<void> _openActions(
    BuildContext context,
    WidgetRef ref,
    DebtExpenseEntry e,
  ) async {
    final hasRemaining = !e.isClosed &&
        e.remaining > 0 &&
        e.kind != DebtExpenseKind.expense;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasRemaining)
              ListTile(
                leading: const Icon(Icons.payments_rounded,
                    color: AppColors.brandInk),
                title: const Text(AppStrings.deAddPayment),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDebtPaymentSheet(context, ref, e);
                },
              ),
            if (hasRemaining)
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded,
                    color: AppColors.success),
                title: const Text(AppStrings.deMarkPaid),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await ref.read(debtExpenseRepositoryProvider).updateEntry(
                        e.copyWith(paidAmount: e.totalAmount),
                      );
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('Sil'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _confirmDelete(context, ref, e);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DebtExpenseEntry e,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: Text('"${e.title}" kaydı silinsin mi? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(debtExpenseRepositoryProvider).deleteEntry(e.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(debtExpenseEntriesProvider(kind));
    final today = DateTime.now();
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FirinNetHeader(
              title: _title,
              showLogo: false,
              actions: [
                HeaderActionButton(
                  icon: Icons.add_rounded,
                  tooltip: _addLabel,
                  onTap: () => _openForm(context),
                ),
              ],
            ),
            const Divider(height: 1, color: AppColors.borderHairline),
            Expanded(
              child: async.when(
                skipLoadingOnReload: true,
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => ErrorRetryState(
                  onRetry: () =>
                      ref.invalidate(debtExpenseEntriesProvider(kind)),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: AppStrings.deEmptyTitle,
                      subtitle: AppStrings.deEmptySub,
                      actionLabel: _addLabel,
                      onAction: () => _openForm(context),
                    );
                  }
                  return ListView.separated(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      AppSpacing.m,
                      AppSpacing.pageH,
                      AppSpacing.xxl,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.m),
                    itemBuilder: (_, i) => DebtExpenseEntryCard(
                      entry: items[i],
                      today: today,
                      onTap: () => _openActions(context, ref, items[i]),
                      onPay: () => showDebtPaymentSheet(context, ref, items[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
