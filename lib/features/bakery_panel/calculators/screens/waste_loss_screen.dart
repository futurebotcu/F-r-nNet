import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/waste_loss_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Günlük Fire / Bayat Zarar" ekranı (patron modülü).
/// Matematik [WasteLossCalculator] servisindedir.
class WasteLossScreen extends StatefulWidget {
  const WasteLossScreen({super.key});

  @override
  State<WasteLossScreen> createState() => _WasteLossScreenState();
}

class _WasteLossScreenState extends State<WasteLossScreen> {
  static const WasteLossCalculator _calc = WasteLossCalculator();

  final _name = TextEditingController(text: 'Ekmek');
  final _produced = TextEditingController(text: '1000');
  final _sold = TextEditingController(text: '900');
  final _waste = TextEditingController(text: '100');
  final _cost = TextEditingController(text: '5');
  final _price = TextEditingController(text: '7.5');

  WasteLossResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _name.dispose();
    _produced.dispose();
    _sold.dispose();
    _waste.dispose();
    _cost.dispose();
    _price.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        producedCount: NumberFormatter.parseLoose(_produced.text),
        soldCount: NumberFormatter.parseLoose(_sold.text),
        wasteCount: NumberFormatter.parseLoose(_waste.text),
        costPerUnit: NumberFormatter.parseLoose(_cost.text),
        salePrice: NumberFormatter.parseLoose(_price.text),
      );
    });
  }

  /// Verdict → patron diliyle yorum (matematik servis tarafında).
  List<String> _warnings(WasteLossResult r) {
    switch (r.verdict) {
      case WasteLossVerdict.high:
        return const [
          'Fire oranı yüksek; üretim adetini veya bayi dağıtımını gözden '
              'geçir.',
        ];
      case WasteLossVerdict.moderate:
        return const ['Fire kabul edilebilir sınırda ama izlemeye değer.'];
      case WasteLossVerdict.low:
        return const ['Fire düşük; üretim planın isabetli görünüyor.'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcWasteLossTitle,
      hint:
          'Bayatlayan, iade gelen veya çöpe giden ürünün bugünkü parasal '
          'zararını gör.',
      onCalculate: _recalculate,
      inputs: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Ürün adı'),
        ),
        AppNumberField(
          label: 'Üretilen adet',
          controller: _produced,
          suffix: 'adet',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Satılan adet',
          controller: _sold,
          suffix: 'adet',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Bayat / iade / fire adet',
          controller: _waste,
          suffix: 'adet',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Ürün başı maliyet',
          controller: _cost,
          suffix: '₺',
        ),
        AppNumberField(label: 'Satış fiyatı', controller: _price, suffix: '₺'),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Bugün çöpe giden maliyet',
                  NumberFormatter.currency(r.costLoss),
                  icon: Icons.delete_outline_rounded,
                  hero: true,
                ),
                CalcResultLine(
                  'Fire oranı',
                  '%${NumberFormatter.decimal(r.wasteRatePct)}',
                  icon: Icons.percent_rounded,
                ),
                CalcResultLine(
                  'Kaçırılan satış değeri',
                  NumberFormatter.currency(r.missedSaleValue),
                  icon: Icons.money_off_csred_outlined,
                ),
                CalcResultLine(
                  'Fire adet',
                  NumberFormatter.integer(r.wasteCount),
                  icon: Icons.production_quantity_limits_outlined,
                ),
              ],
            ),
    );
  }
}
