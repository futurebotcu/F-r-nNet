import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/labor_index_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Ürün Başı İşçilik" ekranı (patron modülü).
/// Matematik [LaborIndexCalculator] servisindedir.
class LaborIndexScreen extends StatefulWidget {
  const LaborIndexScreen({super.key});

  @override
  State<LaborIndexScreen> createState() => _LaborIndexScreenState();
}

class _LaborIndexScreenState extends State<LaborIndexScreen> {
  static const LaborIndexCalculator _calc = LaborIndexCalculator();

  final _totalMinutes = TextEditingController(text: '480');
  final _producedCount = TextEditingController(text: '2000');
  final _laborCost = TextEditingController(text: '3200');

  LaborIndexResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _totalMinutes.dispose();
    _producedCount.dispose();
    _laborCost.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        totalMinutes: NumberFormatter.parseLoose(_totalMinutes.text),
        producedCount: NumberFormatter.parseLoose(_producedCount.text),
        laborCost: NumberFormatter.parseLoose(_laborCost.text),
      );
    });
  }

  /// Verdict → fırıncı diliyle uyarı metni (matematik servis tarafında).
  List<String> _warnings(LaborIndexResult r) {
    switch (r.verdict) {
      case LaborIndexVerdict.invalid:
        return const ['Süre ve ürün adedi girilmeden işçilik hesabı çıkmaz.'];
      case LaborIndexVerdict.ok:
        return const [
          'Ürün başı işçilik sana yüksek geliyorsa tezgâh düzenini ve '
              'iş bölümünü gözden geçir.',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcLaborIndexTitle,
      hint:
          'Bir ürüne kaç saniye ve kaç lira işçilik gittiğini, saatlik '
          'üretim hızını gör.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Toplam üretim süresi',
          controller: _totalMinutes,
          suffix: 'dk',
        ),
        AppNumberField(
          label: 'Çıkan ürün',
          controller: _producedCount,
          suffix: 'adet',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Toplam işçilik/vardiya maliyeti',
          controller: _laborCost,
          suffix: 'TL',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Ürün başı süre',
                  '${NumberFormatter.decimal(r.secondsPerUnit)} sn',
                  icon: Icons.timer_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Ürün başı işçilik',
                  NumberFormatter.currency(r.laborCostPerUnit),
                  icon: Icons.engineering_outlined,
                ),
                CalcResultLine(
                  'Saatlik üretim',
                  '${NumberFormatter.decimal(r.hourlyOutput)} adet',
                  icon: Icons.speed_rounded,
                ),
              ],
            ),
    );
  }
}
