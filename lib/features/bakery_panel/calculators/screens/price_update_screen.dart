import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/price_update_simulator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Fiyat Güncelleme Simülatörü" ekranı (patron modülü).
/// Matematik [PriceUpdateSimulator] servisindedir.
class PriceUpdateScreen extends StatefulWidget {
  const PriceUpdateScreen({super.key});

  @override
  State<PriceUpdateScreen> createState() => _PriceUpdateScreenState();
}

class _PriceUpdateScreenState extends State<PriceUpdateScreen> {
  static const PriceUpdateSimulator _calc = PriceUpdateSimulator();

  final _cost = TextEditingController(text: '5');
  final _oldMain = TextEditingController(text: '1000');
  final _newMain = TextEditingController(text: '1200');
  final _price = TextEditingController(text: '7.5');
  final _target = TextEditingController(text: '30');

  PriceUpdateResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _cost.dispose();
    _oldMain.dispose();
    _newMain.dispose();
    _price.dispose();
    _target.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        currentUnitCost: NumberFormatter.parseLoose(_cost.text),
        oldMainCost: NumberFormatter.parseLoose(_oldMain.text),
        newMainCost: NumberFormatter.parseLoose(_newMain.text),
        currentSalePrice: NumberFormatter.parseLoose(_price.text),
        targetMarginPct: NumberFormatter.parseLoose(_target.text),
      );
    });
  }

  /// Verdict → patron diliyle yorum (matematik servis tarafında).
  List<String> _warnings(PriceUpdateResult r) {
    switch (r.verdict) {
      case PriceUpdateVerdict.sellingAtLoss:
        return const [
          'Yeni maliyet satış fiyatının üstünde — bu fiyatla her satış zarar.',
          'Hedef kâr için fiyatı yaklaşık önerilen seviyeye çekmelisin.',
        ];
      case PriceUpdateVerdict.marginEroded:
        return const [
          'Bu fiyatı değiştirmezsen kârın hedefin altına düşer.',
          'Hedef kâr için fiyatı yaklaşık önerilen seviyeye çekmelisin.',
        ];
      case PriceUpdateVerdict.comfortable:
        return const [
          'Mevcut fiyat hedef kârını koruyor; acil zam gerekmiyor.',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcPriceUpdateTitle,
      hint:
          'Un/malzeme zammından sonra mevcut fiyatın kârını ve hedef kâr için '
          'önerilen satış fiyatını gör.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Mevcut ürün maliyeti',
          controller: _cost,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Eski ana / çuval maliyeti',
          controller: _oldMain,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Yeni ana / çuval maliyeti',
          controller: _newMain,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Mevcut satış fiyatı',
          controller: _price,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Hedef kâr oranı',
          controller: _target,
          suffix: '%',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Önerilen satış fiyatı',
                  NumberFormatter.currency(r.suggestedPrice),
                  icon: Icons.sell_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Yeni tahmini maliyet',
                  NumberFormatter.currency(r.newUnitCost),
                  icon: Icons.receipt_long_outlined,
                ),
                CalcResultLine(
                  'Mevcut fiyatla yeni kâr',
                  '%${NumberFormatter.decimal(r.currentMarginPct)}',
                  icon: Icons.percent_rounded,
                ),
                CalcResultLine(
                  'Fiyat farkı',
                  NumberFormatter.currency(r.priceDiff),
                  icon: Icons.swap_vert_rounded,
                ),
              ],
            ),
    );
  }
}
