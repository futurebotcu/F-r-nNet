import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/evening_discount_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Akşam İndirim Robotu ekranı (patron modülü).
/// Matematik [EveningDiscountCalculator] servisindedir.
class EveningDiscountScreen extends StatefulWidget {
  const EveningDiscountScreen({super.key});

  @override
  State<EveningDiscountScreen> createState() => _EveningDiscountScreenState();
}

class _EveningDiscountScreenState extends State<EveningDiscountScreen> {
  static const EveningDiscountCalculator _calc = EveningDiscountCalculator();

  final _remaining = TextEditingController(text: '40');
  final _costPerUnit = TextEditingController(text: '5');
  final _normalPrice = TextEditingController(text: '7.5');
  final _targetProfit = TextEditingController(text: '0.5');

  DiscountMode _mode = DiscountMode.breakeven;
  EveningDiscountResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _remaining.dispose();
    _costPerUnit.dispose();
    _normalPrice.dispose();
    _targetProfit.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        remainingCount: NumberFormatter.parseLoose(_remaining.text),
        costPerUnit: NumberFormatter.parseLoose(_costPerUnit.text),
        normalPrice: NumberFormatter.parseLoose(_normalPrice.text),
        mode: _mode,
        targetMinProfitPerUnit: NumberFormatter.parseLoose(_targetProfit.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcEveningDiscountTitle,
      hint: 'Elde kalan ürünü zarar etmeden eritmek için minimum fiyat.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Elde kalan adet',
          controller: _remaining,
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Ürün başı maliyet',
          controller: _costPerUnit,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Normal satış fiyatı',
          controller: _normalPrice,
          suffix: '₺',
        ),
        DropdownButtonFormField<DiscountMode>(
          initialValue: _mode,
          decoration: const InputDecoration(labelText: 'Hedef'),
          items: const [
            DropdownMenuItem(
              value: DiscountMode.breakeven,
              child: Text('Başabaş (zarar etme)'),
            ),
            DropdownMenuItem(
              value: DiscountMode.minProfit,
              child: Text('Hedef minimum kâr'),
            ),
          ],
          onChanged: (m) {
            if (m == null) return;
            setState(() => _mode = m);
            _recalculate();
          },
        ),
        if (_mode == DiscountMode.minProfit)
          AppNumberField(
            label: 'Hedef minimum kâr (adet)',
            controller: _targetProfit,
            suffix: '₺',
          ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              lines: [
                CalcResultLine(
                  'Minimum satış fiyatı',
                  NumberFormatter.currency(r.minSalePrice),
                  icon: Icons.price_change_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Maksimum indirim',
                  '%${NumberFormatter.decimal(r.maxDiscountPct)}',
                  icon: Icons.percent_rounded,
                ),
                CalcResultLine(
                  'İndirimli satış nakdi',
                  NumberFormatter.currency(r.discountedCashIncome),
                  icon: Icons.payments_outlined,
                ),
                CalcResultLine(
                  'Normale göre ciro kaybı',
                  NumberFormatter.currency(r.revenueDropVsNormal),
                  icon: Icons.trending_down_rounded,
                ),
              ],
            ),
    );
  }
}
