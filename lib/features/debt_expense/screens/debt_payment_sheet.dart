// Borç & Gider — ödeme ekleme sheet'i. paid_amount artırır; kalan otomatik
// düşer. Çift-submit guard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/debt_expense_entry.dart';
import '../providers/debt_expense_providers.dart';

Future<void> showDebtPaymentSheet(
  BuildContext context,
  WidgetRef ref,
  DebtExpenseEntry entry,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _PaymentSheet(entry: entry),
    ),
  );
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.entry});
  final DebtExpenseEntry entry;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = NumberFormatter.parseLoose(_amount.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tutar sıfırdan büyük olmalı.')),
      );
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(debtExpenseRepositoryProvider)
          .addPayment(widget.entry.id, amount);
      if (!mounted) return;
      Navigator.of(context).pop();
      PremiumTopBannerController.show(
        context,
        message: '${NumberFormatter.currency(amount)} ödeme eklendi.',
        tone: PremiumTopBannerTone.success,
      );
    } on GuestActionRequiredException {
      if (!mounted) return;
      await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (!mounted) return;
      PremiumTopBannerController.show(
        context,
        message: 'Ödeme eklenemedi. Tekrar dene.',
        tone: PremiumTopBannerTone.danger,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return SafeArea(
      top: false,
      child: Padding(
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
            Text(
              '${AppStrings.deAddPayment} — ${e.title}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${AppStrings.deRemaining}: ${NumberFormatter.currency(e.remaining)}',
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            AppNumberField(label: 'Ödeme tutarı', controller: _amount, suffix: '₺'),
            const SizedBox(height: AppSpacing.l),
            AppPrimaryButton(
              label: 'Ödemeyi kaydet',
              icon: Icons.check_rounded,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
