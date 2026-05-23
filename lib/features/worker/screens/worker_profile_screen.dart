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
  static List<String> get _professionCodes =>
      FirinnetTaxonomy.professionCodes;

  static const List<String> _shifts = [
    'gunduz',
    'gece',
    'vardiyali',
    'esnek',
  ];

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
  final _skills = TextEditingController();
  final _bio = TextEditingController();

  /// M6A — çalışmak istediği iller (multi-select). Önce city_codes,
  /// yoksa eski cities[] label'lardan çevirim.
  final List<TurkeyProvince> _selectedProvinces = <TurkeyProvince>[];

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
      _professionCode = p.professionBadgeCode ??
          FirinnetTaxonomy.professionCodeFromLabel(p.professionBadge);
      _shift = p.shiftPreference;
      _workType = p.workType;
      _experience.text =
          p.experienceYears != null ? '${p.experienceYears}' : '';
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
      _skills.text = p.skills.join(', ');
      _bio.text = p.bio ?? '';
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _experience.dispose();
    _salary.dispose();
    _skills.dispose();
    _bio.dispose();
    super.dispose();
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
      final cityCodes = <String>[
        for (final p in _selectedProvinces) p.code,
      ];
      final cities = <String>[
        for (final p in _selectedProvinces) p.name,
      ];
      final skills = _skills.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      // M5 — dual-write: code (yeni) + label (backward compat).
      final code = _professionCode;
      final label =
          code == null ? null : FirinnetTaxonomy.professionLabel(code);
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
        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      );
      await repo.upsertMyProfile(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ustalık bilgilerin kaydedildi.')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
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
              labelOf: (code) =>
                  FirinnetTaxonomy.professionLabel(code) ?? code,
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
            TextField(
              controller: _skills,
              decoration: const InputDecoration(
                labelText: 'Beceriler / notlar (virgülle ayır)',
                hintText: 'taş fırın, ekşi maya, pasta süsleme',
              ),
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
          const Icon(Icons.lightbulb_outline_rounded,
              color: AppColors.softGold, size: 18),
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
            selectedColor: AppColors.copper.withValues(alpha: 0.22),
            backgroundColor: AppColors.card,
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
                    ? AppColors.copper.withValues(alpha: 0.55)
                    : AppColors.borderHairline,
                width: 0.6,
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
            backgroundColor: AppColors.card,
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
              side: BorderSide(
                color: AppColors.copper.withValues(alpha: 0.55),
                width: 0.6,
              ),
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
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            side: const BorderSide(
              color: AppColors.borderHairline,
              width: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}
