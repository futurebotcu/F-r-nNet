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

class DealerDeliveryFormScreen extends ConsumerStatefulWidget {
  const DealerDeliveryFormScreen({super.key, required this.dealerId});

  final String dealerId;

  @override
  ConsumerState<DealerDeliveryFormScreen> createState() =>
      _DealerDeliveryFormScreenState();
}

class _DealerDeliveryFormScreenState
    extends ConsumerState<DealerDeliveryFormScreen> {
  String? _product;
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _note = TextEditingController();
  bool _autoFilledFromPrice = false;

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
    if (!mounted) return;
    if (price != null) {
      _unitPrice.text = NumberFormatter.decimal(price.unitPrice);
      setState(() => _autoFilledFromPrice = true);
    } else {
      _unitPrice.clear();
      setState(() => _autoFilledFromPrice = false);
    }
  }

  double get _total {
    final q = NumberFormatter.parseLoose(_quantity.text);
    final p = NumberFormatter.parseLoose(_unitPrice.text);
    return q * p;
  }

  Future<void> _save() async {
    final productName = _product?.trim() ?? '';
    if (productName.isEmpty) {
      _err(AppStrings.dealerErrPickProduct);
      return;
    }
    final qty = NumberFormatter.parseLoose(_quantity.text).toInt();
    final price = NumberFormatter.parseLoose(_unitPrice.text);
    if (qty <= 0) {
      _err(AppStrings.dealerErrQtyPositive);
      return;
    }
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
      await repo.addTransaction(
        DealerTransaction(
          id: 'tx_${now.microsecondsSinceEpoch}',
          dealerId: widget.dealerId,
          type: DealerTransactionType.delivery,
          productName: productName,
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
          content: Text(
            '${AppStrings.dealerSaveSnackDelivery}'
            '$qty $productName · '
            '${NumberFormatter.currency(qty * price)}',
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
        const SnackBar(content: Text(AppStrings.dealerDeliverySaveError)),
      );
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dealerAsync = ref.watch(dealerByIdProvider(widget.dealerId));

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.dealerDeliveryTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            dealerAsync.when(
              loading: () => const SizedBox(height: 18),
              error: (e, _) => Text('Bayi: $e'),
              data: (d) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.l),
                child: _DealerStrip(
                  name: d?.name ?? AppStrings.dealerDetailFallbackTitle,
                ),
              ),
            ),
            const _Label(AppStrings.dealerDeliveryProductLabel),
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
                    hint: _autoFilledFromPrice
                        ? AppStrings.dealerDeliveryUnitPriceHintAuto
                        : null,
                  ),
                ),
              ],
            ),
            if (_autoFilledFromPrice)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: AppColors.softGold,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      AppStrings.dealerDeliveryAutoPriceMsg,
                      style: TextStyle(
                        color: AppColors.softGold,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.s),
            ListenableBuilder(
              listenable: Listenable.merge([_quantity, _unitPrice]),
              builder: (context, _) => PremiumCard(
                warm: true,
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calculate_outlined,
                      color: AppColors.softGold,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    const Text(
                      AppStrings.dealerDeliveryTotalLabel,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      NumberFormatter.currency(_total),
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
                hintText: AppStrings.dealerDeliveryNoteHint,
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
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.1,
      ),
    );
  }
}

class _DealerStrip extends StatelessWidget {
  const _DealerStrip({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.m,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.storefront_rounded,
            color: AppColors.softGold,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.s),
          const Text(
            AppStrings.dealerDeliveryStripLabel,
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
