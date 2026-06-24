import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_number_field.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/premium/premium_card.dart';
import '../../../../core/widgets/premium/premium_scaffold.dart';
import '../../models/recipe.dart' show RecipeResult;
import '../../models/recipe_quantities.dart';
import '../services/dough_yield_calculator.dart';
import '../widgets/calculator_quantity_row.dart';
import '../widgets/calculator_result_grid.dart';

/// "Hamurdan Ürün" hesabı — eski standalone Hesaplama Makinesi.
///
/// Reçete kaydetmeden hızlı hesap için. Saf motor
/// ([DoughYieldCalculator] → `RecipeCalculator.calculateFromQuantities`)
/// UI'dan ayrıdır. Davranış değişmedi; yalnız modüler hesaplama merkezine
/// (calculators/) taşındı ve ortak widget'lara bölündü.
///
/// Aksiyonlar:
/// - Hesapla
/// - Reçete olarak kaydet (`/recipes/new` push)
/// - WhatsApp / sistem paylaşımı (`share_plus`)
class DoughYieldCalculatorScreen extends ConsumerStatefulWidget {
  const DoughYieldCalculatorScreen({super.key});

  @override
  ConsumerState<DoughYieldCalculatorScreen> createState() =>
      _DoughYieldCalculatorScreenState();
}

class _DoughYieldCalculatorScreenState
    extends ConsumerState<DoughYieldCalculatorScreen> {
  static const DoughYieldCalculator _calculator = DoughYieldCalculator();

  // Default brief örneği — açılışta 316 adet veren değerler.
  final _flour = TextEditingController(text: '50');
  final _water = TextEditingController(text: '30');
  final _yeast = TextEditingController(text: '500');
  final _salt = TextEditingController(text: '1');
  final _piece = TextEditingController(text: '250');
  final _waste = TextEditingController(text: '2.445');

  MassUnit _waterUnit = MassUnit.l;
  MassUnit _yeastUnit = MassUnit.gr;
  MassUnit _saltUnit = MassUnit.kg;
  MassUnit _wasteUnit = MassUnit.kg;

  RecipeResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _flour.dispose();
    _water.dispose();
    _yeast.dispose();
    _salt.dispose();
    _piece.dispose();
    _waste.dispose();
    super.dispose();
  }

  RecipeQuantities _readQuantities() {
    return RecipeQuantities(
      flourKg: NumberFormatter.parseLoose(_flour.text),
      waterKg: massToKg(NumberFormatter.parseLoose(_water.text), _waterUnit),
      yeastKg: massToKg(NumberFormatter.parseLoose(_yeast.text), _yeastUnit),
      saltKg: massToKg(NumberFormatter.parseLoose(_salt.text), _saltUnit),
      pieceWeightG: NumberFormatter.parseLoose(_piece.text),
      wasteKg: _waste.text.trim().isEmpty
          ? 0.0
          : massToKg(NumberFormatter.parseLoose(_waste.text), _wasteUnit),
    );
  }

  void _recalculate() {
    setState(() => _result = _calculator.calculate(_readQuantities()));
  }

  Future<void> _share() async {
    if (_result == null) _recalculate();
    final r = _result;
    if (r == null) return;
    final q = _readQuantities();
    final text = [
      'Hızlı Hesap',
      'Un: ${_fmt(q.flourKg)} kg',
      'Su: ${_fmt(q.waterKg)} kg',
      'Maya: ${_fmt(q.yeastKg)} kg',
      'Tuz: ${_fmt(q.saltKg)} kg',
      'Gramaj: ${_fmt(q.pieceWeightG)} gr',
      if (q.wasteKg > 0) 'Fire: ${_fmt(q.wasteKg)} kg',
      'Toplam hamur: ${_fmt(r.totalDoughKg)} kg',
      'Net hamur: ${_fmt(r.doughAfterWasteKg)} kg',
      'Tahmini: ${r.estimatedPieces} adet',
      '',
      'FırınNet',
    ].join('\n');
    await Share.share(text, subject: 'FırınNet — Hızlı Hesap');
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    final s = v.toStringAsFixed(3);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  void _saveAsRecipe() {
    // Yeni reçete sihirbazına geç — kullanıcı orada ürün adı, malzemeler,
    // adımlar gibi ek alanları doldurup kaydedebilir. Quantity değerlerini
    // editöre ön doldurma şu an kapsam dışı (davranış korundu).
    context.push(AppRoutes.recipeNew);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(
        title: const Text(AppStrings.calcDoughYieldTitle),
        actions: [
          IconButton(
            tooltip: 'Paylaş',
            onPressed: _result == null ? null : _share,
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            const _Hint(),
            const SizedBox(height: AppSpacing.l),
            AppNumberField(label: 'Un (kg)', controller: _flour, suffix: 'kg'),
            const SizedBox(height: AppSpacing.s),
            CalculatorQuantityRow(
              label: 'Su',
              controller: _water,
              unit: _waterUnit,
              units: const [MassUnit.l, MassUnit.kg],
              onUnitChanged: (u) => setState(() => _waterUnit = u),
            ),
            const SizedBox(height: AppSpacing.s),
            CalculatorQuantityRow(
              label: 'Maya',
              controller: _yeast,
              unit: _yeastUnit,
              units: const [MassUnit.gr, MassUnit.kg],
              onUnitChanged: (u) => setState(() => _yeastUnit = u),
            ),
            const SizedBox(height: AppSpacing.s),
            CalculatorQuantityRow(
              label: 'Tuz',
              controller: _salt,
              unit: _saltUnit,
              units: const [MassUnit.kg, MassUnit.gr],
              onUnitChanged: (u) => setState(() => _saltUnit = u),
            ),
            const SizedBox(height: AppSpacing.s),
            AppNumberField(
              label: 'Birim gramaj',
              controller: _piece,
              suffix: 'gr',
            ),
            const SizedBox(height: AppSpacing.s),
            CalculatorQuantityRow(
              label: 'Fire / kayıp (opsiyonel)',
              controller: _waste,
              unit: _wasteUnit,
              units: const [MassUnit.kg, MassUnit.gr],
              onUnitChanged: (u) => setState(() => _wasteUnit = u),
              hint: 'Boşsa 0 sayılır',
            ),
            const SizedBox(height: AppSpacing.l),
            AppPrimaryButton(
              label: 'Hesapla',
              icon: Icons.calculate_rounded,
              onPressed: _recalculate,
            ),
            if (_result != null) ...[
              const SizedBox(height: AppSpacing.xl),
              const _Section(label: 'SONUÇ'),
              CalculatorResultGrid(result: _result!),
              const SizedBox(height: AppSpacing.l),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveAsRecipe,
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: const Text('Reçete olarak kaydet'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.softGold,
                        side: BorderSide(
                          color: AppColors.copper.withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.m),
                        ),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Paylaş'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.copper,
                        foregroundColor: AppColors.surface,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.m),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();
  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: const [
          Icon(Icons.bolt_rounded, color: AppColors.softGold, size: 18),
          SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              'Hızlı hesap — kayıt yapmadan sonuç al, istersen reçeteye dönüştür.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, AppSpacing.s),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.softGold,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
