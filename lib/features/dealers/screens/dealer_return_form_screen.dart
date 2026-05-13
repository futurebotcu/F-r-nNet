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
import '../../../core/widgets/product_choice_chips.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/dealer_transaction.dart';
import '../providers/dealer_providers.dart';

class DealerReturnFormScreen extends ConsumerStatefulWidget {
  const DealerReturnFormScreen({super.key, required this.dealerId});

  final String dealerId;

  @override
  ConsumerState<DealerReturnFormScreen> createState() =>
      _DealerReturnFormScreenState();
}

class _DealerReturnFormScreenState
    extends ConsumerState<DealerReturnFormScreen> {
  String? _product;
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    _unitPrice.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _onProductChanged(String p) async {
    setState(() => _product = p);
    final repo = ref.read(dealerRepositoryProvider);
    final price = await repo.currentPriceFor(
      dealerId: widget.dealerId,
      productName: p,
    );
    if (!mounted || price == null) return;
    _unitPrice.text = NumberFormatter.decimal(price.unitPrice);
  }

  double get _total {
    final q = NumberFormatter.parseLoose(_quantity.text);
    final p = NumberFormatter.parseLoose(_unitPrice.text);
    return q * p;
  }

  Future<void> _save() async {
    if (_product == null) {
      _err(AppStrings.dealerErrPickReturn);
      return;
    }
    final qty = NumberFormatter.parseLoose(_quantity.text).toInt();
    final price = NumberFormatter.parseLoose(_unitPrice.text);
    if (qty <= 0) {
      _err(AppStrings.dealerErrQtyPositive);
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final repo = ref.read(dealerRepositoryProvider);
    final now = DateTime.now();
    await repo.addTransaction(
      DealerTransaction(
        id: 'tx_${now.microsecondsSinceEpoch}',
        dealerId: widget.dealerId,
        type: DealerTransactionType.returned,
        productName: _product,
        quantity: qty,
        unitPrice: price,
        amount: qty * price,
        note: _note.text.trim(),
        createdAt: now,
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppStrings.dealerSaveSnackReturn}'
            '$qty $_product · '
            '${NumberFormatter.currency(qty * price)}'),
      ),
    );
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.dealerReturnTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            const _Label(AppStrings.dealerReturnProductLabel),
            const SizedBox(height: 8),
            ProductChoiceChips(
              selected: _product,
              onSelected: _onProductChanged,
            ),
            const SizedBox(height: AppSpacing.l),
            Row(
              children: [
                Expanded(
                  child: AppNumberField(
                    label: AppStrings.dealerDeliveryQtyLabel,
                    controller: _quantity,
                    allowDecimal: false,
                    suffix: AppStrings.dealerDeliveryQtySuffix,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: AppNumberField(
                    label: AppStrings.dealerDeliveryUnitPriceLabel,
                    controller: _unitPrice,
                    suffix: '₺',
                    hint: AppStrings.dealerReturnUnitPriceHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            ListenableBuilder(
              listenable: Listenable.merge([_quantity, _unitPrice]),
              builder: (context, _) => PremiumCard(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Row(
                  children: [
                    const Icon(
                      Icons.assignment_returned_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    const Text(
                      AppStrings.dealerReturnTotalLabel,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      '−${NumberFormatter.currency(_total)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
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
                labelText: AppStrings.dealerReturnReasonLabel,
                hintText: AppStrings.dealerReturnNoteHint,
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
