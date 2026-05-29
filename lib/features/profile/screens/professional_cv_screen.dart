// Unified Professional CV Center — profil içinde tek mesleki CV düzenleme
// merkezi. Bio + son durum (türetilmiş) + CV/çalışma geçmişi (tür + açık/gizli)
// + CV'den İş Arıyorum ilanı açma/güncelleme. Tüm hesap tipleri için çalışır
// (entry_type account_type'ı değiştirmez). Eski /worker/* route'ları korunur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../worker/models/job_seek_post.dart';
import '../../worker/models/worker_profile.dart';
import '../../worker/providers/worker_providers.dart';
import '../../worker/screens/job_seek_post_form_screen.dart';
import '../models/bakery_profile.dart';
import '../providers/profile_provider.dart';

class ProfessionalCvScreen extends ConsumerStatefulWidget {
  const ProfessionalCvScreen({super.key});

  @override
  ConsumerState<ProfessionalCvScreen> createState() =>
      _ProfessionalCvScreenState();
}

class _ProfessionalCvScreenState extends ConsumerState<ProfessionalCvScreen> {
  final _bio = TextEditingController();
  bool _bioSeeded = false;
  bool _savingBio = false;

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  /// Türetilmiş son mesleki durum (dedicated alan yok — mevcut veriden).
  String? _derivedStatus({
    required AccountType? accountType,
    required bool hasActiveJobSeek,
    required WorkerProfile? worker,
  }) {
    if (hasActiveJobSeek) return AppStrings.profileStatusSeeking;
    if (accountType == AccountType.commercial) {
      return AppStrings.profileStatusBakery;
    }
    if (accountType == AccountType.wholesaler) {
      return AppStrings.profileStatusWholesaler;
    }
    if (worker != null && !worker.isEmpty) {
      return AppStrings.profileStatusWorking;
    }
    return null;
  }

  Future<void> _saveBio(WorkerProfile? current) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() => _savingBio = true);
    try {
      final base = current ?? const WorkerProfile();
      await ref
          .read(workerRepositoryProvider)
          .upsertMyProfile(base.copyWith(bio: _bio.text.trim()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.cvBioSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingBio = false);
    }
  }

  Future<void> _openJobSeek(
    WorkerProfile? worker,
    List<JobSeekPost> myPosts,
  ) async {
    JobSeekPost? active;
    for (final p in myPosts) {
      if (p.isActive) {
        active = p;
        break;
      }
    }
    if (active?.id != null) {
      // Duplicate yok — mevcut aktif ilanı düzenlemeye git.
      context.push('${AppRoutes.jobSeek}/${active!.id}/edit');
      return;
    }
    // Yeni ilan — CV bilgilerinden prefill (kullanıcı ilana özel alanları
    // tamamlar). Manuel menü akışı ayrıca korunur.
    final prefill = JobSeekPrefill(
      professionCode: worker?.professionBadgeCode,
      cityCode: worker != null && worker.cityCodes.isNotEmpty
          ? worker.cityCodes.first
          : null,
      cityName:
          worker != null && worker.cities.isNotEmpty ? worker.cities.first : null,
      experienceYears: worker?.experienceYears,
      description: worker?.bio,
    );
    context.push(AppRoutes.jobSeekNew, extra: prefill);
  }

  @override
  Widget build(BuildContext context) {
    final workerAsync = ref.watch(myWorkerProfileProvider);
    final expAsync = ref.watch(myWorkerExperiencesProvider);
    final postsAsync = ref.watch(myJobSeekPostsProvider);
    final accountType = ref.watch(profileControllerProvider)?.accountType;

    final worker = workerAsync.asData?.value;
    // Bio controller'ı profil ilk geldiğinde tek sefer seed et.
    if (!_bioSeeded && workerAsync is AsyncData) {
      _bio.text = worker?.bio ?? '';
      _bioSeeded = true;
    }

    final myPosts = postsAsync.asData?.value ?? const <JobSeekPost>[];
    final hasActiveJobSeek = myPosts.any((p) => p.isActive);
    final status = _derivedStatus(
      accountType: accountType,
      hasActiveJobSeek: hasActiveJobSeek,
      worker: worker,
    );

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.cvCenterTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.l,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              AppStrings.cvCenterIntro,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // ── Son durum ──
            if (status != null) ...[
              _Label(AppStrings.cvStatusLabel),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.copper.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.copper.withValues(alpha: 0.34),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: AppColors.copper,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
            ],

            // ── Kısa tanıtım (bio) ──
            _Label(AppStrings.cvBioLabel),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _bio,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: AppStrings.cvBioHint,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppPrimaryButton(
              label: _savingBio ? 'Kaydediliyor…' : AppStrings.cvBioSaveCta,
              icon: Icons.check_rounded,
              onPressed: _savingBio ? null : () => _saveBio(worker),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── CV / Çalışma geçmişi ──
            Row(
              children: [
                Expanded(child: _Label(AppStrings.cvRecordsLabel)),
                TextButton.icon(
                  onPressed: () => _openAddSheet(context),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(AppStrings.cvAddRecordCta),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.softGold,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            expAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.l),
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 1.6)),
              ),
              error: (e, _) => Text('Okunamadı: $e',
                  style: const TextStyle(color: AppColors.danger)),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.s),
                    child: Text(
                      AppStrings.cvEmptyRecords,
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final e in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s),
                        child: _CvRecordCard(record: e),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── CV'den İş Arıyorum ──
            AppPrimaryButton(
              label: hasActiveJobSeek
                  ? AppStrings.cvUpdateJobSeekCta
                  : AppStrings.cvOpenJobSeekCta,
              icon: Icons.campaign_outlined,
              onPressed: () => _openJobSeek(worker, myPosts),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _AddCvRecordSheet(),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.softGold,
        fontWeight: FontWeight.w800,
        fontSize: 11.5,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _CvRecordCard extends ConsumerWidget {
  const _CvRecordCard({required this.record});
  final WorkerExperience record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('MMM yyyy', 'tr_TR');
    final range = [
      if (record.startDate != null) df.format(record.startDate!),
      if (record.endDate != null)
        df.format(record.endDate!)
      else if (record.startDate != null)
        'devam',
    ].join(' — ');
    final typeLabel =
        AppStrings.cvEntryTypeLabels[record.entryType] ?? record.entryType;

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              // Görünürlük toggle
              IconButton(
                tooltip: record.isPublic
                    ? AppStrings.cvVisibilityPublic
                    : AppStrings.cvVisibilityHidden,
                visualDensity: VisualDensity.compact,
                onPressed: () => runGuardedMutation(
                  context,
                  ref,
                  action: () async {
                    await ref
                        .read(workerRepositoryProvider)
                        .setExperienceVisibility(
                            record.id!, !record.isPublic);
                  },
                ),
                icon: Icon(
                  record.isPublic
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: record.isPublic
                      ? AppColors.softGold
                      : AppColors.textMuted,
                ),
              ),
              IconButton(
                tooltip: 'Kaldır',
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.textMuted, size: 18),
              ),
            ],
          ),
          if ((record.workplace ?? '').isNotEmpty)
            Text(
              record.workplace!,
              style: const TextStyle(
                color: AppColors.softGold,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Pill(label: typeLabel),
              if (!record.isPublic)
                const _Pill(label: AppStrings.cvVisibilityHidden, muted: true),
              if (range.isNotEmpty || (record.city ?? '').isNotEmpty)
                Text(
                  [if (range.isNotEmpty) range, if (record.city != null) record.city!]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if ((record.description ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              record.description!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CV kaydını kaldır'),
        content: Text('"${record.title}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || record.id == null) return;
    if (!context.mounted) return;
    await runGuardedMutation(
      context,
      ref,
      action: () async {
        await ref.read(workerRepositoryProvider).deleteExperience(record.id!);
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.muted = false});
  final String label;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: muted ? AppColors.textMuted : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _AddCvRecordSheet extends ConsumerStatefulWidget {
  const _AddCvRecordSheet();
  @override
  ConsumerState<_AddCvRecordSheet> createState() => _AddCvRecordSheetState();
}

class _AddCvRecordSheetState extends ConsumerState<_AddCvRecordSheet> {
  final _title = TextEditingController();
  final _workplace = TextEditingController();
  final _description = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  TurkeyProvince? _province;
  String _entryType = 'individual';
  bool _isPublic = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _workplace.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? (_start ?? now) : (_end ?? now),
      firstDate: DateTime(1980),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => start ? _start = picked : _end = picked);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık / rol boş olamaz.')),
      );
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(workerRepositoryProvider).addExperience(WorkerExperience(
            title: _title.text.trim(),
            workplace:
                _workplace.text.trim().isEmpty ? null : _workplace.text.trim(),
            city: _province?.name,
            cityCode: _province?.code,
            startDate: _start,
            endDate: _end,
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            entryType: _entryType,
            isPublic: _isPublic,
          ));
      if (!mounted) return;
      Navigator.of(context).pop();
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
    final df = DateFormat('MMM yyyy', 'tr_TR');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                AppStrings.cvAddRecordCta,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Başlık / rol',
                  hintText: 'Taş Fırın Ustası',
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              TextField(
                controller: _workplace,
                decoration: const InputDecoration(
                  labelText: 'Kurum / işletme (opsiyonel)',
                  hintText: 'Konak Fırını',
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              const Text(
                AppStrings.cvEntryTypeLabel,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in AppStrings.cvEntryTypeLabels.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _entryType == entry.key,
                      onSelected: (_) =>
                          setState(() => _entryType = entry.key),
                      selectedColor: AppColors.copper.withValues(alpha: 0.22),
                      backgroundColor: AppColors.card,
                      labelStyle: TextStyle(
                        color: _entryType == entry.key
                            ? AppColors.softGold
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              LocationPickerField(
                label: 'Şehir',
                value: _province?.name,
                hint: 'İl seç',
                enabled: !_saving,
                onTap: () async {
                  final picked = await LocationPicker.showProvincePicker(
                    context,
                    initialCode: _province?.code,
                  );
                  if (picked != null) setState(() => _province = picked);
                },
                onClear:
                    _province == null ? null : () => setState(() => _province = null),
              ),
              const SizedBox(height: AppSpacing.s),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(start: true),
                      child:
                          Text(_start == null ? 'Başlangıç' : df.format(_start!)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(start: false),
                      child: Text(
                          _end == null ? 'Bitiş (boşsa: devam)' : df.format(_end!)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (opsiyonel)',
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                activeThumbColor: AppColors.success,
                title: Text(
                  _isPublic
                      ? AppStrings.cvVisibilityPublic
                      : AppStrings.cvVisibilityHidden,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              AppPrimaryButton(
                label: _saving ? 'Kaydediliyor…' : 'CV kaydını kaydet',
                icon: Icons.check_rounded,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
