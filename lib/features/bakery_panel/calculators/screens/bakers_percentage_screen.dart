import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/bakers_percentage_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Fırıncı Yüzdesi ekranı — un %100 kabulü, malzeme = un × yüzde / 100.
/// Matematik [BakersPercentageCalculator] servisindedir.
class BakersPercentageScreen extends StatefulWidget {
  const BakersPercentageScreen({super.key});

  @override
  State<BakersPercentageScreen> createState() => _BakersPercentageScreenState();
}

class _BakersPercentageScreenState extends State<BakersPercentageScreen> {
  static const BakersPercentageCalculator _calc = BakersPercentageCalculator();

  final _flour = TextEditingController(text: '50');
  final _water = TextEditingController(text: '62');
  final _yeast = TextEditingController(text: '2.3');
  final _salt = TextEditingController(text: '1.8');
  final _other = TextEditingController();

  BakersPercentageResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _flour.dispose();
    _water.dispose();
    _yeast.dispose();
    _salt.dispose();
    _other.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        flourKg: NumberFormatter.parseLoose(_flour.text),
        waterPct: NumberFormatter.parseLoose(_water.text),
        yeastPct: NumberFormatter.parseLoose(_yeast.text),
        saltPct: NumberFormatter.parseLoose(_salt.text),
        otherPct: NumberFormatter.parseLoose(_other.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcBakersPercentTitle,
      hint:
          'Profesyonel reçetede un her zaman %100 kabul edilir. '
          'Su, tuz ve maya una göre hesaplanır.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(label: 'Un', controller: _flour, suffix: 'kg'),
        AppNumberField(label: 'Su', controller: _water, suffix: '%'),
        AppNumberField(label: 'Maya', controller: _yeast, suffix: '%'),
        AppNumberField(label: 'Tuz', controller: _salt, suffix: '%'),
        AppNumberField(
          label: 'Diğer katkı (opsiyonel)',
          controller: _other,
          suffix: '%',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              lines: [
                CalcResultLine(
                  'Toplam hamur',
                  '${NumberFormatter.decimal(r.totalDoughKg)} kg',
                  icon: Icons.scale_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Su',
                  '${NumberFormatter.decimal(r.waterKg)} kg / L',
                  icon: Icons.water_drop_outlined,
                ),
                CalcResultLine(
                  'Maya',
                  '${NumberFormatter.decimal(r.yeastKg)} kg',
                  icon: Icons.science_outlined,
                ),
                CalcResultLine(
                  'Tuz',
                  '${NumberFormatter.decimal(r.saltKg)} kg',
                  icon: Icons.spa_outlined,
                ),
                if (r.otherKg > 0)
                  CalcResultLine(
                    'Diğer katkı',
                    '${NumberFormatter.decimal(r.otherKg)} kg',
                    icon: Icons.add_circle_outline,
                  ),
              ],
            ),
    );
  }
}
