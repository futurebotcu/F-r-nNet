import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/oven_energy_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Fırın Enerji Maliyeti ekranı (patron modülü).
/// Matematik [OvenEnergyCalculator] servisindedir.
class OvenEnergyScreen extends StatefulWidget {
  const OvenEnergyScreen({super.key});

  @override
  State<OvenEnergyScreen> createState() => _OvenEnergyScreenState();
}

class _OvenEnergyScreenState extends State<OvenEnergyScreen> {
  static const OvenEnergyCalculator _calc = OvenEnergyCalculator();

  final _power = TextEditingController(text: '18');
  final _hours = TextEditingController(text: '6');
  final _unitPrice = TextEditingController(text: '3.5');
  final _pieces = TextEditingController(text: '500');

  OvenEnergyResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _power.dispose();
    _hours.dispose();
    _unitPrice.dispose();
    _pieces.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        powerKw: NumberFormatter.parseLoose(_power.text),
        hours: NumberFormatter.parseLoose(_hours.text),
        unitPrice: NumberFormatter.parseLoose(_unitPrice.text),
        pieces: NumberFormatter.parseLoose(_pieces.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcOvenEnergyTitle,
      hint: 'Enerji maliyeti = güç × süre × birim fiyat.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(label: 'Fırın gücü', controller: _power, suffix: 'kW'),
        AppNumberField(
          label: 'Çalışma süresi',
          controller: _hours,
          suffix: 'saat',
        ),
        AppNumberField(
          label: 'Birim enerji fiyatı',
          controller: _unitPrice,
          suffix: '₺/kWh',
        ),
        AppNumberField(
          label: 'Üretilen adet (opsiyonel)',
          controller: _pieces,
          allowDecimal: false,
          hint: 'Boşsa ürün başı maliyet 0',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              lines: [
                CalcResultLine(
                  'Toplam enerji maliyeti',
                  NumberFormatter.currency(r.totalEnergyCost),
                  icon: Icons.bolt_rounded,
                  hero: true,
                ),
                CalcResultLine(
                  'Tüketilen enerji',
                  '${NumberFormatter.decimal(r.energyKwh)} kWh',
                  icon: Icons.electric_meter_outlined,
                ),
                CalcResultLine(
                  'Ürün başı enerji maliyeti',
                  NumberFormatter.currency(r.costPerUnit),
                  icon: Icons.sell_outlined,
                ),
              ],
            ),
    );
  }
}
