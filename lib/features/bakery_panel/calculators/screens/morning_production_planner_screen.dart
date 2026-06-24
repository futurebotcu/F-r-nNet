import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/morning_production_planner.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Üretim planında seçilebilen hazır ürün tipleri (gramaj eşlemesi).
enum _ProductType { ekmek250, ekmek300, simit100, pogaca80, pogaca100, other }

extension _ProductTypeMeta on _ProductType {
  String get label {
    switch (this) {
      case _ProductType.ekmek250:
        return 'Ekmek 250g';
      case _ProductType.ekmek300:
        return 'Ekmek 300g';
      case _ProductType.simit100:
        return 'Simit 100g';
      case _ProductType.pogaca80:
        return 'Poğaça 80g';
      case _ProductType.pogaca100:
        return 'Poğaça 100g';
      case _ProductType.other:
        return 'Diğer';
    }
  }

  /// Hazır gramaj (gr); [other] için null (kullanıcı girer).
  double? get grams {
    switch (this) {
      case _ProductType.ekmek250:
        return 250;
      case _ProductType.ekmek300:
        return 300;
      case _ProductType.simit100:
        return 100;
      case _ProductType.pogaca80:
        return 80;
      case _ProductType.pogaca100:
        return 100;
      case _ProductType.other:
        return null;
    }
  }
}

/// Sabah Üretim Planlayıcı ekranı — adetten malzeme planı (un/su/maya/tuz).
///
/// Matematik [MorningProductionPlanner] servisindedir; ekran yalnız girdi
/// toplar ve sonucu sade kartlarla gösterir.
class MorningProductionPlannerScreen extends StatefulWidget {
  const MorningProductionPlannerScreen({super.key});

  @override
  State<MorningProductionPlannerScreen> createState() =>
      _MorningProductionPlannerScreenState();
}

class _MorningProductionPlannerScreenState
    extends State<MorningProductionPlannerScreen> {
  static const MorningProductionPlanner _planner = MorningProductionPlanner();

  _ProductType _type = _ProductType.ekmek250;
  final _customGram = TextEditingController(text: '250');
  final _count = TextEditingController(text: '500');
  final _waste = TextEditingController(text: '3');
  final _capacity = TextEditingController();

  MorningPlanResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _customGram.dispose();
    _count.dispose();
    _waste.dispose();
    _capacity.dispose();
    super.dispose();
  }

  double get _pieceGrams =>
      _type.grams ?? NumberFormatter.parseLoose(_customGram.text);

  void _recalculate() {
    setState(() {
      _result = _planner.plan(
        count: NumberFormatter.parseLoose(_count.text),
        pieceWeightG: _pieceGrams,
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
      hint: 'Adet ve ürün tipinden un, su, maya, tuz ve çuval planı çıkar.',
      onCalculate: _recalculate,
      inputs: [
        DropdownButtonFormField<_ProductType>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Ürün tipi'),
          items: [
            for (final t in _ProductType.values)
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (t) {
            if (t == null) return;
            setState(() => _type = t);
            _recalculate();
          },
        ),
        if (_type == _ProductType.other)
          AppNumberField(
            label: 'Birim gramaj',
            controller: _customGram,
            suffix: 'gr',
          ),
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
