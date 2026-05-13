import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/worker_profile.dart';
import '../providers/worker_providers.dart';

/// Tecrübe / Çalışma Geçmişi — bireysel ustanın iş geçmişi kalemleri.
class WorkerExperiencesScreen extends ConsumerWidget {
  const WorkerExperiencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myWorkerExperiencesProvider);

    return PremiumScaffold(
      appBar: AppBar(title: const Text('Çalışma Geçmişim')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tecrübe ekle'),
        backgroundColor: AppColors.copper,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: async.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Text('Okunamadı: $e',
                style: const TextStyle(color: AppColors.danger)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _EmptyState(onAdd: () => _openAddSheet(context, ref));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.l,
                AppSpacing.pageH,
                AppSpacing.xxl + 40,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.s),
              itemBuilder: (_, i) =>
                  _ExperienceCard(experience: items[i]),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _AddExperienceSheet(),
    );
  }
}

class _ExperienceCard extends ConsumerWidget {
  const _ExperienceCard({required this.experience});
  final WorkerExperience experience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('MMM yyyy', 'tr_TR');
    final range = [
      if (experience.startDate != null) df.format(experience.startDate!),
      if (experience.endDate != null) df.format(experience.endDate!) else if (experience.startDate != null) 'devam',
    ].join(' — ');

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  experience.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Kaldır',
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.textMuted, size: 18),
              ),
            ],
          ),
          if (experience.workplace != null && experience.workplace!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                experience.workplace!,
                style: const TextStyle(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            [if (range.isNotEmpty) range, if (experience.city != null) experience.city!]
                .where((s) => s.isNotEmpty)
                .join(' · '),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          if (experience.description != null &&
              experience.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              experience.description!,
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
        title: const Text('Tecrübe kaldır'),
        content: Text('"${experience.title}" silinsin mi?'),
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
    if (ok != true || experience.id == null) return;
    await ref.read(workerRepositoryProvider).deleteExperience(experience.id!);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.xl,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.softGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  child: const Icon(
                    Icons.history_edu_outlined,
                    color: AppColors.softGold,
                    size: 22,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                const Text(
                  'Henüz tecrübe eklenmedi',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Önceki iş yerlerini ekledikçe sektör seni gözünde canlandırır.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          AppPrimaryButton(
            label: 'İlk tecrübeni ekle',
            icon: Icons.add_rounded,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _AddExperienceSheet extends ConsumerStatefulWidget {
  const _AddExperienceSheet();

  @override
  ConsumerState<_AddExperienceSheet> createState() => _AddExperienceSheetState();
}

class _AddExperienceSheetState extends ConsumerState<_AddExperienceSheet> {
  final _title = TextEditingController();
  final _workplace = TextEditingController();
  final _city = TextEditingController();
  final _description = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _workplace.dispose();
    _city.dispose();
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
      setState(() {
        if (start) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pozisyon adı boş olamaz.')),
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
            workplace: _workplace.text.trim().isEmpty
                ? null
                : _workplace.text.trim(),
            city: _city.text.trim().isEmpty ? null : _city.text.trim(),
            startDate: _start,
            endDate: _end,
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
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
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppColors.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Tecrübe ekle',
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
                  labelText: 'Pozisyon / unvan',
                  hintText: 'Taş Fırın Ustası',
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              TextField(
                controller: _workplace,
                decoration: const InputDecoration(
                  labelText: 'İş yeri',
                  hintText: 'Konak Fırını',
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              TextField(
                controller: _city,
                decoration: const InputDecoration(
                  labelText: 'Şehir',
                  hintText: 'İstanbul · Kadıköy',
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(start: true),
                      child: Text(
                          _start == null ? 'Başlangıç' : df.format(_start!)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(start: false),
                      child: Text(_end == null
                          ? 'Bitiş (boşsa: devam)'
                          : df.format(_end!)),
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
              const SizedBox(height: AppSpacing.l),
              AppPrimaryButton(
                label: _saving ? 'Kaydediliyor…' : 'Tecrübeyi Kaydet',
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
