import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/recipe_scaler_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Reçete Büyüt/Küçült ekranı — eski/yeni hedef oranıyla malzeme ölçekleme.
/// Matematik [RecipeScalerCalculator] servisindedir.
class RecipeScalerScreen extends StatefulWidget {
  const RecipeScalerScreen({super.key});

  @override
  State<RecipeScalerScreen> createState() => _RecipeScalerScreenState();
}

class _RecipeScalerScreenState extends State<RecipeScalerScreen> {
  static const RecipeScalerCalculator _calc = RecipeScalerCalculator();

  final _oldTarget = TextEditingController(text: '100');
  final _newTarget = TextEditingController(text: '250');
  final _flour = TextEditingController(text: '50');
  final _water = TextEditingController(text: '31');
  final _yeast = TextEditingController(text: '1.2');
  final _salt = TextEditingController(text: '0.9');
  final _other = TextEditingController();

  RecipeScaleResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _oldTarget.dispose();
    _newTarget.dispose();
    _flour.dispose();
    _water.dispose();
    _yeast.dispose();
    _salt.dispose();
    _other.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.scale(
        oldTarget: NumberFormatter.parseLoose(_oldTarget.text),
        newTarget: NumberFormatter.parseLoose(_newTarget.text),
        flourKg: NumberFormatter.parseLoose(_flour.text),
        waterKg: NumberFormatter.parseLoose(_water.text),
        yeastKg: NumberFormatter.parseLoose(_yeast.text),
        saltKg: NumberFormatter.parseLoose(_salt.text),
        otherKg: NumberFormatter.parseLoose(_other.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcRecipeScaleTitle,
      hint: 'Reçeteyi yeni hedefe göre büyütür ya da küçültür.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(label: 'Eski hedef (adet / kg)', controller: _oldTarget),
        AppNumberField(label: 'Yeni hedef (adet / kg)', controller: _newTarget),
        AppNumberField(label: 'Un', controller: _flour, suffix: 'kg'),
        AppNumberField(label: 'Su', controller: _water, suffix: 'L / kg'),
        AppNumberField(label: 'Maya', controller: _yeast, suffix: 'kg'),
        AppNumberField(label: 'Tuz', controller: _salt, suffix: 'kg'),
        AppNumberField(
          label: 'Diğer malzeme (opsiyonel)',
          controller: _other,
          suffix: 'kg',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              lines: [
                CalcResultLine(
                  'Ölçekleme çarpanı',
                  '×${NumberFormatter.decimal(r.multiplier)}',
                  icon: Icons.close_rounded,
                  hero: true,
                ),
                CalcResultLine(
                  'Un',
                  '${NumberFormatter.decimal(r.flourKg)} kg',
                  icon: Icons.grain_rounded,
                ),
                CalcResultLine(
                  'Su',
                  '${NumberFormatter.decimal(r.waterKg)} L / kg',
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
                    'Diğer malzeme',
                    '${NumberFormatter.decimal(r.otherKg)} kg',
                    icon: Icons.add_circle_outline,
                  ),
              ],
            ),
    );
  }
}
