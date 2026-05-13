import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/product_choice_chips.dart';
import '../models/dealer_delivery_entry.dart';
import '../providers/bakery_providers.dart';

class DealerDeliveryScreen extends ConsumerStatefulWidget {
  const DealerDeliveryScreen({super.key});

  @override
  ConsumerState<DealerDeliveryScreen> createState() =>
      _DealerDeliveryScreenState();
}

class _DealerDeliveryScreenState extends ConsumerState<DealerDeliveryScreen> {
  final _dealer = TextEditingController();
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  String? _product;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _dealer.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    super.dispose();
  }

  double get _total {
    final q = NumberFormatter.parseLoose(_quantity.text);
    final p = NumberFormatter.parseLoose(_unitPrice.text);
    return q * p;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_dealer.text.trim().isEmpty) {
      _err('Bayi adı gerekli.');
      return;
    }
    if (_product == null) {
      _err('Önce bir ürün seç.');
      return;
    }
    final qty = NumberFormatter.parseLoose(_quantity.text).toInt();
    final price = NumberFormatter.parseLoose(_unitPrice.text);
    if (qty <= 0) {
      _err('Adet sıfırdan büyük olmalı.');
      return;
    }

    final repo = ref.read(bakeryRepositoryProvider);
    await repo.addDelivery(
      DealerDeliveryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        dealerName: _dealer.text.trim(),
        product: _product!,
        quantity: qty,
        unitPrice: price,
        deliveryDate: _date,
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bayi kaydı eklendi: ${_dealer.text}')),
    );
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMMM yyyy', 'tr_TR');
    return PremiumScaffold(
      appBar: AppBar(title: const Text('Bayiye Ver')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            TextField(
              controller: _dealer,
              decoration: const InputDecoration(
                labelText: 'Bayi adı',
                hintText: 'Örn. Hamdi Bakkal',
              ),
            ),
            const SizedBox(height: AppSpacing.l),
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
                    label: 'Birim fiyat',
                    controller: _unitPrice,
                    suffix: '₺',
                  ),
                ),
              ],
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
                      'Toplam tutar',
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
            PremiumCard(
              padding: EdgeInsets.zero,
              onTap: _pickDate,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                leading: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.softGold,
                ),
                title: Text(
                  'Teslim tarihi · ${df.format(_date)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
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
