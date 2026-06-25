import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../models/turkish_bakery_product_preset.dart';
import '../services/sack_to_bread_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Tam sayıysa ondalıksız, değilse sade ondalıklı metin (controller için).
String _numText(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// "Çuvaldan Kaç Ürün Çıkar?" ekranı. Matematik
/// [SackToBreadCalculator] servisindedir. Ürün seçimi yalnızca gramaj, su
/// kaldırma ve fire alanlarını **varsayılan** doldurur; kullanıcı her değeri
/// elle değiştirebilir, ürün seçmezse mevcut davranış korunur.
class SackToBreadScreen extends StatefulWidget {
  const SackToBreadScreen({super.key});

  @override
  State<SackToBreadScreen> createState() => _SackToBreadScreenState();
}

class _SackToBreadScreenState extends State<SackToBreadScreen> {
  static const SackToBreadCalculator _calc = SackToBreadCalculator();

  // Varsayılan "Diğer / Manuel" — mevcut davranış (60/500/3) korunur.
  TurkishBakeryProductPreset _product = TurkishBakeryProducts.manual;
  final _sacks = TextEditingController(text: '1');
  final _sackKg = TextEditingController(text: '50');
  final _absorption = TextEditingController(text: '60');
  final _doughG = TextEditingController(text: '500');
  final _waste = TextEditingController(text: '3');

  SackToBreadResult? _result;

  void _onProductChanged(TurkishBakeryProductPreset? p) {
    if (p == null) return;
    setState(() {
      _product = p;
      // Ürün seçimi yalnızca varsayılanları doldurur; manuel ise dokunma.
      if (!p.isManual) {
        _doughG.text = _numText(p.defaultDoughWeightG);
        _absorption.text = _numText(p.defaultHydrationPct);
        _waste.text = _numText(p.defaultBakeLossPct);
      }
    });
    _recalculate();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _sacks.dispose();
    _sackKg.dispose();
    _absorption.dispose();
    _doughG.dispose();
    _waste.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        sackCount: NumberFormatter.parseLoose(_sacks.text),
        sackKg: NumberFormatter.parseLoose(_sackKg.text),
        waterAbsorptionPct: NumberFormatter.parseLoose(_absorption.text),
        breadDoughG: NumberFormatter.parseLoose(_doughG.text),
        wastePct: NumberFormatter.parseLoose(_waste.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcSackBreadTitle,
      hint:
          'Çuvaldan yaklaşık kaç ürün çıkacağını tahmin eder. '
          '${AppStrings.calcPresetDefaultNote}',
      onCalculate: _recalculate,
      inputs: [
        DropdownButtonFormField<TurkishBakeryProductPreset>(
          initialValue: _product,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: AppStrings.calcProductSelectLabel,
          ),
          items: [
            for (final p in TurkishBakeryProducts.all)
              DropdownMenuItem(value: p, child: Text(p.displayName)),
          ],
          onChanged: _onProductChanged,
        ),
        AppNumberField(
          label: 'Çuval sayısı',
          controller: _sacks,
          suffix: 'çuval',
        ),
        AppNumberField(label: 'Çuval kg', controller: _sackKg, suffix: 'kg'),
        AppNumberField(
          label: 'Su kaldırma oranı',
          controller: _absorption,
          suffix: '%',
        ),
        AppNumberField(
          label: 'Ürün hamur gramajı',
          controller: _doughG,
          suffix: 'gr',
        ),
        AppNumberField(
          label: 'Pişme / fire oranı',
          controller: _waste,
          suffix: '%',
          hint: 'Bu oran tahminidir, ürün ve fırına göre değişir.',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: const [
                'Bu sonuç tahminidir; gramaj ve pişme firesi değişirse '
                    'adet değişir.',
                'Gramaj +10g saparsa çuval başına adet düşer, '
                    'teraziyi kontrol et.',
              ],
              lines: [
                CalcResultLine(
                  'Tahmini adet',
                  NumberFormatter.integer(r.estimatedPieces),
                  icon: Icons.numbers_rounded,
                  hero: true,
                ),
                CalcResultLine(
                  'Toplam un',
                  '${NumberFormatter.decimal(r.totalFlourKg)} kg',
                  icon: Icons.grain_rounded,
                ),
                CalcResultLine(
                  'Tahmini hamur',
                  '${NumberFormatter.decimal(r.estimatedDoughKg)} kg',
                  icon: Icons.scale_outlined,
                ),
                CalcResultLine(
                  'Fire sonrası net hamur',
                  '${NumberFormatter.decimal(r.netDoughKg)} kg',
                  icon: Icons.water_drop_outlined,
                ),
              ],
            ),
    );
  }
}
