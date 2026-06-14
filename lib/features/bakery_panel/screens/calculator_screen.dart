import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/stat_card.dart';
import '../models/recipe_quantities.dart';
import '../models/recipe.dart' show RecipeResult;
import '../providers/bakery_providers.dart';

/// Standalone Hesaplama Makinesi.
///
/// Reçete kaydetmeden hızlı hesap için ayrı route. Aynı motor
/// (`RecipeCalculator.calculateFromQuantities`) — sonuç hem ticari hem
/// bireysel panelde kullanılabilir.
///
/// Aksiyonlar:
/// - Hesapla
/// - Reçete olarak kaydet (`/recipes/new` push, alan ön doldurma için
///   şu an basit yönlendirme)
/// - WhatsApp / sistem paylaşımı (`share_plus`)
class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

enum _MassUnit { kg, gr, l }

extension on _MassUnit {
  String get label {
    switch (this) {
      case _MassUnit.kg:
        return 'kg';
      case _MassUnit.gr:
        return 'gr';
      case _MassUnit.l:
        return 'L';
    }
  }
}

double _toKg(double value, _MassUnit unit) {
  switch (unit) {
    case _MassUnit.kg:
    case _MassUnit.l:
      return value;
    case _MassUnit.gr:
      return value / 1000.0;
  }
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  // Default brief örneği — açılışta 316 adet veren değerler.
  final _flour = TextEditingController(text: '50');
  final _water = TextEditingController(text: '30');
  final _yeast = TextEditingController(text: '500');
  final _salt = TextEditingController(text: '1');
  final _piece = TextEditingController(text: '250');
  final _waste = TextEditingController(text: '2.445');

  _MassUnit _waterUnit = _MassUnit.l;
  _MassUnit _yeastUnit = _MassUnit.gr;
  _MassUnit _saltUnit = _MassUnit.kg;
  _MassUnit _wasteUnit = _MassUnit.kg;

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
      waterKg: _toKg(NumberFormatter.parseLoose(_water.text), _waterUnit),
      yeastKg: _toKg(NumberFormatter.parseLoose(_yeast.text), _yeastUnit),
      saltKg: _toKg(NumberFormatter.parseLoose(_salt.text), _saltUnit),
      pieceWeightG: NumberFormatter.parseLoose(_piece.text),
      wasteKg: _waste.text.trim().isEmpty
          ? 0.0
          : _toKg(NumberFormatter.parseLoose(_waste.text), _wasteUnit),
    );
  }

  void _recalculate() {
    final calc = ref.read(recipeCalculatorProvider);
    setState(() => _result = calc.calculateFromQuantities(_readQuantities()));
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
    // adımlar gibi ek alanları doldurup kaydedebilir. Şu an quantity
    // değerlerini editöre ön doldurma kapsam dışı (V1.2 minimal).
    context.push(AppRoutes.recipeNew);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(
        title: const Text('Hesaplama Makinesi'),
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
            _QuantityRow(
              label: 'Su',
              controller: _water,
              unit: _waterUnit,
              units: const [_MassUnit.l, _MassUnit.kg],
              onUnitChanged: (u) => setState(() => _waterUnit = u),
            ),
            const SizedBox(height: AppSpacing.s),
            _QuantityRow(
              label: 'Maya',
              controller: _yeast,
              unit: _yeastUnit,
              units: const [_MassUnit.gr, _MassUnit.kg],
              onUnitChanged: (u) => setState(() => _yeastUnit = u),
            ),
            const SizedBox(height: AppSpacing.s),
            _QuantityRow(
              label: 'Tuz',
              controller: _salt,
              unit: _saltUnit,
              units: const [_MassUnit.kg, _MassUnit.gr],
              onUnitChanged: (u) => setState(() => _saltUnit = u),
            ),
            const SizedBox(height: AppSpacing.s),
            AppNumberField(
              label: 'Birim gramaj',
              controller: _piece,
              suffix: 'gr',
            ),
            const SizedBox(height: AppSpacing.s),
            _QuantityRow(
              label: 'Fire / kayıp (opsiyonel)',
              controller: _waste,
              unit: _wasteUnit,
              units: const [_MassUnit.kg, _MassUnit.gr],
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
              _ResultGrid(result: _result!),
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
                        foregroundColor: AppColors.brandInk,
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

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.result});
  final RecipeResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.scale_outlined,
                label: 'Toplam hamur',
                value: '${NumberFormatter.decimal(result.totalDoughKg)} kg',
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: StatCard(
                icon: Icons.cleaning_services_outlined,
                label: 'Net hamur',
                value:
                    '${NumberFormatter.decimal(result.doughAfterWasteKg)} kg',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        StatCard(
          warm: true,
          hero: true,
          icon: Icons.bakery_dining_outlined,
          label: 'Tahmini adet',
          value: NumberFormatter.integer(result.estimatedPieces),
          accent: AppColors.softGold,
        ),
      ],
    );
  }
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({
    required this.label,
    required this.controller,
    required this.unit,
    required this.units,
    required this.onUnitChanged,
    this.hint,
  });
  final String label;
  final TextEditingController controller;
  final _MassUnit unit;
  final List<_MassUnit> units;
  final ValueChanged<_MassUnit> onUnitChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppNumberField(
            label: label,
            controller: controller,
            suffix: unit.label,
            hint: hint,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.borderHairline, width: 0.6),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in units)
                GestureDetector(
                  onTap: () => onUnitChanged(o),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: o == unit
                          ? AppColors.copper.withValues(alpha: 0.30)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      o.label,
                      style: TextStyle(
                        color: o == unit
                            ? AppColors.softGold
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
