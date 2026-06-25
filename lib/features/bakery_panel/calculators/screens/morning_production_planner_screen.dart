import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../models/turkish_bakery_product_preset.dart';
import '../services/morning_production_planner.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Tam sayıysa ondalıksız, değilse sade ondalıklı metin (controller için).
String _numText(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Sabah Üretim Planlayıcı ekranı — adetten malzeme planı (un/su/maya/tuz).
///
/// Ürün listesi ortak [TurkishBakeryProducts] kataloğundan beslenir; ürün
/// seçimi yalnızca gramaj ve pişme/fire alanlarını **varsayılan** doldurur,
/// kullanıcı her değeri elle değiştirebilir. Matematik
/// [MorningProductionPlanner] servisindedir; formül davranışı korunmuştur
/// (girdiler aynı: gramaj + fire).
class MorningProductionPlannerScreen extends StatefulWidget {
  const MorningProductionPlannerScreen({super.key});

  @override
  State<MorningProductionPlannerScreen> createState() =>
      _MorningProductionPlannerScreenState();
}

class _MorningProductionPlannerScreenState
    extends State<MorningProductionPlannerScreen> {
  static const MorningProductionPlanner _planner = MorningProductionPlanner();

  TurkishBakeryProductPreset _product = TurkishBakeryProducts.all.first;
  late final TextEditingController _gram = TextEditingController(
    text: _numText(_product.defaultDoughWeightG),
  );
  final _count = TextEditingController(text: '500');
  late final TextEditingController _waste = TextEditingController(
    text: _numText(_product.defaultBakeLossPct),
  );
  final _capacity = TextEditingController();

  MorningPlanResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _gram.dispose();
    _count.dispose();
    _waste.dispose();
    _capacity.dispose();
    super.dispose();
  }

  void _onProductChanged(TurkishBakeryProductPreset? p) {
    if (p == null) return;
    setState(() {
      _product = p;
      // Ürün seçimi yalnızca varsayılanları doldurur; manuel ise dokunma.
      if (!p.isManual) {
        _gram.text = _numText(p.defaultDoughWeightG);
        _waste.text = _numText(p.defaultBakeLossPct);
      }
    });
    _recalculate();
  }

  void _recalculate() {
    setState(() {
      _result = _planner.plan(
        count: NumberFormatter.parseLoose(_count.text),
        pieceWeightG: NumberFormatter.parseLoose(_gram.text),
        wastePct: NumberFormatter.parseLoose(_waste.text),
        mixerCapacityKg: NumberFormatter.parseLoose(_capacity.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcMorningPlanTitle,
      hint:
          'Adet ve ürün tipinden un, su, maya, tuz ve çuval planı çıkar. '
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
        AppNumberField(label: 'Birim gramaj', controller: _gram, suffix: 'gr'),
        AppNumberField(label: 'Adet', controller: _count, allowDecimal: false),
        AppNumberField(
          label: 'Pişme / fire oranı',
          controller: _waste,
          suffix: '%',
          hint: 'Bu oran tahminidir, ürün ve fırına göre değişir.',
        ),
        AppNumberField(
          label: 'Yoğurma kapasitesi (opsiyonel)',
          controller: _capacity,
          suffix: 'kg',
          hint: 'Boşsa kapasite uyarısı kapalı',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: [
                if (r.capacityExceeded)
                  'Toplam hamur (${NumberFormatter.decimal(r.totalDoughKg)} kg) '
                      'yoğurma kapasitesini aşıyor — partilere böl.',
              ],
              lines: [
                CalcResultLine(
                  'Gerekli un',
                  '${NumberFormatter.decimal(r.flourKg)} kg',
                  icon: Icons.grain_rounded,
                  hero: true,
                ),
                CalcResultLine(
                  'Çuval karşılığı',
                  NumberFormatter.decimal(r.sacks),
                  icon: Icons.inventory_2_outlined,
                ),
                CalcResultLine(
                  'Su',
                  '${NumberFormatter.decimal(r.waterKg)} kg / L',
                  icon: Icons.water_drop_outlined,
                ),
                CalcResultLine(
                  'Maya',
                  '${NumberFormatter.decimal(r.yeastKg)} kg',
                  icon: Icons.science_outlined,
                ),
                CalcResultLine(
                  'Tuz',
                  '${NumberFormatter.decimal(r.saltKg)} kg',
                  icon: Icons.spa_outlined,
                ),
                CalcResultLine(
                  'Toplam hamur',
                  '${NumberFormatter.decimal(r.totalDoughKg)} kg',
                  icon: Icons.scale_outlined,
                ),
                CalcResultLine(
                  'Fire sonrası beklenen adet',
                  NumberFormatter.integer(r.expectedPiecesAfterWaste),
                  icon: Icons.numbers_rounded,
                ),
              ],
            ),
    );
  }
}
