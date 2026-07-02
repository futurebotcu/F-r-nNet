import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/fermentation_time_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Mayalanma Süresi Tahmini" ekranı (çalışan modülü).
/// Matematik [FermentationTimeCalculator] servisindedir; ekran yalnız
/// süreyi "sa/dk" ve tahmini hazır saatini biçimler.
class FermentationTimeScreen extends StatefulWidget {
  const FermentationTimeScreen({super.key});

  @override
  State<FermentationTimeScreen> createState() => _FermentationTimeScreenState();
}

class _FermentationTimeScreenState extends State<FermentationTimeScreen> {
  static const FermentationTimeCalculator _calc = FermentationTimeCalculator();

  final _ambient = TextEditingController(text: '24');
  final _dough = TextEditingController(text: '26');
  final _yeast = TextEditingController(text: '2');

  FermentationResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _ambient.dispose();
    _dough.dispose();
    _yeast.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        ambientTemp: NumberFormatter.parseLoose(_ambient.text),
        doughTemp: NumberFormatter.parseLoose(_dough.text),
        yeastPct: NumberFormatter.parseLoose(_yeast.text),
      );
    });
  }

  /// Verdict → fırıncı diliyle uyarı metni (matematik servis tarafında).
  List<String> _warnings(FermentationResult r) {
    switch (r.verdict) {
      case FermentationVerdict.noYeast:
        return const ['Maya oranı girilmeden süre tahmini yapılamaz.'];
      case FermentationVerdict.coldSlow:
        return const [
          'Ortam serin; mayalanma uzayabilir, hamuru sıcak bir köşede tut.',
        ];
      case FermentationVerdict.hotFast:
        return const [
          'Sıcak ortamda hamur hızlı gider; sık kontrol et, geçirme.',
        ];
      case FermentationVerdict.normal:
        return const [
          'Bu bir tahmindir; una ve mayaya göre değişir, hamuru gözünle de '
              'kontrol et.',
        ];
    }
  }

  /// Dakikayı "X sa Y dk" (60 dk altında "Y dk") biçimler — yalnız gösterim.
  String _formatMinutes(double minutes) {
    final total = minutes.round();
    if (total < 60) return '$total dk';
    final hours = total ~/ 60;
    final rest = total % 60;
    return '$hours sa $rest dk';
  }

  /// Şu andan itibaren tahmini hazır saati ("HH:mm") — yalnız gösterim.
  String _readyAt(double minutes) {
    final at = DateTime.now().add(Duration(minutes: minutes.round()));
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final noYeast = r?.verdict == FermentationVerdict.noYeast;
    return CalculatorFormScaffold(
      title: AppStrings.calcFermentationTitle,
      hint:
          'Kesin değil, pratik tahmin: ortam ve mayaya göre hamur yaklaşık '
          'ne zaman hazır olur?',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Ortam sıcaklığı',
          controller: _ambient,
          suffix: '°C',
        ),
        AppNumberField(
          label: 'Hamur sıcaklığı',
          controller: _dough,
          suffix: '°C',
        ),
        AppNumberField(
          label: 'Maya oranı (una göre)',
          controller: _yeast,
          suffix: '%',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Tahmini süre',
                  noYeast ? '—' : _formatMinutes(r.minutes),
                  icon: Icons.hourglass_bottom_rounded,
                  hero: true,
                ),
                CalcResultLine(
                  'Tahmini hazır saati',
                  noYeast ? '—' : _readyAt(r.minutes),
                  icon: Icons.schedule_rounded,
                ),
                CalcResultLine(
                  'Etkili sıcaklık',
                  '${NumberFormatter.decimal(r.effectiveTemp)} °C',
                  icon: Icons.thermostat_rounded,
                ),
              ],
            ),
    );
  }
}
