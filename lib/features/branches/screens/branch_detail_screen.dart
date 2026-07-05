import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/tr_case.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/branch_activity.dart';
import '../models/branch_models.dart';
import '../providers/branch_providers.dart';
import '../widgets/branch_activity_list.dart';
import '../widgets/branch_permissions_sheet.dart';
import '../widgets/branch_process_sheet.dart';
import '../widgets/branch_process_tile.dart';
import '../widgets/branch_template_row.dart';

/// Şube detay mini app'i — Genel / Personel / Süreçler / Yetkiler / Geçmiş.
class BranchDetailScreen extends ConsumerWidget {
  const BranchDetailScreen({super.key, required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(branchByIdProvider(branchId));
    return DefaultTabController(
      length: 5,
      child: PremiumScaffold(
        appBar: AppBar(
          title: Text(branch.valueOrNull?.name ?? AppStrings.branchMgmtTitle),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            tabs: [
              Tab(text: AppStrings.branchTabGeneral),
              Tab(text: AppStrings.branchTabStaff),
              Tab(text: AppStrings.branchTabProcesses),
              Tab(text: AppStrings.branchTabPermissions),
              Tab(text: AppStrings.branchTabActivity),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _GeneralTab(branchId: branchId),
              _StaffTab(branchId: branchId),
              _ProcessesTab(branchId: branchId),
              _PermissionsTab(branchId: branchId),
              _ActivityTab(branchId: branchId),
            ],
          ),
        ),
      ),
    );
  }
}

/// V2 — Geçmiş tabı: filtreli aktivite listesi (append-only log görünümü).
class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.branchId});
  final String branchId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageH),
      children: [BranchActivityList(branchId: branchId)],
    );
  }
}

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab({required this.branchId});
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(branchByIdProvider(branchId)).valueOrNull;
    final processes =
        ref.watch(branchProcessesProvider(branchId)).valueOrNull ?? const [];
    final invites =
        ref.watch(branchPendingInvitesProvider(branchId)).valueOrNull ??
        const [];
    if (branch == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final open = processes.where((p) => p.status.isOpen).length;
    final attention = processes
        .where((p) => p.status == BranchProcessStatus.attention)
        .length;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageH),
      children: [
        PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                _InfoRow(
                  icon: Icons.place_outlined,
                  text: branch.address.isEmpty ? '—' : branch.address,
                ),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  text: branch.phone.isEmpty ? '—' : branch.phone,
                ),
                _InfoRow(
                  icon: Icons.badge_outlined,
                  text:
                      '${AppStrings.branchDetailManager}: '
                      '${branch.managerName ?? AppStrings.branchDetailNoManager}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              children: [
                Row(
                  children: [
                    _Summary(count: '${branch.memberCount}', label: 'Personel'),
                    _Summary(count: '$open', label: 'Açık süreç'),
                    _Summary(count: '$attention', label: 'Dikkat'),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: [
                    _Summary(
                      count:
                          '${processes.where((p) => p.status == BranchProcessStatus.completed).length}',
                      label: 'Tamamlanan',
                    ),
                    _Summary(
                      count: '${invites.length}',
                      label: 'Bekleyen davet',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        _RangeSummaryCard(branchId: branchId, processes: processes),
        const SizedBox(height: AppSpacing.m),
        // Pasif şube listede Pasif rozetiyle kalır; veri silinmez.
        OutlinedButton.icon(
          key: const ValueKey('branch_toggle_active'),
          onPressed: () => _toggleActive(context, ref, branch),
          icon: Icon(
            branch.isActive
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
            size: 18,
          ),
          label: Text(
            branch.isActive
                ? AppStrings.branchDeactivateCta
                : AppStrings.branchActivateCta,
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 46),
            foregroundColor: branch.isActive
                ? AppColors.textSecondary
                : AppColors.brandInk,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    Branch branch,
  ) async {
    if (branch.isActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(AppStrings.branchDeactivateConfirmTitle),
          content: const Text(AppStrings.branchDeactivateConfirmBody),
          actions: [
            TextButton(
              key: const ValueKey('branch_deactivate_cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(AppStrings.branchConfirmCancel),
            ),
            FilledButton(
              key: const ValueKey('branch_deactivate_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(AppStrings.branchConfirmApprove),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await ref
        .read(branchRepositoryProvider)
        .setBranchActive(branch.id, !branch.isActive);
  }
}

/// V2 — Bugün / 7 Gün filtreli küçük operasyon özeti + son aktivite satırı.
class _RangeSummaryCard extends ConsumerStatefulWidget {
  const _RangeSummaryCard({required this.branchId, required this.processes});

  final String branchId;
  final List<BranchProcess> processes;

  @override
  ConsumerState<_RangeSummaryCard> createState() => _RangeSummaryCardState();
}

class _RangeSummaryCardState extends ConsumerState<_RangeSummaryCard> {
  bool _week = false;

  bool _inRange(DateTime? at) {
    if (at == null) return false;
    final now = DateTime.now();
    if (_week) {
      return now.difference(at).inDays < 7;
    }
    return at.year == now.year && at.month == now.month && at.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final created = widget.processes.where((p) => _inRange(p.createdAt)).length;
    final completed = widget.processes
        .where((p) => _inRange(p.completedAt))
        .length;
    final activity =
        ref.watch(branchActivityProvider(widget.branchId)).valueOrNull ??
        const <BranchActivityEntry>[];
    final last = activity.isEmpty ? null : activity.first;
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dar ekran + büyük yazı ölçeğinde chip'ler taşmasın (Wrap).
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (label, week) in [
                  (AppStrings.branchSummaryToday, false),
                  (AppStrings.branchSummaryWeek, true),
                ])
                  ChoiceChip(
                    key: ValueKey('branch_summary_range_$week'),
                    label: Text(label),
                    selected: _week == week,
                    onSelected: (_) => setState(() => _week = week),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedColor: AppColors.brandLemonPale,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Row(
              children: [
                _Summary(
                  count: '$created',
                  label: AppStrings.branchSummaryCreated,
                ),
                _Summary(
                  count: '$completed',
                  label: AppStrings.branchSummaryCompleted,
                ),
              ],
            ),
            if (last != null) ...[
              const SizedBox(height: AppSpacing.s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${AppStrings.branchSummaryLastActivity}: '
                      '${last.description}'
                      '${last.actorName.isEmpty ? '' : ' · ${last.actorName}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.count, required this.label});
  final String count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffTab extends ConsumerWidget {
  const _StaffTab({required this.branchId});
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(branchMembersProvider(branchId)).valueOrNull ?? const [];
    final invites =
        ref.watch(branchPendingInvitesProvider(branchId)).valueOrNull ??
        const [];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageH),
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('branch_staff_add_cta'),
            // Detaydan gelişte şube önceden seçili gelsin (değiştirilebilir).
            onPressed: () =>
                context.push('${AppRoutes.branchStaffNew}?branch=$branchId'),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text(AppStrings.branchStaffAddCta),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandLemon,
              foregroundColor: AppColors.brandInk,
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        if (invites.isNotEmpty) ...[
          const _SectionLabel(AppStrings.branchStaffPendingSection),
          for (final inv in invites)
            PremiumCard(
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                title: Text(
                  inv.invitedName.isEmpty ? 'Davetli' : inv.invitedName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(inv.role.label),
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(branchRepositoryProvider)
                        .cancelInvite(inv.id);
                  },
                  child: const Text('İptal'),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.m),
        ],
        if (members.isEmpty && invites.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              AppStrings.branchStaffEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          )
        else
          for (final m in members) ...[
            _MemberCard(membership: m),
            const SizedBox(height: AppSpacing.s),
          ],
      ],
    );
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({required this.membership});
  final BranchMembership membership;

  /// Erişimi kapatan durum değişiklikleri onay ister (aktifleştirme direkt).
  Future<bool> _confirm(
    BuildContext context,
    BranchMembershipStatus status,
  ) async {
    final removing = status == BranchMembershipStatus.removed;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          removing
              ? AppStrings.branchStaffRemoveConfirmTitle
              : AppStrings.branchStaffSuspendConfirmTitle,
        ),
        content: Text(
          removing
              ? AppStrings.branchStaffRemoveConfirmBody
              : AppStrings.branchStaffSuspendConfirmBody,
        ),
        actions: [
          TextButton(
            key: const ValueKey('member_action_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.branchConfirmCancel),
          ),
          FilledButton(
            key: const ValueKey('member_action_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: removing
                  ? AppColors.danger
                  : AppColors.brandLemon,
              foregroundColor: removing ? Colors.white : AppColors.brandInk,
            ),
            child: Text(
              removing
                  ? AppStrings.branchStaffRemove
                  : AppStrings.branchStaffSuspend,
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = membership;
    final suspended = m.status == BranchMembershipStatus.suspended;
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.memberName.isEmpty ? 'Personel' : m.memberName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${m.role.label} · ${m.status.label}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: suspended
                          ? const Color(0xFFB45309)
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<BranchMembershipStatus>(
              key: ValueKey('member_menu_${m.id}'),
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
              onSelected: (status) async {
                if (status != BranchMembershipStatus.active &&
                    !await _confirm(context, status)) {
                  return;
                }
                await ref
                    .read(branchRepositoryProvider)
                    .setMembershipStatus(m.id, status);
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
      ),
    );
  }
}

class _ProcessesTab extends ConsumerWidget {
  const _ProcessesTab({required this.branchId});
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final processes =
        ref.watch(branchProcessesProvider(branchId)).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageH),
      children: [
        // V2: şablondan hızlı süreç oluşturma (patron tüm tipler).
        BranchTemplateRow(
          branchId: branchId,
          allowedTypes: BranchProcessType.values,
        ),
        const SizedBox(height: AppSpacing.m),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('branch_process_add_cta'),
            onPressed: () => showBranchProcessSheet(
              context,
              ref,
              branchId: branchId,
              // Patron tüm tiplerde süreç açabilir.
              allowedTypes: BranchProcessType.values,
            ),
            icon: const Icon(Icons.add_task_rounded, size: 18),
            label: const Text(AppStrings.branchProcessAddCta),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandLemon,
              foregroundColor: AppColors.brandInk,
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        if (processes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              AppStrings.branchProcessEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          )
        else
          for (final p in processes) ...[
            BranchProcessTile(process: p, canEdit: true),
            const SizedBox(height: AppSpacing.s),
          ],
      ],
    );
  }
}

class _PermissionsTab extends ConsumerWidget {
  const _PermissionsTab({required this.branchId});
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(branchMembersProvider(branchId)).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageH),
      children: [
        const Text(
          AppStrings.branchPermissionsInfo,
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        const _SectionLabel('Roller'),
        for (final role in BranchRole.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.s),
                Text(
                  role.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.m),
        if (members.isNotEmpty) ...[
          const _SectionLabel('Personel izinleri'),
          for (final m in members)
            PremiumCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${m.memberName} — ${m.role.label}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // V2: izinler yeniden davet gerektirmeden düzenlenir
                        // (şube sorumlusu zaten tüm tiplere yetkili).
                        if (!m.role.hasAllProcessPermissions)
                          TextButton(
                            key: ValueKey('perm_edit_cta_${m.id}'),
                            onPressed: () => showBranchPermissionsSheet(
                              context,
                              membership: m,
                            ),
                            child: const Text(
                              AppStrings.branchPermissionsEditCta,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.role.hasAllProcessPermissions
                          ? 'Tüm süreç tipleri'
                          : m.permissions.isEmpty
                          ? 'Süreç izni yok'
                          : m.permissions.map((p) => p.label).join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s, left: 2),
      child: Text(
        trUpperCase(title),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
