// Borç & Gider Defteri mini-app shell — 5 tab (Bayi Defteri pattern'i).
// Genel Bakış / Borçlar / Giderler / Personel / Raporlar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_bottom_nav.dart';
import '../models/debt_expense_entry.dart';
import '../providers/debt_expense_providers.dart';
import 'debt_expense_list_tab.dart';
import 'debt_expense_overview_tab.dart';
import 'debt_expense_reports_tab.dart';

class DebtExpenseShellScreen extends ConsumerWidget {
  const DebtExpenseShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(debtExpenseShellTabIndexProvider);
    final scaffold = Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: index,
        children: const [
          DebtExpenseOverviewTab(),
          DebtExpenseListTab(kind: DebtExpenseKind.debt),
          DebtExpenseListTab(kind: DebtExpenseKind.expense),
          DebtExpenseListTab(kind: DebtExpenseKind.staffPayment),
          DebtExpenseReportsTab(),
        ],
      ),
      bottomNavigationBar: PremiumBottomNav(
        selectedIndex: index,
        onSelect: (i) =>
            ref.read(debtExpenseShellTabIndexProvider.notifier).state = i,
        items: const [
          PremiumNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: AppStrings.deTabOverview,
          ),
          PremiumNavItem(
            icon: Icons.account_balance_wallet_outlined,
            activeIcon: Icons.account_balance_wallet_rounded,
            label: AppStrings.deTabDebts,
          ),
          PremiumNavItem(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: AppStrings.deTabExpenses,
          ),
          PremiumNavItem(
            icon: Icons.badge_outlined,
            activeIcon: Icons.badge_rounded,
            label: AppStrings.deTabStaff,
          ),
          PremiumNavItem(
            icon: Icons.analytics_outlined,
            activeIcon: Icons.analytics_rounded,
            label: AppStrings.deTabReports,
          ),
        ],
      ),
    );

    // UI-NAV-004: iç tab >0 iken Android geri → tab 0; tab 0'da normal pop.
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(debtExpenseShellTabIndexProvider.notifier).state = 0;
      },
      child: scaffold,
    );
  }
}
