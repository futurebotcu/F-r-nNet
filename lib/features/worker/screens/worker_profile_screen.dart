import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
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
  static const List<String> _professions = [
    'Usta Fırıncı',
    'Mayacı',
    'Hamurcu',
    'Simitçi',
    'Poğaçacı',
    'Pasta Ustası',
    'Çırak',
    'Kalfa',
    'Pideci',
  ];

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

  String? _profession;
  String? _shift;
  String? _workType;

  final _experience = TextEditingController();
  final _salary = TextEditingController();
  final _cities = TextEditingController();
  final _skills = TextEditingController();
  final _bio = TextEditingController();

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
      _profession = p.professionBadge;
      _shift = p.shiftPreference;
      _workType = p.workType;
      _experience.text =
          p.experienceYears != null ? '${p.experienceYears}' : '';
      _salary.text = p.salaryExpectation != null
          ? p.salaryExpectation!.toStringAsFixed(0)
          : '';
      _cities.text = p.cities.join(', ');
      _skills.text = p.skills.join(', ');
      _bio.text = p.bio ?? '';
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _experience.dispose();
    _salary.dispose();
    _cities.dispose();
    _skills.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(workerRepositoryProvider);
      final cities = _cities.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final skills = _skills.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final draft = WorkerProfile(
        id: _initial?.id,
        ownerId: _initial?.ownerId,
        professionBadge: _profession,
        experienceYears: _experience.text.trim().isEmpty
            ? null
            : int.tryParse(_experience.text.trim()),
        cities: cities,
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
              options: _professions,
              labelOf: (s) => s,
              selected: _profession,
              onChanged: (v) => setState(() => _profession = v),
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
            TextField(
              controller: _cities,
              decoration: const InputDecoration(
                labelText: 'Çalışabileceğin şehirler (virgülle ayır)',
                hintText: 'Konya, Manisa, İzmir',
              ),
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
