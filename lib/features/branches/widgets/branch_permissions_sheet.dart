import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/branch_models.dart';
import '../providers/branch_providers.dart';

/// V2 — üyelik süreç izinlerini düzenleme sheet'i (rol DEĞİŞMEZ).
///
/// Owner tüm non-manager üyelerde kullanır (şube sorumlusu zaten tüm
/// tiplere yetkili — onun için açılmaz). Asıl denetim
/// update_branch_membership_permissions RPC'sindedir.
Future<void> showBranchPermissionsSheet(
  BuildContext context, {
  required BranchMembership membership,
}) {
  if (membership.role.hasAllProcessPermissions) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _PermissionsSheet(membership: membership),
    ),
  );
}

class _PermissionsSheet extends ConsumerStatefulWidget {
  const _PermissionsSheet({required this.membership});

  final BranchMembership membership;

  @override
  ConsumerState<_PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends ConsumerState<_PermissionsSheet> {
  late final Set<BranchProcessType> _selected = {
    ...widget.membership.permissions,
  };
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(branchRepositoryProvider)
          .updateMembershipPermissions(
            widget.membership.id,
            _selected.toList(growable: false),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.branchPermissionsUpdated)),
      );
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
        _error = 'İzinler güncellenemedi. Tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.membership.memberName.isEmpty
        ? 'Personel'
        : widget.membership.memberName;
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
              AppStrings.branchPermissionsSheetTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              '$name · ${widget.membership.role.label}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final type in BranchProcessType.values)
                  FilterChip(
                    key: ValueKey('perm_edit_${type.persistKey}'),
                    label: Text(type.label),
                    selected: _selected.contains(type),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _selected.add(type);
                      } else {
                        _selected.remove(type);
                      }
                    }),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedColor: AppColors.brandLemonPale,
                    checkmarkColor: AppColors.brandInk,
                  ),
              ],
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
                key: const ValueKey('perm_edit_save'),
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
                  _saving ? 'Kaydediliyor…' : AppStrings.branchPermissionsSave,
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
