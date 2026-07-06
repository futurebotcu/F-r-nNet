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
import '../models/waste_entry.dart';
import '../providers/bakery_providers.dart';

class WasteEntryScreen extends ConsumerStatefulWidget {
  const WasteEntryScreen({super.key});

  @override
  ConsumerState<WasteEntryScreen> createState() => _WasteEntryScreenState();
}

class _WasteEntryScreenState extends ConsumerState<WasteEntryScreen> {
  String? _product;
  WasteReason? _reason;
  final _quantity = TextEditingController();
  final _unitValue = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    _unitValue.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _estimatedLoss {
    final q = NumberFormatter.parseLoose(_quantity.text);
    final v = NumberFormatter.parseLoose(_unitValue.text);
    return q * v;
  }

  Future<void> _save() async {
    if (_saving) return;
    final productName = _product?.trim() ?? '';
    if (productName.isEmpty) {
      _err('Önce bir ürün seç.');
      return;
    }
    final qty = NumberFormatter.parseLoose(_quantity.text).toInt();
    final value = NumberFormatter.parseLoose(_unitValue.text);
    if (qty <= 0) {
      _err('Adet sıfırdan büyük olmalı.');
      return;
    }
    final reason = _reason;
    if (reason == null) {
      _err(AppStrings.ledgerWasteReasonRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthRequiredGuard.runOrPrompt(
        context,
        ref,
        action: () async {
          final repo = ref.read(bakeryRepositoryProvider);
          final now = DateTime.now();
          await repo.addWaste(
            WasteEntry(
              id: now.microsecondsSinceEpoch.toString(),
              product: productName,
              quantity: qty,
              unitValue: value,
              note: _note.text.trim(),
              createdAt: now,
              reason: reason,
            ),
          );
          if (!mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fire kaydedildi: $qty $productName')),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(title: const Text('Fire Gir')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            const Text(
              'Ürün',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            ProductChoiceChips(
              selected: _product,
              onSelected: (v) => setState(() => _product = v),
            ),
            const SizedBox(height: AppSpacing.l),
            Row(
              children: [
                Expanded(
                  child: AppNumberField(
                    label: 'Adet',
                    controller: _quantity,
                    allowDecimal: false,
                    suffix: 'adet',
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: AppNumberField(
                    label: 'Birim değer',
                    controller: _unitValue,
                    suffix: '₺',
                    hint: 'maliyet / satış',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            ListenableBuilder(
              listenable: Listenable.merge([_quantity, _unitValue]),
              builder: (context, _) => PremiumCard(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_down_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    const Text(
                      'Tahmini zarar',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      NumberFormatter.currency(_estimatedLoss),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            const Text(
              AppStrings.ledgerWasteReasonField,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in WasteReason.values)
                  ChoiceChip(
                    key: ValueKey('waste_reason_${r.persistKey}'),
                    label: Text(r.label),
                    selected: _reason == r,
                    onSelected: (_) => setState(() => _reason = r),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedColor: AppColors.brandLemonPale,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Not (opsiyonel)',
                hintText: 'Tezgahta kalan, müşteri iadesi…',
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            AppPrimaryButton(
              label: _saving ? 'Kaydediliyor…' : 'Kaydet',
              icon: Icons.check_rounded,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
