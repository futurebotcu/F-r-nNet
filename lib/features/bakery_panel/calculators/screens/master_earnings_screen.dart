import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/master_earnings_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Usta Hak Ediş Hesabı ekranı (patron modülü).
/// Matematik [MasterEarningsCalculator] servisindedir.
class MasterEarningsScreen extends StatefulWidget {
  const MasterEarningsScreen({super.key});

  @override
  State<MasterEarningsScreen> createState() => _MasterEarningsScreenState();
}

class _MasterEarningsScreenState extends State<MasterEarningsScreen> {
  static const MasterEarningsCalculator _calc = MasterEarningsCalculator();

  final _units = TextEditingController(text: '12');
  final _rate = TextEditingController(text: '90');
  final _fixed = TextEditingController(text: '0');
  final _deduction = TextEditingController(text: '0');

  MasterEarningsResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _units.dispose();
    _rate.dispose();
    _fixed.dispose();
    _deduction.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        unitsProcessed: NumberFormatter.parseLoose(_units.text),
        ratePerUnit: NumberFormatter.parseLoose(_rate.text),
        fixedDaily: NumberFormatter.parseLoose(_fixed.text),
        deduction: NumberFormatter.parseLoose(_deduction.text),
      );
    });
  }

  /// Verdict → patron diliyle uyarı metni (matematik servis tarafında).
  List<String> _warnings(MasterEarningsResult r) {
    switch (r.verdict) {
      case MasterEarningsVerdict.invalid:
        return const [
          'Çuval/parti sayısı ve prim (ya da sabit ücret) girilmeli.',
        ];
      case MasterEarningsVerdict.deductionExceeds:
        return const [
          'Avans/kesinti hak edişi aşıyor; net 0 gösterildi, kalan farkı '
              'sonraki hesaba konuş.',
        ];
      case MasterEarningsVerdict.ok:
        return const [
          'Bu vardiyanın tahmini hak edişi budur; resmî bordro yerine geçmez.',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcMasterEarningsTitle,
      hint:
          'Çuval ya da parti başı prim alan ustanın vardiyalık hak edişini '
          'çıkar.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(
          label: 'İşlenen çuval/parti',
          controller: _units,
          suffix: 'adet',
        ),
        AppNumberField(
          label: 'Çuval/parti başı prim',
          controller: _rate,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Sabit günlük ücret (opsiyonel)',
          controller: _fixed,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Kesinti/avans (opsiyonel)',
          controller: _deduction,
          suffix: '₺',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Prim toplamı',
                  NumberFormatter.currency(r.bonusTotal),
                  icon: Icons.workspace_premium_outlined,
                ),
                CalcResultLine(
                  'Brüt hak ediş',
                  NumberFormatter.currency(r.gross),
                  icon: Icons.account_balance_wallet_outlined,
                ),
                CalcResultLine(
                  'Net hak ediş',
                  NumberFormatter.currency(r.net),
                  icon: Icons.payments_outlined,
                  hero: true,
                ),
              ],
            ),
    );
  }
}
