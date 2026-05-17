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

/// Bayi cari bakiyesini elle ayarlamak için form (V1.1).
/// Tutar pozitif girilir, yön segment ile seçilir → işaretli `amount`
/// adjustment olarak kaydedilir. Not zorunludur.
class DealerAdjustmentFormScreen extends ConsumerStatefulWidget {
  const DealerAdjustmentFormScreen({super.key, required this.dealerId});

  final String dealerId;

  @override
  ConsumerState<DealerAdjustmentFormScreen> createState() =>
      _DealerAdjustmentFormScreenState();
}

enum _AdjustDirection { add, subtract }

class _DealerAdjustmentFormScreenState
    extends ConsumerState<DealerAdjustmentFormScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  _AdjustDirection _direction = _AdjustDirection.add;
  bool _noteErr = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = NumberFormatter.parseLoose(_amount.text);
    final note = _note.text.trim();
    setState(() => _noteErr = note.isEmpty);
    if (raw <= 0) {
      _err(AppStrings.dealerErrAmountPositive);
      return;
    }
    if (note.isEmpty) {
      _err(AppStrings.dealerAdjustmentNoteRequired);
      return;
    }
    final signed = _direction == _AdjustDirection.add ? raw : -raw;
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
          type: DealerTransactionType.adjustment,
          amount: signed,
          note: note,
          createdAt: now,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      final sign = signed >= 0 ? '+' : '−';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.dealerSaveSnackAdjustment}'
              '$sign${NumberFormatter.currency(signed.abs())}'),
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
        const SnackBar(content: Text(AppStrings.dealerAdjustmentSaveError)),
      );
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final amount = NumberFormatter.parseLoose(_amount.text);
    final preview = _direction == _AdjustDirection.add ? amount : -amount;
    final previewColor = preview >= 0 ? AppColors.copper : AppColors.success;
    final previewSign = preview >= 0 ? '+' : '−';

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.dealerAdjustmentTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            const _Label(AppStrings.dealerAdjustmentDirectionLabel),
            const SizedBox(height: 8),
            SegmentedButton<_AdjustDirection>(
              segments: const [
                ButtonSegment(
                  value: _AdjustDirection.add,
                  label: Text(AppStrings.dealerAdjustmentDirectionAdd),
                  icon: Icon(Icons.add_rounded),
                ),
                ButtonSegment(
                  value: _AdjustDirection.subtract,
                  label: Text(AppStrings.dealerAdjustmentDirectionSubtract),
                  icon: Icon(Icons.remove_rounded),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (s) =>
                  setState(() => _direction = s.first),
            ),
            const SizedBox(height: AppSpacing.l),
            const _Label(AppStrings.dealerPaymentAmountLabel),
            const SizedBox(height: 8),
            AppNumberField(
              label: AppStrings.dealerPaymentReceivedLabel,
              controller: _amount,
              suffix: '₺',
            ),
            const SizedBox(height: AppSpacing.s),
            ListenableBuilder(
              listenable: _amount,
              builder: (_, __) => PremiumCard(
                warm: true,
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Row(
                  children: [
                    Icon(
                      _direction == _AdjustDirection.add
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: previewColor,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      _direction == _AdjustDirection.add
                          ? AppStrings.dealerAdjustmentDirectionAdd
                          : AppStrings.dealerAdjustmentDirectionSubtract,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      '$previewSign${NumberFormatter.currency(preview.abs())}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: previewColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            const _Label(AppStrings.dealerAdjustmentNoteLabel),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              maxLines: 3,
              onChanged: (_) {
                if (_noteErr) setState(() => _noteErr = false);
              },
              decoration: InputDecoration(
                hintText: AppStrings.dealerAdjustmentNoteHint,
                errorText: _noteErr
                    ? AppStrings.dealerAdjustmentNoteRequired
                    : null,
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
