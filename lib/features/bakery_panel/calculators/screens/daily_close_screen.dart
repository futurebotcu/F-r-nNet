import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/daily_close_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// Günlük Kapanış (Kâr / Zarar) ekranı (patron modülü).
/// Matematik [DailyCloseCalculator] servisindedir.
class DailyCloseScreen extends StatefulWidget {
  const DailyCloseScreen({super.key});

  @override
  State<DailyCloseScreen> createState() => _DailyCloseScreenState();
}

class _DailyCloseScreenState extends State<DailyCloseScreen> {
  static const DailyCloseCalculator _calc = DailyCloseCalculator();

  final _revenue = TextEditingController(text: '25000');
  final _material = TextEditingController(text: '9000');
  final _staff = TextEditingController(text: '6000');
  final _fixed = TextEditingController(text: '2500');
  final _energy = TextEditingController(text: '1500');
  final _waste = TextEditingController(text: '800');
  final _cash = TextEditingController(text: '0');

  DailyCloseResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _revenue.dispose();
    _material.dispose();
    _staff.dispose();
    _fixed.dispose();
    _energy.dispose();
    _waste.dispose();
    _cash.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        revenue: NumberFormatter.parseLoose(_revenue.text),
        materialCost: NumberFormatter.parseLoose(_material.text),
        staffCost: NumberFormatter.parseLoose(_staff.text),
        fixedShare: NumberFormatter.parseLoose(_fixed.text),
        energyOther: NumberFormatter.parseLoose(_energy.text),
        wasteLoss: NumberFormatter.parseLoose(_waste.text),
        cashInRegister: NumberFormatter.parseLoose(_cash.text),
      );
    });
  }

  /// Verdict → patron diliyle uyarı metni (matematik servis tarafında).
  List<String> _warnings(DailyCloseResult r) {
    final warnings = <String>[];
    switch (r.verdict) {
      case DailyCloseVerdict.noRevenue:
        warnings.add('Ciro girilmeden kapanış hesabı çıkmaz.');
      case DailyCloseVerdict.loss:
        warnings.add(
          'Bugün tahmini zarar var; önce fire ve malzeme kalemine bak.',
        );
      case DailyCloseVerdict.breakeven:
        warnings.add(
          'Bugün başa baş; küçük bir fiyat ya da fire iyileştirmesi günü '
          'kâra çevirir.',
        );
      case DailyCloseVerdict.profit:
        warnings.add(
          'Bugün cebine kalan tahmini net kâr '
          '${NumberFormatter.currency(r.netProfit)}.',
        );
    }
    if (r.hasCash && r.cashDiff.abs() > 1) {
      warnings.add(
        'Kasa ile girilen ciro arasında '
        '${NumberFormatter.currency(r.cashDiff.abs())} fark var; kasayı say, '
        'veresiye/harcamayı kontrol et.',
      );
    }
    return warnings;
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CalculatorFormScaffold(
      title: AppStrings.calcDailyCloseTitle,
      hint:
          'Akşam kapanışta günün kaba kâr/zarar röntgenini çek; kayıt tutmaz, '
          'sadece hesaplar.',
      onCalculate: _recalculate,
      inputs: [
        AppNumberField(label: 'Günlük ciro', controller: _revenue, suffix: '₺'),
        AppNumberField(
          label: 'Malzeme gideri',
          controller: _material,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Personel gideri',
          controller: _staff,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Sabit gider payı',
          controller: _fixed,
          suffix: '₺',
        ),
        AppNumberField(label: 'Enerji/diğer', controller: _energy, suffix: '₺'),
        AppNumberField(
          label: 'Bayat/fire zararı',
          controller: _waste,
          suffix: '₺',
        ),
        AppNumberField(
          label: 'Kasadaki para (opsiyonel)',
          controller: _cash,
          suffix: '₺',
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  'Gider toplamı',
                  NumberFormatter.currency(r.totalExpense),
                  icon: Icons.receipt_long_outlined,
                ),
                CalcResultLine(
                  'Tahmini net kâr',
                  NumberFormatter.currency(r.netProfit),
                  icon: Icons.payments_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Kâr oranı',
                  '%${NumberFormatter.decimal(r.profitMarginPct)}',
                  icon: Icons.percent_rounded,
                ),
                if (r.hasCash)
                  CalcResultLine(
                    'Kasa farkı',
                    NumberFormatter.currency(r.cashDiff),
                    icon: Icons.point_of_sale_outlined,
                  ),
              ],
            ),
    );
  }
}
