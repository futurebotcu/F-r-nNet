import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/branch_models.dart';
import '../providers/branch_providers.dart';

/// V2 — bireysel "Şube İşlerim" içinde branch_manager Sorumlu Araçları.
///
/// SINIRLI yönetim: yalnız sorumlu olunan şube; personel listesi + alt-rol
/// daveti + non-manager askı/çıkarma. Şube oluşturma/silme, işletme ayarı,
/// diğer şubeler burada HİÇ render edilmez. UI filtresi UX içindir — asıl
/// sınır RPC + RLS'tedir (manager branch_manager rolü veremez, kendi
/// üyeliğine ve diğer sorumlulara dokunamaz).
class BranchManagerTools extends ConsumerWidget {
  const BranchManagerTools({super.key, required this.membership});

  final BranchMembership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(branchMembersProvider(membership.branchId)).valueOrNull ??
        const <BranchMembership>[];
    final invites =
        ref
            .watch(branchPendingInvitesProvider(membership.branchId))
            .valueOrNull ??
        const <BranchInvite>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: AppSpacing.s),
          child: Text(
            AppStrings.myBranchManagerSection,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: AppColors.brandLemonPale,
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          child: const Text(
            AppStrings.myBranchManagerInfo,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brandInk,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        OutlinedButton.icon(
          key: const ValueKey('manager_invite_cta'),
          onPressed: () => showBranchManagerInviteSheet(
            context,
            branchId: membership.branchId,
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
          label: const Text(AppStrings.myBranchManagerInviteCta),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: AppColors.brandInk,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        if (members.isNotEmpty || invites.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: AppSpacing.xs),
            child: Text(
              AppStrings.myBranchManagerStaffSection,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ),
          for (final m in members)
            _ManagerMemberTile(member: m, selfUserId: membership.userId),
          for (final inv in invites) _ManagerInviteTile(invite: inv),
        ],
      ],
    );
  }
}

/// Personel satırı: sorumlu YALNIZ non-manager üyeleri yönetebilir; kendi
/// satırı ve diğer sorumlular salt-görünür (menü yok).
class _ManagerMemberTile extends ConsumerWidget {
  const _ManagerMemberTile({required this.member, required this.selfUserId});

  final BranchMembership member;
  final String selfUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manageable =
        member.userId != selfUserId && member.role != BranchRole.branchManager;
    final suspended = member.status == BranchMembershipStatus.suspended;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.memberName.isEmpty ? 'Personel' : member.memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${member.role.label} · ${member.status.label}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: suspended
                        ? const Color(0xFFB45309)
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (manageable)
            PopupMenuButton<BranchMembershipStatus>(
              key: ValueKey('manager_member_menu_${member.id}'),
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 19,
                color: AppColors.textMuted,
              ),
              onSelected: (status) async {
                try {
                  await ref
                      .read(branchRepositoryProvider)
                      .setMembershipStatus(member.id, status);
                } on StateError catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              itemBuilder: (_) => [
                if (suspended)
                  const PopupMenuItem(
                    value: BranchMembershipStatus.active,
                    child: Text(AppStrings.branchStaffActivate),
                  )
                else
                  const PopupMenuItem(
                    value: BranchMembershipStatus.suspended,
                    child: Text(AppStrings.branchStaffSuspend),
                  ),
                const PopupMenuItem(
                  value: BranchMembershipStatus.removed,
                  child: Text(AppStrings.branchStaffRemove),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ManagerInviteTile extends ConsumerWidget {
  const _ManagerInviteTile({required this.invite});

  final BranchInvite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 15,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${invite.invitedName.isEmpty ? 'Davetli' : invite.invitedName}'
              ' · ${invite.role.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextButton(
            key: ValueKey('manager_invite_cancel_${invite.id}'),
            onPressed: () =>
                ref.read(branchRepositoryProvider).cancelInvite(invite.id),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }
}

/// Sorumlunun davet sheet'i — FN-ID + alt rol + süreç izinleri.
/// branch_manager rolü LİSTEDE YOK (server da reddeder).
Future<void> showBranchManagerInviteSheet(
  BuildContext context, {
  required String branchId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _ManagerInviteSheet(branchId: branchId),
    ),
  );
}

class _ManagerInviteSheet extends ConsumerStatefulWidget {
  const _ManagerInviteSheet({required this.branchId});

  final String branchId;

  @override
  ConsumerState<_ManagerInviteSheet> createState() =>
      _ManagerInviteSheetState();
}

class _ManagerInviteSheetState extends ConsumerState<_ManagerInviteSheet> {
  static final List<BranchRole> _allowedRoles = BranchRole.values
      .where((r) => r != BranchRole.branchManager)
      .toList(growable: false);

  final _fnId = TextEditingController();
  BranchRole _role = BranchRole.counter;
  final Set<BranchProcessType> _permissions = {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _fnId.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_saving) return;
    if (_fnId.text.trim().isEmpty) {
      setState(() => _error = AppStrings.branchInviteFnIdRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(branchRepositoryProvider)
          .createStaffInvite(
            branchId: widget.branchId,
            firinnetId: _fnId.text,
            role: _role,
            permissions: _permissions.toList(growable: false),
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
        _error = AppStrings.branchInviteGenericError;
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
              AppStrings.branchInviteTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              AppStrings.branchManagerInviteRoleNote,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _fnId,
              decoration: const InputDecoration(
                labelText: AppStrings.branchInviteFnIdLabel,
                hintText: AppStrings.branchInviteFnIdHint,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            const Text(
              AppStrings.branchInviteRoleField,
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
                for (final role in _allowedRoles)
                  ChoiceChip(
                    key: ValueKey('manager_role_${role.persistKey}'),
                    label: Text(role.label),
                    selected: _role == role,
                    onSelected: (_) => setState(() => _role = role),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedColor: AppColors.brandLemonPale,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            const Text(
              AppStrings.branchInvitePermissionsField,
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
                for (final type in BranchProcessType.values)
                  FilterChip(
                    key: ValueKey('manager_perm_${type.persistKey}'),
                    label: Text(type.label),
                    selected: _permissions.contains(type),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _permissions.add(type);
                      } else {
                        _permissions.remove(type);
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
                key: const ValueKey('manager_invite_send'),
                onPressed: _saving ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandLemon,
                  foregroundColor: AppColors.brandInk,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
                child: Text(
                  _saving
                      ? AppStrings.branchInviteSending
                      : AppStrings.branchInviteSend,
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
