import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/stat_card.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../data/recipe_products.dart';
import '../models/recipe_metadata.dart';
import '../models/recipe_quantities.dart';
import '../models/recipe.dart' show RecipeResult;
import '../models/recipe_record.dart';
import '../providers/bakery_providers.dart';

/// Reçete oluşturma & düzenleme sihirbazı (V1.1).
///
/// Yüzde formu kaldırıldı; kullanıcı gerçek miktar girer:
///   - Un (kg)
///   - Su (L veya kg)
///   - Maya (gr veya kg)
///   - Tuz (gr veya kg)
///   - Birim gramaj (gr)
///   - Fire/kayıp (kg, opsiyonel)
/// Ek malzemeler dinamik "+ Malzeme ekle" listesinde tutulur.
///
/// `recipeId == null` → yeni reçete. Aksi halde mevcut reçeteyi yükler.
class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({super.key, this.recipeId});
  final String? recipeId;

  @override
  ConsumerState<RecipeEditorScreen> createState() =>
      _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  // Ürün
  String? _selectedProduct;
  final _customProduct = TextEditingController();

  // Temel bilgiler
  final _title = TextEditingController();
  final _description = TextEditingController();

  // Gerçek miktar alanları
  final _flour = TextEditingController(text: '50');
  final _water = TextEditingController(text: '30');
  final _yeast = TextEditingController(text: '500');
  final _salt = TextEditingController(text: '1');
  final _piece = TextEditingController(text: '250');
  final _waste = TextEditingController();

  // Birimler
  _MassUnit _waterUnit = _MassUnit.l;
  _MassUnit _yeastUnit = _MassUnit.gr;
  _MassUnit _saltUnit = _MassUnit.kg;
  _MassUnit _wasteUnit = _MassUnit.kg;

  // Pişirme
  final _tempC = TextEditingController();
  final _bakeDuration = TextEditingController();
  final _proofMin = TextEditingController();

  // Notlar
  final _notes = TextEditingController();

  // Malzemeler & adımlar
  final List<_IngredientCtrl> _ingredients = <_IngredientCtrl>[];
  final List<_StepCtrl> _steps = <_StepCtrl>[];

  // Görünürlük
  bool _isPublic = false;

  RecipeResult? _previewResult;
  bool _loading = false;
  bool _saving = false;
  Recipe? _existing;

  @override
  void initState() {
    super.initState();
    _recalculate();
    if (widget.recipeId != null) _loadExisting(widget.recipeId!);
  }

  Future<void> _loadExisting(String id) async {
    setState(() => _loading = true);
    final repo = ref.read(recipeRepositoryProvider);
    final r = await repo.getById(id);
    if (!mounted) return;
    if (r == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reçete bulunamadı.')),
      );
      Navigator.of(context).pop();
      return;
    }
    _existing = r;
    final isStandard = standardRecipeProducts.contains(r.productName);
    _selectedProduct = isStandard ? r.productName : null;
    if (!isStandard) _customProduct.text = r.productName;
    _title.text = r.metadata.title ?? '';
    _description.text = r.metadata.description ?? '';

    _flour.text = NumberFormatter.decimal(r.quantities.flourKg);
    _waterUnit = _MassUnit.l;
    _water.text = NumberFormatter.decimal(_fromKg(r.quantities.waterKg, _waterUnit));
    // Maya: 1 kg altıysa gr, üstüyse kg.
    _yeastUnit = r.quantities.yeastKg < 1 ? _MassUnit.gr : _MassUnit.kg;
    _yeast.text = NumberFormatter.decimal(_fromKg(r.quantities.yeastKg, _yeastUnit));
    _saltUnit = r.quantities.saltKg < 1 ? _MassUnit.gr : _MassUnit.kg;
    _salt.text = NumberFormatter.decimal(_fromKg(r.quantities.saltKg, _saltUnit));
    _piece.text = NumberFormatter.decimal(r.quantities.pieceWeightG);
    if (r.quantities.wasteKg > 0) {
      _wasteUnit = r.quantities.wasteKg < 1 ? _MassUnit.gr : _MassUnit.kg;
      _waste.text =
          NumberFormatter.decimal(_fromKg(r.quantities.wasteKg, _wasteUnit));
    } else {
      _waste.text = '';
    }
    _tempC.text = r.metadata.bake.tempC != null
        ? NumberFormatter.decimal(r.metadata.bake.tempC!)
        : '';
    _bakeDuration.text = r.metadata.bake.durationMin?.toString() ?? '';
    _proofMin.text = r.metadata.bake.proofMin?.toString() ?? '';
    _notes.text = r.metadata.notes ?? '';
    _ingredients.clear();
    for (final ing in r.metadata.ingredients) {
      _ingredients.add(_IngredientCtrl.fromModel(ing));
    }
    _steps.clear();
    for (final s in r.metadata.steps) {
      _steps.add(_StepCtrl.fromModel(s));
    }
    _isPublic = r.isPublic;
    setState(() => _loading = false);
    _recalculate();
  }

  @override
  void dispose() {
    _customProduct.dispose();
    _title.dispose();
    _description.dispose();
    _flour.dispose();
    _water.dispose();
    _yeast.dispose();
    _salt.dispose();
    _piece.dispose();
    _waste.dispose();
    _tempC.dispose();
    _bakeDuration.dispose();
    _proofMin.dispose();
    _notes.dispose();
    for (final c in _ingredients) {
      c.dispose();
    }
    for (final c in _steps) {
      c.dispose();
    }
    super.dispose();
  }

  /// Kullanıcı girişini kg'a normalize edip [RecipeQuantities] üretir.
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

  /// Editor'da görüntülenen ham extras (kg/L/gr/adet, hepsi serbest).
  List<RecipeIngredient> _readIngredients() {
    final out = <RecipeIngredient>[];
    for (final c in _ingredients) {
      final name = c.name.text.trim();
      if (name.isEmpty) continue;
      final amount = NumberFormatter.parseLoose(c.amount.text);
      final unit = c.unit.text.trim();
      out.add(RecipeIngredient(
        name: name,
        amount: amount,
        unit: unit.isEmpty ? 'kg' : unit,
        note: c.note.text.trim().isEmpty ? null : c.note.text.trim(),
      ));
    }
    return out;
  }

  void _recalculate() {
    final calc = ref.read(recipeCalculatorProvider);
    setState(() {
      _previewResult = calc.calculateFromQuantities(
        _readQuantities(),
        extras: _readIngredients(),
      );
    });
  }

  String _resolveProductName() {
    if (_selectedProduct != null && _selectedProduct!.isNotEmpty) {
      return _selectedProduct!;
    }
    final custom = _customProduct.text.trim();
    if (custom.isNotEmpty) return custom;
    return '';
  }

  Future<void> _save() async {
    final q = _readQuantities();
    final productName = _resolveProductName();

    // Validasyon — brief'teki kurallar
    if (q.flourKg <= 0) {
      _err('Un miktarı sıfırdan büyük olmalı.');
      return;
    }
    if (q.pieceWeightG <= 0) {
      _err('Birim gramaj sıfırdan büyük olmalı.');
      return;
    }
    if (q.waterKg < 0 ||
        q.yeastKg < 0 ||
        q.saltKg < 0 ||
        q.wasteKg < 0) {
      _err('Miktarlar negatif olamaz.');
      return;
    }

    final cleanIngredients = _readIngredients();
    final cleanSteps = <RecipeStep>[];
    var order = 1;
    for (final c in _steps) {
      final text = c.text.text.trim();
      if (text.isEmpty) continue;
      final dur = c.duration.text.trim().isEmpty
          ? null
          : int.tryParse(c.duration.text.trim());
      cleanSteps.add(RecipeStep(order: order, text: text, durationMin: dur));
      order++;
    }

    final bake = RecipeBakeInfo(
      tempC: _tempC.text.trim().isEmpty
          ? null
          : NumberFormatter.parseLoose(_tempC.text),
      durationMin: _bakeDuration.text.trim().isEmpty
          ? null
          : int.tryParse(_bakeDuration.text.trim()),
      proofMin: _proofMin.text.trim().isEmpty
          ? null
          : int.tryParse(_proofMin.text.trim()),
    );

    final metadata = RecipeMetadata(
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      ingredients: cleanIngredients,
      steps: cleanSteps,
      bake: bake,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      mediaHints: _existing?.metadata.mediaHints ?? const <String>[],
    );

    // V1.3.1 — guest kullanıcı reçete kaydedemez; AuthRequired sheet açılır.
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }

    final user = ref.read(currentAuthUserProvider);
    final draft = Recipe(
      id: _existing?.id ?? '',
      ownerId: _existing?.ownerId ?? user?.id ?? 'local',
      productName: productName.isEmpty ? 'Genel reçete' : productName,
      quantities: q,
      result: _previewResult ??
          const RecipeResult(
            waterLiters: 0,
            yeastKg: 0,
            saltKg: 0,
            totalDoughKg: 0,
            doughAfterWasteKg: 0,
            estimatedPieces: 0,
          ),
      metadata: metadata,
      createdAt: _existing?.createdAt ?? DateTime.now(),
      visibility:
          _isPublic ? RecipeVisibility.public : RecipeVisibility.private,
      publishedAt: _existing?.publishedAt,
    );

    setState(() => _saving = true);
    try {
      final repo = ref.read(recipeRepositoryProvider);
      final saved = await repo.save(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _existing == null
                ? 'Reçete kaydedildi: ${saved.displayTitle}'
                : 'Reçete güncellendi: ${saved.displayTitle}',
          ),
        ),
      );
      if (_existing == null) {
        context.pushReplacement('${AppRoutes.recipes}/${saved.id}');
      } else {
        context.pop();
      }
    } on GuestActionRequiredException {
      // V1.4 P1.6 — Defense-in-depth: pre-check (canWriteWithRef line 282)
      // sonrası repo katmanı yine guest exception atarsa sessizce yutmayalım;
      // ham mesaj yerine auth sheet aç.
      if (!mounted) return;
      await showAuthRequiredSheet(context, ref);
    } catch (_) {
      // V1.4 P1.6 — Ham PostgrestException/network hatası UI'a sızmaz;
      // form alanları korunur (setState reset edilmez), kullanıcı tek tıkla
      // tekrar deneyebilir.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.recipeSaveError)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PremiumScaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
      );
    }
    final isEditing = _existing != null;
    return PremiumScaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Reçeteyi Düzenle' : 'Yeni Reçete'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl + 24,
          ),
          children: [
            const _Section(label: 'ÜRÜN'),
            _ProductPicker(
              standard: standardRecipeProducts,
              selected: _selectedProduct,
              customController: _customProduct,
              onSelected: (v) {
                setState(() {
                  _selectedProduct = v;
                  if (v != null) _customProduct.clear();
                });
              },
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section(label: 'TEMEL BİLGİ'),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Reçete adı / başlık (opsiyonel)',
                hintText: 'Örn. Trabzon Ekmeği, Ramazan Pidesi',
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Kısa açıklama (opsiyonel)',
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section(label: 'HAMUR (gerçek miktar)'),
            AppNumberField(
              label: 'Un (kg)',
              controller: _flour,
              suffix: 'kg',
            ),
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
              hint: 'Boş bırakılırsa 0 sayılır',
            ),
            const SizedBox(height: AppSpacing.m),
            OutlinedButton.icon(
              onPressed: _recalculate,
              icon: const Icon(Icons.calculate_outlined, size: 18),
              label: const Text('Hesabı yenile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.softGold,
                side: BorderSide(
                  color: AppColors.copper.withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            if (_previewResult != null) ...[
              const SizedBox(height: AppSpacing.m),
              _CalcPreview(result: _previewResult!),
            ],
            const SizedBox(height: AppSpacing.l),
            const _Section(label: 'PİŞİRME'),
            Row(
              children: [
                Expanded(
                  child: AppNumberField(
                    label: 'Pişirme derecesi',
                    controller: _tempC,
                    suffix: '°C',
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: AppNumberField(
                    label: 'Pişirme süresi',
                    controller: _bakeDuration,
                    allowDecimal: false,
                    suffix: 'dk',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            AppNumberField(
              label: 'Mayalanma / dinlendirme',
              controller: _proofMin,
              allowDecimal: false,
              suffix: 'dk',
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section(label: 'MALZEMELER (ek)'),
            for (var i = 0; i < _ingredients.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: _IngredientRow(
                  ctrl: _ingredients[i],
                  onRemove: () => setState(() {
                    _ingredients[i].dispose();
                    _ingredients.removeAt(i);
                  }),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _ingredients.add(_IngredientCtrl.empty())),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Malzeme ekle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.softGold,
                side: BorderSide(
                  color: AppColors.copper.withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section(label: 'YAPILIŞI'),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: _StepRow(
                  order: i + 1,
                  ctrl: _steps[i],
                  onRemove: () => setState(() {
                    _steps[i].dispose();
                    _steps.removeAt(i);
                  }),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _steps.add(_StepCtrl.empty())),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Adım ekle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.softGold,
                side: BorderSide(
                  color: AppColors.copper.withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section(label: 'NOT'),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Not (opsiyonel)',
                hintText: 'Soğuk fermantasyon önerilir, çıtır kabuk için…',
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section(label: 'GÖRÜNÜRLÜK'),
            _VisibilityToggle(
              isPublic: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section(label: 'GÖRSEL / VİDEO'),
            const _MediaPlaceholder(),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: _saving
                  ? 'Kaydediliyor…'
                  : (isEditing ? 'Güncelle' : 'Reçeteyi Kaydet'),
              icon: Icons.check_rounded,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Birim yardımcıları

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

double _fromKg(double kg, _MassUnit unit) {
  switch (unit) {
    case _MassUnit.kg:
    case _MassUnit.l:
      return kg;
    case _MassUnit.gr:
      return kg * 1000.0;
  }
}

// ─────────────────────────── Yardımcı controller'lar

class _IngredientCtrl {
  _IngredientCtrl({
    required this.name,
    required this.amount,
    required this.unit,
    required this.note,
  });

  factory _IngredientCtrl.empty() => _IngredientCtrl(
        name: TextEditingController(),
        amount: TextEditingController(),
        unit: TextEditingController(text: 'kg'),
        note: TextEditingController(),
      );

  factory _IngredientCtrl.fromModel(RecipeIngredient ing) => _IngredientCtrl(
        name: TextEditingController(text: ing.name),
        amount: TextEditingController(text: NumberFormatter.decimal(ing.amount)),
        unit: TextEditingController(text: ing.unit),
        note: TextEditingController(text: ing.note ?? ''),
      );

  final TextEditingController name;
  final TextEditingController amount;
  final TextEditingController unit;
  final TextEditingController note;

  void dispose() {
    name.dispose();
    amount.dispose();
    unit.dispose();
    note.dispose();
  }
}

class _StepCtrl {
  _StepCtrl({required this.text, required this.duration});

  factory _StepCtrl.empty() => _StepCtrl(
        text: TextEditingController(),
        duration: TextEditingController(),
      );

  factory _StepCtrl.fromModel(RecipeStep s) => _StepCtrl(
        text: TextEditingController(text: s.text),
        duration: TextEditingController(
            text: s.durationMin == null ? '' : '${s.durationMin}'),
      );

  final TextEditingController text;
  final TextEditingController duration;

  void dispose() {
    text.dispose();
    duration.dispose();
  }
}

// ─────────────────────────── UI parça widget'ları

class _Section extends StatelessWidget {
  const _Section({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpacing.s, 0, AppSpacing.s),
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
      crossAxisAlignment: CrossAxisAlignment.center,
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
        _UnitChips(
          selected: unit,
          options: units,
          onSelected: onUnitChanged,
        ),
      ],
    );
  }
}

class _UnitChips extends StatelessWidget {
  const _UnitChips({
    required this.selected,
    required this.options,
    required this.onSelected,
  });
  final _MassUnit selected;
  final List<_MassUnit> options;
  final ValueChanged<_MassUnit> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.borderHairline,
          width: 0.6,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onSelected(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: o == selected
                      ? AppColors.copper.withValues(alpha: 0.30)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  o.label,
                  style: TextStyle(
                    color: o == selected
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
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({
    required this.standard,
    required this.selected,
    required this.customController,
    required this.onSelected,
  });
  final List<String> standard;
  final String? selected;
  final TextEditingController customController;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in standard)
              ChoiceChip(
                label: Text(p),
                selected: selected == p,
                onSelected: (v) => onSelected(v ? p : null),
                selectedColor: AppColors.copper.withValues(alpha: 0.22),
                backgroundColor: AppColors.card,
                labelStyle: TextStyle(
                  color: selected == p
                      ? AppColors.softGold
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  side: BorderSide(
                    color: selected == p
                        ? AppColors.copper.withValues(alpha: 0.55)
                        : AppColors.borderHairline,
                    width: 0.6,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        TextField(
          controller: customController,
          onChanged: (_) {
            if (selected != null) onSelected(null);
          },
          decoration: const InputDecoration(
            labelText: 'Veya yeni ürün adı yaz',
            hintText: 'Örn. Trabzon Ekmeği',
          ),
        ),
      ],
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.isPublic, required this.onChanged});
  final bool isPublic;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isPublic ? AppColors.success : AppColors.textMuted)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            child: Icon(
              isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
              color: isPublic ? AppColors.success : AppColors.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPublic ? 'Profilimde görünsün' : 'Gizli',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPublic
                      ? 'Profiline girenler bu reçeteyi görebilir.'
                      : 'Sadece sen görürsün.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isPublic,
            onChanged: onChanged,
            activeThumbColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _CalcPreview extends StatelessWidget {
  const _CalcPreview({required this.result});
  final RecipeResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.water_drop_outlined,
                label: 'Su',
                value: '${NumberFormatter.decimal(result.waterLiters)} kg',
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: StatCard(
                icon: Icons.science_outlined,
                label: 'Maya',
                value: '${NumberFormatter.decimal(result.yeastKg)} kg',
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: StatCard(
                icon: Icons.grain_outlined,
                label: 'Tuz',
                value: '${NumberFormatter.decimal(result.saltKg)} kg',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
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
                label: 'Fire sonrası',
                value:
                    '${NumberFormatter.decimal(result.doughAfterWasteKg)} kg',
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: StatCard(
                warm: true,
                icon: Icons.bakery_dining_outlined,
                label: 'Tahmini adet',
                value: NumberFormatter.integer(result.estimatedPieces),
                accent: AppColors.softGold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ctrl, required this.onRemove});
  final _IngredientCtrl ctrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.s,
        AppSpacing.s,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: ctrl.name,
                  decoration: const InputDecoration(
                    labelText: 'Malzeme',
                    isDense: true,
                    hintText: 'Yağ, susam, şeker…',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: ctrl.amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Miktar',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: ctrl.unit,
                  decoration: const InputDecoration(
                    labelText: 'Birim',
                    isDense: true,
                    hintText: 'kg/L/gr',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Kaldır',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          TextField(
            controller: ctrl.note,
            decoration: const InputDecoration(
              labelText: 'Not (opsiyonel)',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.order,
    required this.ctrl,
    required this.onRemove,
  });
  final int order;
  final _StepCtrl ctrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.s,
        AppSpacing.s,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.softGold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                child: Text(
                  '$order',
                  style: const TextStyle(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: TextField(
                  controller: ctrl.text,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Adım açıklaması',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Kaldır',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: TextField(
              controller: ctrl.duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Süre (dakika, opsiyonel)',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.softGold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              color: AppColors.softGold,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          const Expanded(
            child: Text(
              'Görsel ekleme sonraki fazda aktif olacak. '
              'Şimdilik reçeteyi metin olarak paylaşabilirsin.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
