import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/flour_price_hike_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Un Zammı Etki Hesabı ekranı (patron modülü).
/// Matematik [FlourPriceHikeCalculator] servisindedir.
class FlourPriceHikeScreen extends StatefulWidget {
  const FlourPriceHikeScreen({super.key});

  @override
  State<FlourPriceHikeScreen> createState() => _FlourPriceHikeScreenState();
}

class _FlourPriceHikeScreenState extends State<FlourPriceHikeScreen> {
  static const FlourPriceHikeCalculator _calc = FlourPriceHikeCalculator();

  final _oldPrice = TextEditingController(text: '1000');
  final _newPrice = TextEditingController(text: '1150');
  final _dailySacks = TextEditingController(text: '8');

  FlourPriceHikeResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _oldPrice.dispose();
    _newPrice.dispose();
    _dailySacks.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        oldSackPrice: NumberFormatter.parseLoose(_oldPrice.text),
        newSackPrice: NumberFormatter.parseLoose(_newPrice.text),
        dailySacks: NumberFormatter.parseLoose(_dailySacks.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcFlourHikeTitle,
      hint: 'Un zammı günlük ve aylık ne kadar ek yük getiriyor? (ay = 30 gün)',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Eski çuval fiyatı',
          controller: _oldPrice,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Yeni çuval fiyatı',
          controller: _newPrice,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Günlük tüketilen çuval',
          controller: _dailySacks,
          suffix: 'çuval',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              lines: [
                CalcResultLine(
                  'Aylık ek maliyet',
                  NumberFormatter.currency(r.monthlyExtraCost),
                  icon: Icons.calendar_month_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Günlük ek maliyet',
                  NumberFormatter.currency(r.dailyExtraCost),
                  icon: Icons.today_outlined,
                ),
                CalcResultLine(
                  'Çuval başı fark',
                  NumberFormatter.currency(r.perSackDiff),
                  icon: Icons.compare_arrows_rounded,
                ),
              ],
            ),
    );
  }
}
