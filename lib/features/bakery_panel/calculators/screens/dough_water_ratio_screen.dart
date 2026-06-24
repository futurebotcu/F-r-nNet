import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/dough_water_ratio_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Hamur Su Oranı Ustası ekranı — su/un oranını yüzde olarak verir + kıvam
/// yorumu. Matematik [DoughWaterRatioCalculator] servisindedir.
class DoughWaterRatioScreen extends StatefulWidget {
  const DoughWaterRatioScreen({super.key});

  @override
  State<DoughWaterRatioScreen> createState() => _DoughWaterRatioScreenState();
}

class _DoughWaterRatioScreenState extends State<DoughWaterRatioScreen> {
  static const DoughWaterRatioCalculator _calc = DoughWaterRatioCalculator();

  final _flour = TextEditingController(text: '50');
  final _water = TextEditingController(text: '33');

  DoughWaterRatioResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _flour.dispose();
    _water.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.evaluate(
        flourKg: NumberFormatter.parseLoose(_flour.text),
        waterKg: NumberFormatter.parseLoose(_water.text),
      );
    });
  }

  static String _bandLabel(DoughHydrationBand band) {
    switch (band) {
      case DoughHydrationBand.tooStiff:
        return 'Çok sert — su ekle';
      case DoughHydrationBand.lowWater:
        return 'Su az';
      case DoughHydrationBand.ideal:
        return 'İdeal kıvam';
      case DoughHydrationBand.highWater:
        return 'Su fazla';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcWaterRatioTitle,
      hint: 'Su / un × 100. 65–70 arası genelde ideal kabul edilir.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(label: 'Un', controller: _flour, suffix: 'kg'),
        AppNumberField(label: 'Su', controller: _water, suffix: 'L / kg'),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              lines: [
                CalcResultLine(
                  'Su oranı',
                  '%${NumberFormatter.decimal(r.ratioPct)}',
                  icon: Icons.percent_rounded,
                  hero: true,
                ),
                CalcResultLine(
                  'Kıvam',
                  _bandLabel(r.band),
                  icon: Icons.thermostat_auto_outlined,
                ),
              ],
            ),
    );
  }
}
