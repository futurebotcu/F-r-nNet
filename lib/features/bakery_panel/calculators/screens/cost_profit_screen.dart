import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/cost_profit_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Gerçek Maliyet + Kâr ekranı (patron modülü).
/// Matematik [CostProfitCalculator] servisindedir.
class CostProfitScreen extends StatefulWidget {
  const CostProfitScreen({super.key});

  @override
  State<CostProfitScreen> createState() => _CostProfitScreenState();
}

class _CostProfitScreenState extends State<CostProfitScreen> {
  static const CostProfitCalculator _calc = CostProfitCalculator();

  final _count = TextEditingController(text: '500');
  final _flour = TextEditingController(text: '1000');
  final _ingredients = TextEditingController(text: '250');
  final _packaging = TextEditingController(text: '150');
  final _labor = TextEditingController(text: '900');
  final _energy = TextEditingController(text: '300');
  final _overhead = TextEditingController(text: '10');
  final _price = TextEditingController(text: '7.5');

  CostProfitResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _count.dispose();
    _flour.dispose();
    _ingredients.dispose();
    _packaging.dispose();
    _labor.dispose();
    _energy.dispose();
    _overhead.dispose();
    _price.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        productionCount: NumberFormatter.parseLoose(_count.text),
        flourCost: NumberFormatter.parseLoose(_flour.text),
        otherIngredientCost: NumberFormatter.parseLoose(_ingredients.text),
        packagingCost: NumberFormatter.parseLoose(_packaging.text),
        laborCost: NumberFormatter.parseLoose(_labor.text),
        energyCost: NumberFormatter.parseLoose(_energy.text),
        otherExpensePct: NumberFormatter.parseLoose(_overhead.text),
        salePrice: NumberFormatter.parseLoose(_price.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final loss = r != null && r.profitPerUnit < 0;
    return CalculatorFormScaffold(
      title: AppStrings.calcCostProfitTitle,
      hint: 'Tüm giderleri topla, adet başı maliyet ve kârı gör.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Üretim adedi',
          controller: _count,
          allowDecimal: false,
        ),
        AppNumberField(label: 'Un maliyeti', controller: _flour, suffix: '₺'),
        AppNumberField(
          label: 'Maya / tuz / yağ / diğer',
          controller: _ingredients,
          suffix: '₺',
        ),
        AppNumberField(label: 'Ambalaj', controller: _packaging, suffix: '₺'),
        AppNumberField(label: 'İşçilik', controller: _labor, suffix: '₺'),
        AppNumberField(label: 'Enerji', controller: _energy, suffix: '₺'),
        AppNumberField(
          label: 'Diğer gider',
          controller: _overhead,
          suffix: '%',
        ),
        AppNumberField(
          label: 'Satış fiyatı (adet)',
          controller: _price,
          suffix: '₺',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: [
                if (loss)
                  'Bu fiyatta adet başı zarar var — satış fiyatını veya '
                      'maliyeti gözden geçir.',
              ],
              lines: [
                CalcResultLine(
                  'Adet başı kâr',
                  NumberFormatter.currency(r.profitPerUnit),
                  icon: Icons.trending_up_rounded,
                  hero: true,
                ),
                CalcResultLine(
                  'Toplam maliyet',
                  NumberFormatter.currency(r.totalCost),
                  icon: Icons.receipt_long_outlined,
                ),
                CalcResultLine(
                  'Ürün başı maliyet',
                  NumberFormatter.currency(r.costPerUnit),
                  icon: Icons.sell_outlined,
                ),
                CalcResultLine(
                  'Kâr oranı',
                  '%${NumberFormatter.decimal(r.profitMarginPct)}',
                  icon: Icons.percent_rounded,
                ),
                CalcResultLine(
                  'Günlük toplam kâr',
                  NumberFormatter.currency(r.dailyTotalProfit),
                  icon: Icons.payments_outlined,
                ),
              ],
            ),
    );
  }
}
