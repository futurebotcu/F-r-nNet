import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/oven_capacity_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Fırın Kapasite Hesabı" ekranı (patron modülü).
/// Matematik [OvenCapacityCalculator] servisindedir.
class OvenCapacityScreen extends StatefulWidget {
  const OvenCapacityScreen({super.key});

  @override
  State<OvenCapacityScreen> createState() => _OvenCapacityScreenState();
}

class _OvenCapacityScreenState extends State<OvenCapacityScreen> {
  static const OvenCapacityCalculator _calc = OvenCapacityCalculator();

  final _trays = TextEditingController(text: '8');
  final _piecesPerTray = TextEditingController(text: '30');
  final _bakeMinutes = TextEditingController(text: '25');
  final _dailyHours = TextEditingController(text: '10');
  final _loadUnload = TextEditingController(text: '5');

  OvenCapacityResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _trays.dispose();
    _piecesPerTray.dispose();
    _bakeMinutes.dispose();
    _dailyHours.dispose();
    _loadUnload.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        trayCount: NumberFormatter.parseLoose(_trays.text),
        piecesPerTray: NumberFormatter.parseLoose(_piecesPerTray.text),
        bakeMinutes: NumberFormatter.parseLoose(_bakeMinutes.text),
        dailyHours: NumberFormatter.parseLoose(_dailyHours.text),
        loadUnloadMinutes: NumberFormatter.parseLoose(_loadUnload.text),
      );
    });
  }

  /// Verdict → fırıncı diliyle uyarı metni (matematik servis tarafında).
  List<String> _warnings(OvenCapacityResult r) {
    switch (r.verdict) {
      case OvenCapacityVerdict.invalid:
        return const ['Tepsi, ürün ve süre bilgilerini gir.'];
      case OvenCapacityVerdict.noCycle:
        return const [
          'Pişirme süresi günlük çalışma saatine sığmıyor; '
              'süreleri kontrol et.',
        ];
      case OvenCapacityVerdict.ok:
        return const [
          'Fırın tam dolu çalışırsa günlük tavan bu; gerçek üretim genelde '
              'altında kalır.',
          'Yarım yükle çalışmak ürün başına enerji maliyetini artırır; '
              'turları dolu planla.',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcOvenCapacityTitle,
      hint:
          'Tepsi, pişirme süresi ve çalışma saatine göre fırının günlük '
          'tavanını gör.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Tepsi adedi',
          controller: _trays,
          suffix: 'tepsi',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Tepsi başı ürün',
          controller: _piecesPerTray,
          suffix: 'adet',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Pişirme süresi',
          controller: _bakeMinutes,
          suffix: 'dk',
        ),
        AppNumberField(
          label: 'Günlük fırın çalışma',
          controller: _dailyHours,
          suffix: 'saat',
        ),
        AppNumberField(
          label: 'Yükleme/boşaltma',
          controller: _loadUnload,
          suffix: 'dk',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Günlük tur',
                  NumberFormatter.integer(r.cyclesPerDay),
                  icon: Icons.replay_rounded,
                ),
                CalcResultLine(
                  'Azami günlük ürün',
                  NumberFormatter.integer(r.maxDailyPieces),
                  icon: Icons.bakery_dining_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Saatlik kapasite',
                  '≈${NumberFormatter.decimal(r.hourlyCapacity)} adet',
                  icon: Icons.speed_rounded,
                ),
              ],
            ),
    );
  }
}
