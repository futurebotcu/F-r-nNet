import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/fixed_cost_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Dükkan Boşta Kaça Çalışıyor?" ekranı (patron modülü).
/// Matematik [FixedCostCalculator] servisindedir.
class FixedCostScreen extends StatefulWidget {
  const FixedCostScreen({super.key});

  @override
  State<FixedCostScreen> createState() => _FixedCostScreenState();
}

class _FixedCostScreenState extends State<FixedCostScreen> {
  static const FixedCostCalculator _calc = FixedCostCalculator();

  final _monthly = TextEditingController(text: '90000');
  final _workDays = TextEditingController(text: '30');
  final _sacks = TextEditingController(text: '10');
  final _units = TextEditingController(text: '1200');

  FixedCostResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _monthly.dispose();
    _workDays.dispose();
    _sacks.dispose();
    _units.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        monthlyFixedTotal: NumberFormatter.parseLoose(_monthly.text),
        workDaysPerMonth: NumberFormatter.parseLoose(_workDays.text),
        dailySacks: NumberFormatter.parseLoose(_sacks.text),
        dailyUnits: NumberFormatter.parseLoose(_units.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final hasUnits = NumberFormatter.parseLoose(_units.text) > 0;
    return CalculatorFormScaffold(
      title: AppStrings.calcFixedCostTitle,
      hint:
          'Kira, maaş, elektrik gibi sabit giderlerin günlük, çuval ve ürün '
          'başına yükünü gör.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Aylık sabit gider toplamı',
          controller: _monthly,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Aylık çalışma günü',
          controller: _workDays,
          suffix: 'gün',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Günlük işlenen çuval',
          controller: _sacks,
          suffix: 'çuval',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Günlük ürün adedi (opsiyonel)',
          controller: _units,
          suffix: 'adet',
          allowDecimal: false,
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: const [
                'Dükkan her sabah bu sabit giderle açılıyor; bu yükü satıştan '
                    'önce çıkarman gerekir.',
              ],
              lines: [
                CalcResultLine(
                  'Günlük sabit gider',
                  NumberFormatter.currency(r.dailyFixedCost),
                  icon: Icons.calendar_today_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Çuval başı sabit gider',
                  NumberFormatter.currency(r.perSackFixedCost),
                  icon: Icons.inventory_2_outlined,
                ),
                if (hasUnits)
                  CalcResultLine(
                    'Ürün başı sabit gider',
                    NumberFormatter.currency(r.perUnitFixedCost),
                    icon: Icons.bakery_dining_outlined,
                  ),
              ],
            ),
    );
  }
}
