import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../models/turkish_bakery_product_preset.dart';
import '../services/dough_water_ratio_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Hamur Kıvamı (Su Oranı) ekranı — su/un oranını yüzde verir + kıvam yorumu.
/// Matematik [DoughWaterRatioCalculator] servisindedir (formül değişmez).
///
/// Ürün grubu seçilirse o gruba uygun ideal su oranı bandı (eşikler) uygulanır;
/// grup seçilmezse genel varsayılan eşik (60/65/70) korunur.
class DoughWaterRatioScreen extends StatefulWidget {
  const DoughWaterRatioScreen({super.key});

  @override
  State<DoughWaterRatioScreen> createState() => _DoughWaterRatioScreenState();
}

class _DoughWaterRatioScreenState extends State<DoughWaterRatioScreen> {
  // null → ürün seçilmedi; genel varsayılan eşik (60/65/70) kullanılır.
  BakeryProductGroup? _group;

  final _flour = TextEditingController(text: '50');
  final _water = TextEditingController(text: '33');

  DoughWaterRatioResult? _result;

  /// Seçilen gruba göre hesaplayıcı. Grup yoksa/bandı yoksa servis varsayılanı
  /// (60/65/70) — mevcut davranış korunur. Çekirdek formül değişmez; yalnız
  /// eşik parametreleri ürün grubuna göre dolar.
  DoughWaterRatioCalculator get _calc {
    final band = _group?.hydrationBand;
    if (band == null) return const DoughWaterRatioCalculator();
    return DoughWaterRatioCalculator(
      stiffBelow: band.stiffBelow,
      lowWaterBelow: band.idealLow,
      idealBelow: band.idealHigh,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _flour.dispose();
    _water.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.evaluate(
        flourKg: NumberFormatter.parseLoose(_flour.text),
        waterKg: NumberFormatter.parseLoose(_water.text),
      );
    });
  }

  static String _bandLabel(DoughHydrationBand band) {
    switch (band) {
      case DoughHydrationBand.tooStiff:
        return 'Çok sert — su ekle';
      case DoughHydrationBand.lowWater:
        return 'Su az';
      case DoughHydrationBand.ideal:
        return 'İdeal kıvam';
      case DoughHydrationBand.highWater:
        return 'Su fazla';
    }
  }

  /// Sonuç bandına göre pratik fırıncı yorumu (uyarı bandında gösterilir).
  static String _bandAdvice(DoughHydrationBand band) {
    switch (band) {
      case DoughHydrationBand.tooStiff:
      case DoughHydrationBand.lowWater:
        return 'Hamur sert kalabilir; ürün tipine göre biraz su gerekebilir.';
      case DoughHydrationBand.ideal:
        return 'Kıvam iyi görünüyor; teraziyi bu oranla koru.';
      case DoughHydrationBand.highWater:
        return 'Su fazla olabilir; hamur yapışırsa un eklemeden önce bekle.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcWaterRatioTitle,
      hint:
          'Hamurun kıvamını söyler: su az mı, ideal mi, fazla mı? '
          'Eşikler ürün tipine göre değişebilir.',
      onCalculate: _recalculate,
      inputs: [
        DropdownButtonFormField<BakeryProductGroup?>(
          initialValue: _group,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: AppStrings.calcProductGroupSelectLabel,
          ),
          items: [
            const DropdownMenuItem<BakeryProductGroup?>(
              value: null,
              child: Text('Genel (ürün seçme)'),
            ),
            for (final g in TurkishBakeryProducts.hydrationGroups)
              DropdownMenuItem<BakeryProductGroup?>(
                value: g,
                child: Text(g.displayName),
              ),
          ],
          onChanged: (g) {
            setState(() => _group = g);
            _recalculate();
          },
        ),
        AppNumberField(label: 'Un', controller: _flour, suffix: 'kg'),
        AppNumberField(label: 'Su', controller: _water, suffix: 'L / kg'),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: [_bandAdvice(r.band)],
              lines: [
                CalcResultLine(
                  'Su oranı',
                  '%${NumberFormatter.decimal(r.ratioPct)}',
                  icon: Icons.percent_rounded,
                  hero: true,
                ),
                CalcResultLine(
                  'Kıvam',
                  _bandLabel(r.band),
                  icon: Icons.thermostat_auto_outlined,
                ),
              ],
            ),
    );
  }
}
