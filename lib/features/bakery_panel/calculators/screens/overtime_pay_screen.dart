import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/overtime_pay_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Mesai + Prim Hesaplayıcı" ekranı (çalışan modülü).
/// Matematik [OvertimePayCalculator] servisindedir.
class OvertimePayScreen extends StatefulWidget {
  const OvertimePayScreen({super.key});

  @override
  State<OvertimePayScreen> createState() => _OvertimePayScreenState();
}

class _OvertimePayScreenState extends State<OvertimePayScreen> {
  static const OvertimePayCalculator _calc = OvertimePayCalculator();

  final _hours = TextEditingController(text: '11');
  final _normalHours = TextEditingController(text: '9');
  final _wage = TextEditingController(text: '120');
  final _multiplier = TextEditingController(text: '1.5');
  final _produced = TextEditingController(text: '0');
  final _threshold = TextEditingController(text: '0');
  final _bonusAmount = TextEditingController(text: '0');

  OvertimePayResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _hours.dispose();
    _normalHours.dispose();
    _wage.dispose();
    _multiplier.dispose();
    _produced.dispose();
    _threshold.dispose();
    _bonusAmount.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        hoursWorked: NumberFormatter.parseLoose(_hours.text),
        normalHours: NumberFormatter.parseLoose(_normalHours.text),
        hourlyWage: NumberFormatter.parseLoose(_wage.text),
        overtimeMultiplier: NumberFormatter.parseLoose(_multiplier.text),
        producedCount: NumberFormatter.parseLoose(_produced.text),
        bonusThreshold: NumberFormatter.parseLoose(_threshold.text),
        bonusAmount: NumberFormatter.parseLoose(_bonusAmount.text),
      );
    });
  }

  /// Durum → fırıncı diliyle uyarı metinleri (matematik servis tarafında;
  /// yalnız "eşiğe kalan adet" gösterim için ekranda türetilir).
  List<String> _warnings(OvertimePayResult r) {
    final warnings = <String>[];
    if (r.overtimeHours > 0) {
      warnings.add(
        'Bugün ${NumberFormatter.decimal(r.overtimeHours)} saat fazla '
        'mesain var; karşılığı ${NumberFormatter.currency(r.overtimePay)}.',
      );
    }
    switch (r.bonusStatus) {
      case OvertimeBonusStatus.earned:
        warnings.add('Prim eşiği geçildi, prim hak edildi.');
      case OvertimeBonusStatus.missed:
        final threshold = NumberFormatter.parseLoose(_threshold.text);
        final produced = NumberFormatter.parseLoose(_produced.text);
        final remaining = threshold - produced;
        warnings.add(
          'Prim eşiği geçilmedi; eşiğe '
          '${NumberFormatter.integer(remaining < 0 ? 0 : remaining)} adet '
          'kaldı.',
        );
      case OvertimeBonusStatus.none:
        break;
    }
    warnings.add('Bu tahmini bir hesaptır; resmî bordro yerine geçmez.');
    return warnings;
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcOvertimePayTitle,
      hint:
          'Bugünkü mesai ve primin tahmini karşılığını gör; resmî bordro '
          'yerine geçmez.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'Çalışılan saat',
          controller: _hours,
          suffix: 'saat',
        ),
        AppNumberField(
          label: 'Normal mesai',
          controller: _normalHours,
          suffix: 'saat',
        ),
        AppNumberField(label: 'Saatlik ücret', controller: _wage, suffix: 'TL'),
        AppNumberField(
          label: 'Fazla mesai katsayısı',
          controller: _multiplier,
          suffix: 'x',
        ),
        AppNumberField(
          label: 'Üretim adedi (opsiyonel)',
          controller: _produced,
          suffix: 'adet',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Prim eşiği (opsiyonel)',
          controller: _threshold,
          suffix: 'adet',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Prim tutarı (opsiyonel)',
          controller: _bonusAmount,
          suffix: 'TL',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Normal ücret',
                  NumberFormatter.currency(r.normalPay),
                  icon: Icons.schedule_rounded,
                ),
                CalcResultLine(
                  'Fazla mesai',
                  '${NumberFormatter.decimal(r.overtimeHours)} sa → '
                      '${NumberFormatter.currency(r.overtimePay)}',
                  icon: Icons.more_time_rounded,
                ),
                if (r.bonusStatus != OvertimeBonusStatus.none)
                  CalcResultLine(
                    'Prim',
                    NumberFormatter.currency(r.bonus),
                    icon: Icons.emoji_events_outlined,
                  ),
                CalcResultLine(
                  'Toplam tahmini hak ediş',
                  NumberFormatter.currency(r.total),
                  icon: Icons.payments_outlined,
                  hero: true,
                ),
              ],
            ),
    );
  }
}
