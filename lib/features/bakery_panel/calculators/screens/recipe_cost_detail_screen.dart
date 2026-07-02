import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/recipe_cost_detail_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Detaylı Reçete Maliyeti" ekranı (patron modülü).
/// Matematik [RecipeCostDetailCalculator] servisindedir.
class RecipeCostDetailScreen extends StatefulWidget {
  const RecipeCostDetailScreen({super.key});

  @override
  State<RecipeCostDetailScreen> createState() => _RecipeCostDetailScreenState();
}

class _RecipeCostDetailScreenState extends State<RecipeCostDetailScreen> {
  static const RecipeCostDetailCalculator _calc = RecipeCostDetailCalculator();

  final _count = TextEditingController(text: '1000');
  final _flourQty = TextEditingController(text: '100');
  final _flourPrice = TextEditingController(text: '18');
  final _yeastFlat = TextEditingController(text: '250');
  final _fatQty = TextEditingController(text: '5');
  final _fatPrice = TextEditingController(text: '90');
  final _otherFlat = TextEditingController(text: '150');
  final _packagingFlat = TextEditingController(text: '100');
  final _targetProfit = TextEditingController(text: '25');

  RecipeCostDetailResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _count.dispose();
    _flourQty.dispose();
    _flourPrice.dispose();
    _yeastFlat.dispose();
    _fatQty.dispose();
    _fatPrice.dispose();
    _otherFlat.dispose();
    _packagingFlat.dispose();
    _targetProfit.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        productionCount: NumberFormatter.parseLoose(_count.text),
        items: [
          RecipeCostItem(
            name: 'Un',
            quantity: NumberFormatter.parseLoose(_flourQty.text),
            unitPrice: NumberFormatter.parseLoose(_flourPrice.text),
          ),
          RecipeCostItem(
            name: 'Maya/Tuz/Katkı',
            flatCost: NumberFormatter.parseLoose(_yeastFlat.text),
          ),
          RecipeCostItem(
            name: 'Yağ',
            quantity: NumberFormatter.parseLoose(_fatQty.text),
            unitPrice: NumberFormatter.parseLoose(_fatPrice.text),
          ),
          RecipeCostItem(
            name: 'Diğer Malzeme',
            flatCost: NumberFormatter.parseLoose(_otherFlat.text),
          ),
          RecipeCostItem(
            name: 'Ambalaj',
            flatCost: NumberFormatter.parseLoose(_packagingFlat.text),
          ),
        ],
        targetProfitPct: NumberFormatter.parseLoose(_targetProfit.text),
      );
    });
  }

  /// Verdict → fırıncı diliyle uyarı metni (matematik servis tarafında).
  List<String> _warnings(RecipeCostDetailResult r) {
    switch (r.verdict) {
      case RecipeCostVerdict.invalid:
        return const ['Üretim adedi ve en az bir maliyet kalemi girilmeli.'];
      case RecipeCostVerdict.ok:
        final profit = NumberFormatter.decimal(
          NumberFormatter.parseLoose(_targetProfit.text),
        );
        return [
          'En büyük kalem: ${r.dominantItemName} '
              '(${NumberFormatter.currency(r.dominantItemCost)}). '
              'Maliyet asıl burada yükseliyor.',
          'Hedef %$profit kâr için fiyatı en az '
              '${NumberFormatter.currency(r.suggestedPrice)} yap.',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcRecipeCostDetailTitle,
      hint:
          'Malzeme miktarı × birim fiyatla ürünün gerçek maliyetini ve '
          'hedef kâra göre fiyatını çıkar.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Üretim adedi',
          controller: _count,
          suffix: 'adet',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Un miktarı',
          controller: _flourQty,
          suffix: 'kg',
        ),
        AppNumberField(
          label: 'Un birim fiyatı',
          controller: _flourPrice,
          suffix: 'TL/kg',
        ),
        AppNumberField(
          label: 'Maya/tuz/katkı toplam',
          controller: _yeastFlat,
          suffix: 'TL',
        ),
        AppNumberField(label: 'Yağ miktarı', controller: _fatQty, suffix: 'kg'),
        AppNumberField(
          label: 'Yağ birim fiyatı',
          controller: _fatPrice,
          suffix: 'TL/kg',
        ),
        AppNumberField(
          label: 'Şeker/yumurta/süt vb.',
          controller: _otherFlat,
          suffix: 'TL',
        ),
        AppNumberField(
          label: 'Ambalaj/diğer',
          controller: _packagingFlat,
          suffix: 'TL',
        ),
        AppNumberField(
          label: 'Hedef kâr',
          controller: _targetProfit,
          suffix: '%',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Toplam hammadde maliyeti',
                  NumberFormatter.currency(r.totalCost),
                  icon: Icons.receipt_long_outlined,
                ),
                CalcResultLine(
                  'Ürün başı maliyet',
                  NumberFormatter.currency(r.costPerUnit),
                  icon: Icons.bakery_dining_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Önerilen satış fiyatı',
                  NumberFormatter.currency(r.suggestedPrice),
                  icon: Icons.sell_outlined,
                  hero: true,
                ),
              ],
            ),
    );
  }
}
