import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/pack_convert_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Koli / Paket Dönüştürücü" ekranı (ortak modül).
/// Matematik [PackConvertCalculator] servisindedir.
class PackConvertScreen extends StatefulWidget {
  const PackConvertScreen({super.key});

  @override
  State<PackConvertScreen> createState() => _PackConvertScreenState();
}

class _PackConvertScreenState extends State<PackConvertScreen> {
  static const PackConvertCalculator _calc = PackConvertCalculator();

  final _name = TextEditingController(text: 'Maya');
  final _needed = TextEditingController(text: '150');
  final _perPack = TextEditingController(text: '24');

  PackConvertResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _name.dispose();
    _needed.dispose();
    _perPack.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        neededUnits: NumberFormatter.parseLoose(_needed.text),
        unitsPerPack: NumberFormatter.parseLoose(_perPack.text),
      );
    });
  }

  /// Verdict → fırıncı diliyle uyarı metni (matematik servis tarafında).
  List<String> _warnings(PackConvertResult r, String product) {
    switch (r.verdict) {
      case PackConvertVerdict.invalid:
        return const ['Adet ve koli içi adet girilmeden çevirme yapılamaz.'];
      case PackConvertVerdict.exact:
        return const ['Sipariş tam koliye denk geliyor.'];
      case PackConvertVerdict.withRemainder:
        return [
          '$product için "${r.fullPacks} koli + ${r.remainderUnits} tekli" '
              'iste; tekli verilmiyorsa ${r.roundUpPacks} koli alıp '
              '${r.extraUnits} fazlayı hesaba kat.',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final product = _name.text.trim().isEmpty ? 'Ürün' : _name.text.trim();
    final invalid = r?.verdict == PackConvertVerdict.invalid;
    return CalculatorFormScaffold(
      title: AppStrings.calcPackConvertTitle,
      hint:
          'Maya, yağ, ambalaj gibi ürünlerde adet ile koli arasında hızlı '
          'çevir.',
      onCalculate: _recalculate,
      inputs: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Ürün adı'),
          onChanged: (_) => setState(() {}),
        ),
        AppNumberField(
          label: 'İstenen toplam adet',
          controller: _needed,
          suffix: 'adet',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Koli içi adet',
          controller: _perPack,
          suffix: 'adet',
          allowDecimal: false,
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r, product),
              lines: [
                CalcResultLine(
                  'Tam koli',
                  invalid ? '—' : NumberFormatter.integer(r.fullPacks),
                  icon: Icons.inventory_2_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Açıkta kalan',
                  invalid
                      ? '—'
                      : '${NumberFormatter.integer(r.remainderUnits)} adet',
                  icon: Icons.numbers_rounded,
                ),
                CalcResultLine(
                  'Yukarı yuvarlarsan',
                  invalid
                      ? '—'
                      : '${NumberFormatter.integer(r.roundUpPacks)} koli '
                            '(+${NumberFormatter.integer(r.extraUnits)} fazla)',
                  icon: Icons.move_up_rounded,
                ),
              ],
            ),
    );
  }
}
