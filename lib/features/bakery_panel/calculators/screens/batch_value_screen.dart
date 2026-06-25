import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/batch_value_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Tepsi / Parti Bazında Değer" ekranı (ortak modül).
/// Matematik [BatchValueCalculator] servisindedir.
class BatchValueScreen extends StatefulWidget {
  const BatchValueScreen({super.key});

  @override
  State<BatchValueScreen> createState() => _BatchValueScreenState();
}

class _BatchValueScreenState extends State<BatchValueScreen> {
  static const BatchValueCalculator _calc = BatchValueCalculator();

  final _name = TextEditingController(text: 'Poğaça');
  final _perBatch = TextEditingController(text: '40');
  final _cost = TextEditingController(text: '4');
  final _price = TextEditingController(text: '7.5');
  final _batches = TextEditingController(text: '6');

  BatchValueResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _name.dispose();
    _perBatch.dispose();
    _cost.dispose();
    _price.dispose();
    _batches.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        unitsPerBatch: NumberFormatter.parseLoose(_perBatch.text),
        costPerUnit: NumberFormatter.parseLoose(_cost.text),
        salePricePerUnit: NumberFormatter.parseLoose(_price.text),
        batchCount: NumberFormatter.parseLoose(_batches.text),
      );
    });
  }

  /// Verdict → fırıncı diliyle yorum (matematik servis tarafında).
  List<String> _warnings(BatchValueResult r) {
    switch (r.verdict) {
      case BatchProfitVerdict.loss:
        return const [
          'Bu fiyatla bu parti zarar ettiriyor — satış fiyatını veya '
              'maliyeti gözden geçir.',
        ];
      case BatchProfitVerdict.thin:
        return const [
          'Kâr ince görünüyor; küçük bir maliyet artışı bu partiyi zarara '
              'çevirebilir.',
        ];
      case BatchProfitVerdict.healthy:
        return const ['Bu parti satılırsa kasaya iyi bir brüt kâr bırakır.'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcBatchValueTitle,
      hint:
          'Bir tepsi/parti üretimin maliyetini, satış değerini ve kasaya '
          'bırakacağı brüt kârı gör.',
      onCalculate: _recalculate,
      inputs: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Ürün adı'),
        ),
        AppNumberField(
          label: 'Tepside/partide ürün sayısı',
          controller: _perBatch,
          suffix: 'adet',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Ürün başı maliyet',
          controller: _cost,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Ürün satış fiyatı',
          controller: _price,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Tepsi / parti sayısı',
          controller: _batches,
          suffix: 'parti',
          allowDecimal: false,
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Tahmini brüt kâr',
                  NumberFormatter.currency(r.grossProfit),
                  icon: Icons.savings_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Toplam satış değeri',
                  NumberFormatter.currency(r.totalSale),
                  icon: Icons.point_of_sale_outlined,
                ),
                CalcResultLine(
                  'Toplam üretim maliyeti',
                  NumberFormatter.currency(r.totalCost),
                  icon: Icons.receipt_long_outlined,
                ),
                CalcResultLine(
                  'Adet başı kâr',
                  NumberFormatter.currency(r.profitPerUnit),
                  icon: Icons.sell_outlined,
                ),
                CalcResultLine(
                  'Toplam adet',
                  NumberFormatter.integer(r.totalUnits),
                  icon: Icons.numbers_rounded,
                ),
              ],
            ),
    );
  }
}
