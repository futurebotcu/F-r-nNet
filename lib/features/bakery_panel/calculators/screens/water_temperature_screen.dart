import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/water_temperature_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Hamur Suyu Sıcaklığı ekranı (çalışan modülü). su = hedef×3 −
/// (un + oda + sürtünme). Matematik [WaterTemperatureCalculator] servisindedir.
class WaterTemperatureScreen extends StatefulWidget {
  const WaterTemperatureScreen({super.key});

  @override
  State<WaterTemperatureScreen> createState() => _WaterTemperatureScreenState();
}

class _WaterTemperatureScreenState extends State<WaterTemperatureScreen> {
  static const WaterTemperatureCalculator _calc = WaterTemperatureCalculator();

  final _flourTemp = TextEditingController(text: '22');
  final _roomTemp = TextEditingController(text: '24');
  final _targetTemp = TextEditingController(text: '25');
  final _friction = TextEditingController(text: '3');

  WaterTemperatureResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _flourTemp.dispose();
    _roomTemp.dispose();
    _targetTemp.dispose();
    _friction.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        flourTempC: NumberFormatter.parseLoose(_flourTemp.text),
        roomTempC: NumberFormatter.parseLoose(_roomTemp.text),
        targetDoughTempC: NumberFormatter.parseLoose(_targetTemp.text),
        frictionFactor: NumberFormatter.parseLoose(_friction.text),
      );
    });
  }

  static String? _warning(WaterTempBand band) {
    switch (band) {
      case WaterTempBand.iced:
        return 'Önerilen su çok soğuk — buzlu su kullan.';
      case WaterTempBand.lukewarm:
        return 'Önerilen su yüksek — ılık su kullan.';
      case WaterTempBand.normal:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcWaterTempTitle,
      hint: 'Hedef hamur sıcaklığı için gereken su sıcaklığını verir.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Un sıcaklığı',
          controller: _flourTemp,
          suffix: '°C',
        ),
        AppNumberField(
          label: 'Oda sıcaklığı',
          controller: _roomTemp,
          suffix: '°C',
        ),
        AppNumberField(
          label: 'Hedef hamur sıcaklığı',
          controller: _targetTemp,
          suffix: '°C',
        ),
        AppNumberField(
          label: 'Sürtünme payı',
          controller: _friction,
          suffix: '°C',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: [if (_warning(r.band) != null) _warning(r.band)!],
              lines: [
                CalcResultLine(
                  'Önerilen su sıcaklığı',
                  '${NumberFormatter.decimal(r.waterTempC)} °C',
                  icon: Icons.thermostat_outlined,
                  hero: true,
                ),
              ],
            ),
    );
  }
}
