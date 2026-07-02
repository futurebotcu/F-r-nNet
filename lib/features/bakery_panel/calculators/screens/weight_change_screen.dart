import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/weight_change_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Gramaj Değişimi" ekranı (ortak modül).
/// Matematik [WeightChangeCalculator] servisindedir.
class WeightChangeScreen extends StatefulWidget {
  const WeightChangeScreen({super.key});

  @override
  State<WeightChangeScreen> createState() => _WeightChangeScreenState();
}

class _WeightChangeScreenState extends State<WeightChangeScreen> {
  static const WeightChangeCalculator _calc = WeightChangeCalculator();

  final _dough = TextEditingController(text: '100');
  final _oldGrams = TextEditingController(text: '250');
  final _newGrams = TextEditingController(text: '240');
  final _price = TextEditingController(text: '15');

  WeightChangeResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _dough.dispose();
    _oldGrams.dispose();
    _newGrams.dispose();
    _price.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        totalDoughKg: NumberFormatter.parseLoose(_dough.text),
        oldGramsPerPiece: NumberFormatter.parseLoose(_oldGrams.text),
        newGramsPerPiece: NumberFormatter.parseLoose(_newGrams.text),
        salePrice: NumberFormatter.parseLoose(_price.text),
      );
    });
  }

  /// Verdict → fırıncı diliyle uyarı metni (matematik servis tarafında).
  List<String> _warnings(WeightChangeResult r) {
    switch (r.verdict) {
      case WeightChangeVerdict.invalid:
        return const [
          'Hamur ve gramaj değerlerini gir; 0 ile hesap yapılamaz.',
        ];
      case WeightChangeVerdict.morePieces:
        return const [
          'Gramaj düşünce adet artar; ama müşteri gramajın düştüğünü fark '
              'ederse güven sarsılır, etiket ve gramajda dürüst kal.',
        ];
      case WeightChangeVerdict.fewerPieces:
        return const [
          'Gramaj artınca aynı hamurdan daha az ürün çıkar; fiyatı ve '
              'reçeteyi buna göre gözden geçir.',
        ];
      case WeightChangeVerdict.same:
        return const ['Gramaj değişmedi; adet aynı kalır.'];
    }
  }

  /// +/− işaretli adet farkı metni (yalnız gösterim).
  String _signedDiff(int diff) {
    final text = NumberFormatter.integer(diff);
    return diff > 0 ? '+$text' : text;
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final invalid = r?.verdict == WeightChangeVerdict.invalid;
    return CalculatorFormScaffold(
      title: AppStrings.calcWeightChangeTitle,
      hint: 'Aynı hamurla gramaj değişirse adet ve ciro nasıl etkilenir, gör.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(label: 'Toplam hamur', controller: _dough, suffix: 'kg'),
        AppNumberField(
          label: 'Eski gramaj',
          controller: _oldGrams,
          suffix: 'g',
        ),
        AppNumberField(
          label: 'Yeni gramaj',
          controller: _newGrams,
          suffix: 'g',
        ),
        AppNumberField(
          label: 'Satış fiyatı (opsiyonel)',
          controller: _price,
          suffix: 'TL/adet',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Eski adet',
                  invalid ? '—' : NumberFormatter.integer(r.oldCount),
                  icon: Icons.bakery_dining_outlined,
                ),
                CalcResultLine(
                  'Yeni adet',
                  invalid ? '—' : NumberFormatter.integer(r.newCount),
                  icon: Icons.bakery_dining_rounded,
                  hero: true,
                ),
                CalcResultLine(
                  'Adet farkı',
                  invalid ? '—' : _signedDiff(r.pieceDiff),
                  icon: Icons.swap_vert_rounded,
                ),
                CalcResultLine(
                  'Değişim',
                  invalid ? '—' : '%${NumberFormatter.decimal(r.pctChangePct)}',
                  icon: Icons.percent_rounded,
                ),
                if (r.hasRevenue)
                  CalcResultLine(
                    'Tahmini ciro farkı',
                    NumberFormatter.currency(r.revenueDiff),
                    icon: Icons.payments_outlined,
                  ),
              ],
            ),
    );
  }
}
