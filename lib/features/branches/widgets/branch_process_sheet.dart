import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/branch_models.dart';
import '../providers/branch_providers.dart';

/// Yeni süreç ekleme bottom sheet'i.
///
/// [allowedTypes] çağıran yüzey belirler: patron tüm tipler, personel yalnız
/// izinli tipleri (UX filtresi — asıl izin denetimi server RPC'sindedir;
/// izinsiz deneme yine nötr hatayla döner).
/// V2: [initialType]/[initialTitle] şablondan hızlı oluşturma için ön
/// doldurur — kullanıcı düzenleyebilir (şablon dayatmaz, başlatır).
Future<void> showBranchProcessSheet(
  BuildContext context,
  WidgetRef ref, {
  required String branchId,
  required List<BranchProcessType> allowedTypes,
  BranchProcessType? initialType,
  String initialTitle = '',
}) {
  if (allowedTypes.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _ProcessSheet(
        branchId: branchId,
        allowedTypes: allowedTypes,
        initialType: initialType,
        initialTitle: initialTitle,
      ),
    ),
  );
}

class _ProcessSheet extends ConsumerStatefulWidget {
  const _ProcessSheet({
    required this.branchId,
    required this.allowedTypes,
    this.initialType,
    this.initialTitle = '',
  });

  final String branchId;
  final List<BranchProcessType> allowedTypes;
  final BranchProcessType? initialType;
  final String initialTitle;

  @override
  ConsumerState<_ProcessSheet> createState() => _ProcessSheetState();
}

class _ProcessSheetState extends ConsumerState<_ProcessSheet> {
  late final _title = TextEditingController(text: widget.initialTitle);
  final _note = TextEditingController();
  late BranchProcessType _type =
      widget.allowedTypes.contains(widget.initialType)
      ? widget.initialType!
      : widget.allowedTypes.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = AppStrings.branchProcessTitleRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(branchRepositoryProvider)
          .createProcess(
            branchId: widget.branchId,
            type: _type,
            title: _title.text,
            note: _note.text,
          );
      if (mounted) Navigator.of(context).pop();
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
        _error = 'Süreç eklenemedi. Tekrar dene.';
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
              AppStrings.branchProcessFormTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.m),
            const Text(
              AppStrings.branchProcessFormTypeField,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in widget.allowedTypes)
                  ChoiceChip(
                    key: ValueKey('process_type_${t.persistKey}'),
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedColor: AppColors.brandLemonPale,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: AppStrings.branchProcessFormTitleField,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: AppStrings.branchProcessFormNoteField,
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
                key: const ValueKey('process_sheet_save'),
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
                  _saving ? 'Kaydediliyor…' : AppStrings.branchProcessAddCta,
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
