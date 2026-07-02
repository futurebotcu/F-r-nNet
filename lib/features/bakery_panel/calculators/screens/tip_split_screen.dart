import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/tip_split_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Prim / Bahşiş Bölüştürücü ekranı (patron modülü).
/// Matematik [TipSplitCalculator] servisindedir.
class TipSplitScreen extends StatefulWidget {
  const TipSplitScreen({super.key});

  @override
  State<TipSplitScreen> createState() => _TipSplitScreenState();
}

class _TipSplitScreenState extends State<TipSplitScreen> {
  static const TipSplitCalculator _calc = TipSplitCalculator();

  final _total = TextEditingController(text: '3000');
  final _productionPct = TextEditingController(text: '50');
  final _counterPct = TextEditingController(text: '30');
  final _apprenticePct = TextEditingController(text: '20');

  TipSplitResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _total.dispose();
    _productionPct.dispose();
    _counterPct.dispose();
    _apprenticePct.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        totalAmount: NumberFormatter.parseLoose(_total.text),
        productionPct: NumberFormatter.parseLoose(_productionPct.text),
        counterPct: NumberFormatter.parseLoose(_counterPct.text),
        apprenticePct: NumberFormatter.parseLoose(_apprenticePct.text),
      );
    });
  }

  /// Verdict → patron diliyle uyarı metni (matematik servis tarafında).
  List<String> _warnings(TipSplitResult r) {
    switch (r.verdict) {
      case TipSplitVerdict.invalid:
        return const ['Toplam tutar ve pay yüzdeleri girilmeli.'];
      case TipSplitVerdict.pctMismatch:
        return [
          'Pay yüzdeleri 100 etmiyor '
              '(şu an %${NumberFormatter.decimal(r.sumPct)}); kalan tutar '
              'açıkta kalır, oranları kontrol et.',
        ];
      case TipSplitVerdict.ok:
        return const [
          'Dağıtım toplamı tutuyor; payları gönül rahatlığıyla dağıt.',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcTipSplitTitle,
      hint:
          'Gün sonu prim veya bahşişi imalat, tezgâh ve çırak arasında adil '
          'paylaştır.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(label: 'Toplam tutar', controller: _total, suffix: '₺'),
        AppNumberField(
          label: 'İmalat payı',
          controller: _productionPct,
          suffix: '%',
        ),
        AppNumberField(
          label: 'Tezgâh payı',
          controller: _counterPct,
          suffix: '%',
        ),
        AppNumberField(
          label: 'Çırak/diğer payı',
          controller: _apprenticePct,
          suffix: '%',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'İmalat payı',
                  NumberFormatter.currency(r.productionShare),
                  icon: Icons.bakery_dining_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Tezgâh payı',
                  NumberFormatter.currency(r.counterShare),
                  icon: Icons.storefront_outlined,
                ),
                CalcResultLine(
                  'Çırak/diğer payı',
                  NumberFormatter.currency(r.apprenticeShare),
                  icon: Icons.group_outlined,
                ),
                if (r.remainder.abs() > 0.005)
                  CalcResultLine(
                    'Kalan/yuvarlama',
                    NumberFormatter.currency(r.remainder),
                    icon: Icons.balance_outlined,
                  ),
              ],
            ),
    );
  }
}
