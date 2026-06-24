import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/sack_to_bread_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Çuvaldan Kaç Ekmek Çıkar?" ekranı. Matematik
/// [SackToBreadCalculator] servisindedir.
class SackToBreadScreen extends StatefulWidget {
  const SackToBreadScreen({super.key});

  @override
  State<SackToBreadScreen> createState() => _SackToBreadScreenState();
}

class _SackToBreadScreenState extends State<SackToBreadScreen> {
  static const SackToBreadCalculator _calc = SackToBreadCalculator();

  final _sacks = TextEditingController(text: '1');
  final _sackKg = TextEditingController(text: '50');
  final _absorption = TextEditingController(text: '60');
  final _doughG = TextEditingController(text: '500');
  final _waste = TextEditingController(text: '3');

  SackToBreadResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _sacks.dispose();
    _sackKg.dispose();
    _absorption.dispose();
    _doughG.dispose();
    _waste.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        sackCount: NumberFormatter.parseLoose(_sacks.text),
        sackKg: NumberFormatter.parseLoose(_sackKg.text),
        waterAbsorptionPct: NumberFormatter.parseLoose(_absorption.text),
        breadDoughG: NumberFormatter.parseLoose(_doughG.text),
        wastePct: NumberFormatter.parseLoose(_waste.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcSackBreadTitle,
      hint: 'Çuval sayısından tahmini ekmek adedi (un + su kaldırma − fire).',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Çuval sayısı',
          controller: _sacks,
          suffix: 'çuval',
        ),
        AppNumberField(label: 'Çuval kg', controller: _sackKg, suffix: 'kg'),
        AppNumberField(
          label: 'Su kaldırma oranı',
          controller: _absorption,
          suffix: '%',
        ),
        AppNumberField(
          label: 'Ekmek hamur gramajı',
          controller: _doughG,
          suffix: 'gr',
        ),
        AppNumberField(label: 'Fire oranı', controller: _waste, suffix: '%'),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              lines: [
                CalcResultLine(
                  'Tahmini adet',
                  NumberFormatter.integer(r.estimatedPieces),
                  icon: Icons.numbers_rounded,
                  hero: true,
                ),
                CalcResultLine(
                  'Toplam un',
                  '${NumberFormatter.decimal(r.totalFlourKg)} kg',
                  icon: Icons.grain_rounded,
                ),
                CalcResultLine(
                  'Tahmini hamur',
                  '${NumberFormatter.decimal(r.estimatedDoughKg)} kg',
                  icon: Icons.scale_outlined,
                ),
                CalcResultLine(
                  'Fire sonrası net hamur',
                  '${NumberFormatter.decimal(r.netDoughKg)} kg',
                  icon: Icons.water_drop_outlined,
                ),
              ],
            ),
    );
  }
}
