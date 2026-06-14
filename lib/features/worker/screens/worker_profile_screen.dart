import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/data/firinnet_taxonomy.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/worker_profile.dart';
import '../providers/worker_providers.dart';

/// Ustalık Bilgilerim — bireysel kullanıcının profesyonel kartı.
///
/// Kullanıcı başına tek kayıt (`worker_profiles.owner_id` unique). Kaydet
/// dokunulunca upsert.
class WorkerProfileScreen extends ConsumerStatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  ConsumerState<WorkerProfileScreen> createState() =>
      _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends ConsumerState<WorkerProfileScreen> {
  // M5 Data Foundation — meslek listesi ortak taxonomy'den; hardcoded
  // liste kaldırıldı. UI label gösterir, save'de code yazılır.
  static List<String> get _professionCodes => FirinnetTaxonomy.professionCodes;

  static const List<String> _shifts = ['gunduz', 'gece', 'vardiyali', 'esnek'];

  static String _shiftLabel(String key) {
    switch (key) {
      case 'gunduz':
        return 'Gündüz';
      case 'gece':
        return 'Gece';
      case 'vardiyali':
        return 'Vardiyalı';
      case 'esnek':
        return 'Esnek';
      default:
        return key;
    }
  }

  static const List<String> _workTypes = [
    'tam_zamanli',
    'part_time',
    'sezonluk',
  ];

  static String _workTypeLabel(String key) {
    switch (key) {
      case 'tam_zamanli':
        return 'Tam zamanlı';
      case 'part_time':
        return 'Part-time';
      case 'sezonluk':
        return 'Sezonluk';
      default:
        return key;
    }
  }

  /// M5 — taxonomy code (`usta_firinci`, `mayaci`, ...). UI label render eder.
  String? _professionCode;
  String? _shift;
  String? _workType;

  final _experience = TextEditingController();
  final _salary = TextEditingController();
  final _bio = TextEditingController();

  /// M6A — çalışmak istediği iller (multi-select). Önce city_codes,
  /// yoksa eski cities[] label'lardan çevirim.
  final List<TurkeyProvince> _selectedProvinces = <TurkeyProvince>[];

  /// M7 — beceriler (multi-select taxonomy code'ları). UI label render eder;
  /// save'de skill_codes + skills dual-write.
  final List<String> _selectedSkillCodes = <String>[];

  /// M7 — taxonomy cap (DB CHECK ile aynı).
  static const int _maxSkillSelection = 10;

  bool _loading = true;
  bool _saving = false;
  WorkerProfile? _initial;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(workerRepositoryProvider);
    final p = await repo.getMyProfile();
    if (!mounted) return;
    if (p != null) {
      _initial = p;
      // M5 — code öncelikli; yoksa eski label'dan code'a çevir (legacy hydrate).
      _professionCode =
          p.professionBadgeCode ??
          FirinnetTaxonomy.professionCodeFromLabel(p.professionBadge);
      _shift = p.shiftPreference;
      _workType = p.workType;
      _experience.text = p.experienceYears != null
          ? '${p.experienceYears}'
          : '';
      _salary.text = p.salaryExpectation != null
          ? p.salaryExpectation!.toStringAsFixed(0)
          : '';
      // M6A — city_codes öncelikli, yoksa cities (label) → code çevirim.
      _selectedProvinces.clear();
      final seen = <String>{};
      for (final c in p.cityCodes) {
        final prov = TurkeyLocations.findProvinceByCode(c);
        if (prov != null && seen.add(prov.code)) {
          _selectedProvinces.add(prov);
        }
      }
      for (final name in p.cities) {
        final prov = TurkeyLocations.findProvinceByName(name);
        if (prov != null && seen.add(prov.code)) {
          _selectedProvinces.add(prov);
        }
      }
      // M7 — skill_codes öncelikli; yoksa eski skills (label) → code çevirim.
      _selectedSkillCodes.clear();
      final skillSeen = <String>{};
      for (final c in p.skillCodes) {
        if (FirinnetTaxonomy.isValidWorkerSkillCode(c) && skillSeen.add(c)) {
          _selectedSkillCodes.add(c);
        }
      }
      for (final label in p.skills) {
        final code = FirinnetTaxonomy.workerSkillCodeFromLabel(label);
        if (code != null && skillSeen.add(code)) {
          _selectedSkillCodes.add(code);
        }
      }
      _bio.text = p.bio ?? '';
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _experience.dispose();
    _salary.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _openSkillPicker() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _SkillPickerSheet(
        initialSelected: List<String>.from(_selectedSkillCodes),
        maxSelection: _maxSkillSelection,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedSkillCodes
          ..clear()
          ..addAll(result);
      });
    }
  }

  void _removeSkill(String code) {
    setState(() => _selectedSkillCodes.remove(code));
  }

  Future<void> _addProvince() async {
    final picked = await LocationPicker.showProvincePicker(context);
    if (picked == null) return;
    if (_selectedProvinces.any((p) => p.code == picked.code)) return;
    setState(() => _selectedProvinces.add(picked));
  }

  void _removeProvince(TurkeyProvince p) {
    setState(() => _selectedProvinces.removeWhere((x) => x.code == p.code));
  }

  Future<void> _save() async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(workerRepositoryProvider);
      // M6A — dual-write: city_codes (taxonomy) + cities (label fallback).
      final cityCodes = <String>[for (final p in _selectedProvinces) p.code];
      final cities = <String>[for (final p in _selectedProvinces) p.name];
      // M7 — dual-write: skill_codes (taxonomy) + skills (label fallback).
      final skillCodes = List<String>.from(_selectedSkillCodes);
      final skills = <String>[
        for (final c in skillCodes) FirinnetTaxonomy.workerSkillLabel(c) ?? c,
      ];
      // M5 — dual-write: code (yeni) + label (backward compat).
      final code = _professionCode;
      final label = code == null
          ? null
          : FirinnetTaxonomy.professionLabel(code);
      final draft = WorkerProfile(
        id: _initial?.id,
        ownerId: _initial?.ownerId,
        professionBadge: label,
        professionBadgeCode: code,
        experienceYears: _experience.text.trim().isEmpty
            ? null
            : int.tryParse(_experience.text.trim()),
        cities: cities,
        cityCodes: cityCodes,
        shiftPreference: _shift,
        salaryExpectation: _salary.text.trim().isEmpty
            ? null
            : NumberFormatter.parseLoose(_salary.text),
        workType: _workType,
        skills: skills,
        skillCodes: skillCodes,
        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      );
      await repo.upsertMyProfile(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ustalık bilgilerin kaydedildi.')),
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilemedi. Lütfen tekrar dene.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PremiumScaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
      );
    }
    return PremiumScaffold(
      appBar: AppBar(title: const Text('Ustalık Bilgilerim')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            const _Hint(
              text:
                  'Sektör seni bulabilsin. Bilgiler profilinin Açık Reçeteler '
                  'altındaki ustalık kartında görünür.',
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section('MESLEK'),
            _ChipPicker(
              // M5 — options = taxonomy code listesi; label çevirim helper'da.
              options: _professionCodes,
              labelOf: (code) => FirinnetTaxonomy.professionLabel(code) ?? code,
              selected: _professionCode,
              onChanged: (v) => setState(() => _professionCode = v),
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section('TECRÜBE & MAAŞ'),
            Row(
              children: [
                Expanded(
                  child: AppNumberField(
                    label: 'Tecrübe yılı',
                    controller: _experience,
                    suffix: 'yıl',
                    allowDecimal: false,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: AppNumberField(
                    label: 'Maaş beklentisi',
                    controller: _salary,
                    suffix: 'TL',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section('VARDİYA'),
            _ChipPicker(
              options: _shifts,
              labelOf: _shiftLabel,
              selected: _shift,
              onChanged: (v) => setState(() => _shift = v),
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section('ÇALIŞMA TİPİ'),
            _ChipPicker(
              options: _workTypes,
              labelOf: _workTypeLabel,
              selected: _workType,
              onChanged: (v) => setState(() => _workType = v),
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section('ŞEHİRLER'),
            _CitiesPicker(
              selected: _selectedProvinces,
              onAdd: _saving ? null : _addProvince,
              onRemove: _saving ? null : _removeProvince,
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section('BECERİLER'),
            _SkillsPicker(
              selectedCodes: _selectedSkillCodes,
              onAdd: _saving ? null : _openSkillPicker,
              onRemove: _saving ? null : _removeSkill,
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section('KISA AÇIKLAMA'),
            TextField(
              controller: _bio,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Kendini kısaca anlat (opsiyonel)',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: _saving ? 'Kaydediliyor…' : 'Bilgileri Kaydet',
              icon: Icons.check_rounded,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.softGold,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
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

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s, left: 2),
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

class _ChipPicker extends StatelessWidget {
  const _ChipPicker({
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });
  final List<String> options;
  final String Function(String) labelOf;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(labelOf(o)),
            selected: selected == o,
            onSelected: (v) => onChanged(v ? o : null),
            selectedColor: AppColors.copperMuted.withValues(alpha: 0.28),
            backgroundColor: Colors.transparent,
            labelStyle: TextStyle(
              color: selected == o
                  ? AppColors.softGold
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              side: BorderSide(
                color: selected == o
                    ? AppColors.copperMuted
                    : AppColors.surfaceVariant,
                width: 1,
              ),
            ),
          ),
      ],
    );
  }
}

/// M6A — çoklu il seçimi: chip cluster + "İl ekle" CTA. Her chip'in
/// üstüne tıklayınca o il kaldırılır (X icon). Boş listede sadece CTA.
class _CitiesPicker extends StatelessWidget {
  const _CitiesPicker({
    required this.selected,
    required this.onAdd,
    required this.onRemove,
  });

  final List<TurkeyProvince> selected;
  final VoidCallback? onAdd;
  final void Function(TurkeyProvince)? onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in selected)
          InputChip(
            label: Text(p.name),
            backgroundColor: AppColors.copperMuted.withValues(alpha: 0.22),
            labelStyle: const TextStyle(
              color: AppColors.softGold,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
            deleteIcon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
            onDeleted: onRemove == null ? null : () => onRemove!(p),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              side: BorderSide(color: AppColors.copperMuted, width: 1),
            ),
          ),
        ActionChip(
          avatar: const Icon(
            Icons.add_rounded,
            size: 16,
            color: AppColors.softGold,
          ),
          label: const Text(
            'İl ekle',
            style: TextStyle(
              color: AppColors.softGold,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          onPressed: onAdd,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            side: const BorderSide(color: AppColors.surfaceVariant, width: 1),
          ),
        ),
      ],
    );
  }
}

/// M7 — beceri chip listesi + "Beceri ekle/değiştir" CTA. Boş listede
/// sadece CTA; her chip'te X delete.
class _SkillsPicker extends StatelessWidget {
  const _SkillsPicker({
    required this.selectedCodes,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> selectedCodes;
  final VoidCallback? onAdd;
  final void Function(String)? onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final code in selectedCodes)
          InputChip(
            label: Text(FirinnetTaxonomy.workerSkillLabel(code) ?? code),
            backgroundColor: AppColors.copperMuted.withValues(alpha: 0.22),
            labelStyle: const TextStyle(
              color: AppColors.softGold,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
            deleteIcon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
            onDeleted: onRemove == null ? null : () => onRemove!(code),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              side: BorderSide(color: AppColors.copperMuted, width: 1),
            ),
          ),
        ActionChip(
          avatar: const Icon(
            Icons.add_rounded,
            size: 16,
            color: AppColors.softGold,
          ),
          label: Text(
            selectedCodes.isEmpty ? 'Beceri ekle' : 'Beceri değiştir',
            style: const TextStyle(
              color: AppColors.softGold,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          onPressed: onAdd,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            side: const BorderSide(color: AppColors.surfaceVariant, width: 1),
          ),
        ),
      ],
    );
  }
}

/// M7 — bottom sheet: 14 entry skill chip multi-select; cap'i geçince
/// uyarı snackbar. Onayla / Vazgeç ile kapanır.
class _SkillPickerSheet extends StatefulWidget {
  const _SkillPickerSheet({
    required this.initialSelected,
    required this.maxSelection,
  });

  final List<String> initialSelected;
  final int maxSelection;

  @override
  State<_SkillPickerSheet> createState() => _SkillPickerSheetState();
}

class _SkillPickerSheetState extends State<_SkillPickerSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = <String>{...widget.initialSelected};
  }

  void _toggle(String code) {
    setState(() {
      if (_selected.contains(code)) {
        _selected.remove(code);
      } else {
        if (_selected.length >= widget.maxSelection) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'En fazla ${widget.maxSelection} beceri seçebilirsin.',
              ),
            ),
          );
          return;
        }
        _selected.add(code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.m),
                  decoration: BoxDecoration(
                    color: AppColors.borderHairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Beceriler',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Birden fazla seçebilirsin (en fazla ${widget.maxSelection}).',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in FirinnetTaxonomy.workerSkillEntries)
                    FilterChip(
                      label: Text(e.value),
                      selected: _selected.contains(e.key),
                      onSelected: (_) => _toggle(e.key),
                      selectedColor: AppColors.copperMuted.withValues(
                        alpha: 0.28,
                      ),
                      backgroundColor: Colors.transparent,
                      labelStyle: TextStyle(
                        color: _selected.contains(e.key)
                            ? AppColors.softGold
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        side: BorderSide(
                          color: _selected.contains(e.key)
                              ? AppColors.copperMuted
                              : AppColors.surfaceVariant,
                          width: 1,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_selected.toList()),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    'Onayla (${_selected.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.copper,
                    foregroundColor: AppColors.brandInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
