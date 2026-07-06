import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../providers/bakery_providers.dart';

/// Ciro / gün notu sheet'i — upsert_bakery_day_book RPC'sine yazar.
///
/// Ciro bir GÜNLÜK NOTTUR; muhasebe/fatura/tahsilat kaydı değildir
/// (gider ve bayi finansı kendi modüllerinde). Boş bırakılan alan mevcut
/// değeri KORUR (partial upsert).
Future<void> showLedgerRevenueSheet(
  BuildContext context,
  WidgetRef ref, {
  bool focusNote = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _RevenueSheet(focusNote: focusNote),
    ),
  );
}

class _RevenueSheet extends ConsumerStatefulWidget {
  const _RevenueSheet({required this.focusNote});

  final bool focusNote;

  @override
  ConsumerState<_RevenueSheet> createState() => _RevenueSheetState();
}

class _RevenueSheetState extends ConsumerState<_RevenueSheet> {
  final _revenue = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _revenue.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final revenueText = _revenue.text.trim();
    final noteText = _note.text.trim();
    final revenue = revenueText.isEmpty
        ? null
        : NumberFormatter.parseLoose(revenueText);
    if (revenue == null && noteText.isEmpty) {
      setState(() => _error = 'Ciro veya not gir.');
      return;
    }
    if (revenue != null && revenue < 0) {
      setState(() => _error = 'Ciro negatif olamaz.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(bakeryRepositoryProvider)
          .upsertDayBook(
            day: DateTime.now(),
            revenue: revenue,
            dayNote: noteText.isEmpty ? null : noteText,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.ledgerSaved)));
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Kayıt yapılamadı. Tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          0,
          AppSpacing.pageH,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.ledgerRevenueSheetTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            const Text(
              AppStrings.ledgerRevenueHint,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            AppNumberField(
              label: AppStrings.ledgerRevenueField,
              controller: _revenue,
              suffix: '₺',
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              key: const ValueKey('ledger_day_note_field'),
              controller: _note,
              autofocus: widget.focusNote,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: AppStrings.ledgerDayNoteField,
                hintText: 'Bugün nasıl geçti, yarına not…',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('ledger_revenue_save'),
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandLemon,
                  foregroundColor: AppColors.brandInk,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
                child: Text(
                  _saving ? 'Kaydediliyor…' : 'Kaydet',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hızlı iş ekleme sheet'i — create_bakery_task RPC'sine yazar.
Future<void> showLedgerTaskSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: const _TaskSheet(),
    ),
  );
}

class _TaskSheet extends ConsumerStatefulWidget {
  const _TaskSheet();

  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  final _title = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Görev başlığını yaz.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(bakeryRepositoryProvider)
          .addTask(day: DateTime.now(), title: _title.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.ledgerTaskAdded)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Görev eklenemedi. Tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          0,
          AppSpacing.pageH,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.ledgerQuickTask,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              key: const ValueKey('ledger_task_title_field'),
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: AppStrings.ledgerTaskAddHint,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('ledger_task_save'),
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandLemon,
                  foregroundColor: AppColors.brandInk,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
                child: Text(
                  _saving ? 'Kaydediliyor…' : 'Ekle',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
