import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/flat_deal_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Düz Hesap / İskonto" ekranı (patron modülü).
/// Matematik [FlatDealCalculator] servisindedir.
class FlatDealScreen extends StatefulWidget {
  const FlatDealScreen({super.key});

  @override
  State<FlatDealScreen> createState() => _FlatDealScreenState();
}

class _FlatDealScreenState extends State<FlatDealScreen> {
  static const FlatDealCalculator _calc = FlatDealCalculator();

  final _invoice = TextEditingController(text: '12750');
  final _offered = TextEditingController(text: '12000');

  FlatDealResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _invoice.dispose();
    _offered.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        invoiceAmount: NumberFormatter.parseLoose(_invoice.text),
        offeredAmount: NumberFormatter.parseLoose(_offered.text),
      );
    });
  }

  /// Verdict → fırıncı diliyle uyarı metni (matematik servis tarafında).
  List<String> _warnings(FlatDealResult r) {
    switch (r.verdict) {
      case FlatDealVerdict.invalid:
        return const ['Fatura tutarını gir.'];
      case FlatDealVerdict.noGain:
        return const [
          'Teklif faturanın altında değil; bu pazarlıkta sana kazanç yok.',
        ];
      case FlatDealVerdict.discount:
        return [
          'Bu pazarlıkta faturadan '
              '${NumberFormatter.currency(r.savedAmount)} siliniyor; bu, '
              'ekstra %${NumberFormatter.decimal(r.discountPct)} '
              'iskonto demek.',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcFlatDealTitle,
      hint:
          'Toptancıyla "düz hesap yapalım" pazarlığının gerçekte yüzde kaç '
          'iskonto olduğunu gör.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Gerçek fatura tutarı',
          controller: _invoice,
          suffix: 'TL',
        ),
        AppNumberField(
          label: 'Teklif edilen düz hesap',
          controller: _offered,
          suffix: 'TL',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Silinen tutar',
                  NumberFormatter.currency(
                    r.savedAmount < 0 ? 0 : r.savedAmount,
                  ),
                  icon: Icons.savings_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Gerçek iskonto',
                  '%${NumberFormatter.decimal(r.discountPct < 0 ? 0 : r.discountPct)}',
                  icon: Icons.percent_rounded,
                ),
              ],
            ),
    );
  }
}
