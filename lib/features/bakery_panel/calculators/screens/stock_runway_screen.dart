import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../services/stock_runway_calculator.dart';
import '../widgets/calculator_form_scaffold.dart';
import '../widgets/calculator_result_list.dart';

/// "Stok Bu Hafta Biter mi?" ekranı (ortak modül).
/// Matematik [StockRunwayCalculator] servisindedir.
class StockRunwayScreen extends StatefulWidget {
  const StockRunwayScreen({super.key});

  @override
  State<StockRunwayScreen> createState() => _StockRunwayScreenState();
}

class _StockRunwayScreenState extends State<StockRunwayScreen> {
  static const StockRunwayCalculator _calc = StockRunwayCalculator();

  final _name = TextEditingController(text: 'Un');
  final _stock = TextEditingController(text: '600');
  final _usage = TextEditingController(text: '100');
  final _lead = TextEditingController(text: '2');
  final _safety = TextEditingController(text: '1');

  StockRunwayResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _name.dispose();
    _stock.dispose();
    _usage.dispose();
    _lead.dispose();
    _safety.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = _calc.calculate(
        currentStock: NumberFormatter.parseLoose(_stock.text),
        dailyUsage: NumberFormatter.parseLoose(_usage.text),
        leadTimeDays: NumberFormatter.parseLoose(_lead.text),
        safetyStockDays: NumberFormatter.parseLoose(_safety.text),
      );
    });
  }

  /// Verdict → fırıncı diliyle uyarı metni (matematik servis tarafında).
  List<String> _warnings(StockRunwayResult r) {
    switch (r.verdict) {
      case StockRunwayVerdict.noUsage:
        return const [
          'Günlük tüketim girilmeden stok kaç gün gider hesaplanamaz.',
        ];
      case StockRunwayVerdict.orderNow:
        return const [
          'Teslim süresine göre siparişi geciktirme — bugün sipariş vermelisin.',
        ];
      case StockRunwayVerdict.critical:
        return const ['Bu stok 3 günden az gidiyor, siparişi geciktirme.'];
      case StockRunwayVerdict.orderSoon:
        return const ['Teslim süresine göre yarın sipariş vermelisin.'];
      case StockRunwayVerdict.ok:
        return const ['Stok şimdilik güvenli; sipariş için aceleye gerek yok.'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final material = _name.text.trim().isEmpty ? 'Malzeme' : _name.text.trim();
    return CalculatorFormScaffold(
      title: AppStrings.calcStockRunwayTitle,
      hint:
          'Eldeki malzeme kaç gün yeter, teslim süresine göre ne zaman '
          'sipariş vermelisin gör.',
      onCalculate: _recalculate,
      inputs: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Malzeme adı'),
          onChanged: (_) => setState(() {}),
        ),
        AppNumberField(
          label: 'Eldeki miktar',
          controller: _stock,
          suffix: 'kg/adet',
        ),
        AppNumberField(
          label: 'Günlük ortalama tüketim',
          controller: _usage,
          suffix: 'kg/adet',
        ),
        AppNumberField(
          label: 'Sipariş teslim süresi',
          controller: _lead,
          suffix: 'gün',
          allowDecimal: false,
        ),
        AppNumberField(
          label: 'Güvenli stok günü',
          controller: _safety,
          suffix: 'gün',
          allowDecimal: false,
        ),
      ],
      result: r == null
          ? null
          : CalculatorResultList(
              warnings: _warnings(r),
              lines: [
                CalcResultLine(
                  '$material kaç gün yeter',
                  r.verdict == StockRunwayVerdict.noUsage
                      ? '—'
                      : '${NumberFormatter.decimal(r.daysOfCover)} gün',
                  icon: Icons.event_available_outlined,
                  hero: true,
                ),
                CalcResultLine(
                  'Sipariş için kalan gün',
                  r.verdict == StockRunwayVerdict.noUsage
                      ? '—'
                      : '${NumberFormatter.decimal(r.orderInDays < 0 ? 0 : r.orderInDays)} gün',
                  icon: Icons.local_shipping_outlined,
                ),
              ],
            ),
    );
  }
}
