import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/dealer_transaction.dart';
import '../providers/dealer_providers.dart';

class DealerPaymentFormScreen extends ConsumerStatefulWidget {
  const DealerPaymentFormScreen({super.key, required this.dealerId});

  final String dealerId;

  @override
  ConsumerState<DealerPaymentFormScreen> createState() =>
      _DealerPaymentFormScreenState();
}

class _DealerPaymentFormScreenState
    extends ConsumerState<DealerPaymentFormScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DealerPaymentMethod _method = DealerPaymentMethod.cash;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = NumberFormatter.parseLoose(_amount.text);
    if (amount <= 0) {
      _err(AppStrings.dealerErrAmountPositive);
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final repo = ref.read(dealerRepositoryProvider);
    final now = DateTime.now();
    try {
      await repo.addTransaction(
        DealerTransaction(
          id: 'tx_${now.microsecondsSinceEpoch}',
          dealerId: widget.dealerId,
          type: DealerTransactionType.payment,
          amount: amount,
          paymentMethod: _method,
          note: _note.text.trim(),
          createdAt: now,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.dealerSaveSnackPayment}'
            '${NumberFormatter.currency(amount)} (${_method.label})',
          ),
        ),
      );
    } on GuestActionRequiredException {
      // V1.4 P1.7 — Defense-in-depth: pre-check sonrası repo katmanı yine
      // guest exception atarsa auth sheet aç.
      if (!mounted) return;
      await showAuthRequiredSheet(context, ref);
    } catch (_) {
      // V1.4 P1.7 — Ham PostgrestException/network UI'a sızmaz. Form AÇIK
      // kalır (Navigator.pop çağrılmaz) ki kullanıcı tekrar deneyebilsin.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.dealerPaymentSaveError)),
      );
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.dealerPaymentTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            const _Label(AppStrings.dealerPaymentAmountLabel),
            const SizedBox(height: 8),
            AppNumberField(
              label: AppStrings.dealerPaymentReceivedLabel,
              controller: _amount,
              suffix: '₺',
            ),
            const SizedBox(height: AppSpacing.l),
            const _Label(AppStrings.dealerPaymentMethodLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in DealerPaymentMethod.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            ListenableBuilder(
              listenable: _amount,
              builder: (context, _) => PremiumCard(
                warm: true,
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_rounded,
                      color: AppColors.softGold,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    const Text(
                      AppStrings.dealerPaymentDecreasesLabel,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      '−${NumberFormatter.currency(NumberFormatter.parseLoose(_amount.text))}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.softGold,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: AppStrings.dealerFieldNote,
                hintText: AppStrings.dealerPaymentNoteHint,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            AppPrimaryButton(
              label: 'Kaydet',
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      letterSpacing: -0.1,
    ),
  );
}
