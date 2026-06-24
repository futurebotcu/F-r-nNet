import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/free_goods_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Bedelsiz Kampanya Çözücü ekranı (patron modülü).
/// Matematik [FreeGoodsCalculator] servisindedir.
class FreeGoodsScreen extends StatefulWidget {
  const FreeGoodsScreen({super.key});

  @override
  State<FreeGoodsScreen> createState() => _FreeGoodsScreenState();
}

class _FreeGoodsScreenState extends State<FreeGoodsScreen> {
  static const FreeGoodsCalculator _calc = FreeGoodsCalculator();

  final _normalPrice = TextEditingController(text: '1000');
  final _purchased = TextEditingController(text: '10');
  final _free = TextEditingController(text: '1');

  FreeGoodsResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _normalPrice.dispose();
    _purchased.dispose();
    _free.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        normalUnitPrice: NumberFormatter.parseLoose(_normalPrice.text),
        purchasedCount: NumberFormatter.parseLoose(_purchased.text),
        freeCount: NumberFormatter.parseLoose(_free.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcFreeGoodsTitle,
      hint: '"X al Y bedelsiz" kampanyasında gerçek birim fiyatı çözer.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Normal çuval fiyatı',
          controller: _normalPrice,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Satın alınan adet',
          controller: _purchased,
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Bedelsiz adet',
          controller: _free,
          allowDecimal: false,
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              lines: [
                CalcResultLine(
                  'Gerçek birim fiyat',
                  NumberFormatter.currency(r.realUnitPrice),
                  icon: Icons.local_offer_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Toplam avantaj',
                  NumberFormatter.currency(r.totalAdvantage),
                  icon: Icons.savings_outlined,
                ),
                CalcResultLine(
                  'Yüzdesel indirim',
                  '%${NumberFormatter.decimal(r.discountPct)}',
                  icon: Icons.percent_rounded,
                ),
              ],
            ),
    );
  }
}
