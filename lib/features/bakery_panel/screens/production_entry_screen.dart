import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/product_choice_chips.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/production_entry.dart';
import '../providers/bakery_providers.dart';

class ProductionEntryScreen extends ConsumerStatefulWidget {
  const ProductionEntryScreen({super.key});

  @override
  ConsumerState<ProductionEntryScreen> createState() =>
      _ProductionEntryScreenState();
}

class _ProductionEntryScreenState
    extends ConsumerState<ProductionEntryScreen> {
  String? _product;
  final _quantity = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final productName = _product?.trim() ?? '';
    if (productName.isEmpty) {
      _err('Önce bir ürün seç.');
      return;
    }
    final qty = NumberFormatter.parseLoose(_quantity.text).toInt();
    if (qty <= 0) {
      _err('Adet sıfırdan büyük olmalı.');
      return;
    }
    await AuthRequiredGuard.runOrPrompt(
      context,
      ref,
      action: () async {
        final repo = ref.read(bakeryRepositoryProvider);
        final now = DateTime.now();
        await repo.addProduction(
          ProductionEntry(
            id: now.microsecondsSinceEpoch.toString(),
            product: productName,
            quantity: qty,
            note: _note.text.trim(),
            createdAt: now,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Üretim kaydedildi: $qty $productName')),
        );
      },
    );
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMMM yyyy', 'tr_TR');
    return PremiumScaffold(
      appBar: AppBar(title: const Text('Üretim Gir')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Tarih · ${df.format(DateTime.now())}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            const _Label('Ürün'),
            const SizedBox(height: AppSpacing.s),
            ProductChoiceChips(
              selected: _product,
              onSelected: (v) => setState(() => _product = v),
            ),
            const SizedBox(height: AppSpacing.l),
            AppNumberField(
              label: 'Adet',
              controller: _quantity,
              allowDecimal: false,
              suffix: 'adet',
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Not (opsiyonel)',
                hintText: 'Hamur sertti, tezgah yoğundu…',
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
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.1,
      ),
    );
  }
}
