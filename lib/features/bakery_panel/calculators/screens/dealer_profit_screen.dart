import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/dealer_profit_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Bayi Kârlılık Ölçeği" ekranı (patron modülü).
/// Matematik [DealerProfitCalculator] servisindedir.
class DealerProfitScreen extends StatefulWidget {
  const DealerProfitScreen({super.key});

  @override
  State<DealerProfitScreen> createState() => _DealerProfitScreenState();
}

class _DealerProfitScreenState extends State<DealerProfitScreen> {
  static const DealerProfitCalculator _calc = DealerProfitCalculator();

  final _units = TextEditingController(text: '100');
  final _price = TextEditingController(text: '7');
  final _cost = TextEditingController(text: '5');
  final _returns = TextEditingController(text: '8');
  final _distribution = TextEditingController(text: '50');

  DealerProfitResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _units.dispose();
    _price.dispose();
    _cost.dispose();
    _returns.dispose();
    _distribution.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        dailyUnits: NumberFormatter.parseLoose(_units.text),
        dealerSalePrice: NumberFormatter.parseLoose(_price.text),
        costPerUnit: NumberFormatter.parseLoose(_cost.text),
        dailyReturns: NumberFormatter.parseLoose(_returns.text),
        distributionCost: NumberFormatter.parseLoose(_distribution.text),
      );
    });
  }

  /// Verdict → patron diliyle yorum (matematik servis tarafında).
  List<String> _warnings(DealerProfitResult r) {
    switch (r.verdict) {
      case DealerProfitVerdict.lossy:
        return const [
          'Bu bayi şu an zarar ettiriyor — fiyatı, iadeyi veya dağıtımı '
              'gözden geçir.',
        ];
      case DealerProfitVerdict.highReturns:
        return const ['İade oranı yüksek; bu bayi kârı eritiyor.'];
      case DealerProfitVerdict.marginal:
        return const [
          'Dağıtım maliyetiyle birlikte bu bayi sınırda görünüyor.',
        ];
      case DealerProfitVerdict.profitable:
        return const ['Bu bayi kârlı görünüyor.'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcDealerProfitTitle,
      hint:
          'İskonto, iade ve dağıtımdan sonra bir bayinin gerçekten para '
          'kazandırıp kazandırmadığını gör.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Günlük verilen adet',
          controller: _units,
          suffix: 'adet',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Bayi satış fiyatı',
          controller: _price,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Ürün başı maliyet',
          controller: _cost,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Günlük iade / bayat adet',
          controller: _returns,
          suffix: 'adet',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Dağıtım maliyeti (opsiyonel)',
          controller: _distribution,
          suffix: '₺',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Dağıtım sonrası kâr',
                  NumberFormatter.currency(r.netProfit),
                  icon: Icons.account_balance_wallet_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Günlük ciro',
                  NumberFormatter.currency(r.dailyRevenue),
                  icon: Icons.point_of_sale_outlined,
                ),
                CalcResultLine(
                  'İade zararı',
                  NumberFormatter.currency(r.returnLoss),
                  icon: Icons.assignment_return_outlined,
                ),
                CalcResultLine(
                  'Kâr oranı',
                  '%${NumberFormatter.decimal(r.profitMarginPct)}',
                  icon: Icons.percent_rounded,
                ),
                CalcResultLine(
                  'İade oranı',
                  '%${NumberFormatter.decimal(r.returnRatePct)}',
                  icon: Icons.recycling_outlined,
                ),
              ],
            ),
    );
  }
}
