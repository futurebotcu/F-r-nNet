import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/branch_models.dart';
import '../providers/branch_providers.dart';
import '../widgets/branch_process_sheet.dart';
import '../widgets/branch_process_tile.dart';

/// "Şube İşlerim" — bireysel şube personeli mini app'i.
///
/// YÖNETİM YOK: şube oluşturma, personel ekleme, işletme ayarı, diğer
/// şubeler burada hiç render edilmez (asıl sınır RLS'te). Kullanıcı yalnız
/// aktif üyeliği olan şube(ler)i görür; izinli süreç tiplerinde ekleme/
/// güncelleme/not düşme yapar. Bekleyen davetler burada kabul/red edilir.
class MyBranchScreen extends ConsumerStatefulWidget {
  const MyBranchScreen({super.key});

  @override
  ConsumerState<MyBranchScreen> createState() => _MyBranchScreenState();
}

class _MyBranchScreenState extends ConsumerState<MyBranchScreen> {
  String? _selectedBranchId;

  @override
  Widget build(BuildContext context) {
    final memberships =
        ref.watch(myBranchMembershipsProvider).valueOrNull ?? const [];
    final invites = ref.watch(myBranchInvitesProvider).valueOrNull ?? const [];

    BranchMembership? current;
    if (memberships.isNotEmpty) {
      current = memberships.firstWhere(
        (m) => m.branchId == _selectedBranchId,
        orElse: () => memberships.first,
      );
    }

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.myBranchTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            if (invites.isNotEmpty) ...[
              const _SectionLabel(AppStrings.myBranchInviteSection),
              for (final inv in invites) _InviteCard(invite: inv),
              const SizedBox(height: AppSpacing.m),
            ],
            if (current == null && invites.isEmpty)
              const _MyBranchEmpty()
            else if (current != null) ...[
              if (memberships.length > 1) ...[
                DropdownButtonFormField<String>(
                  key: const ValueKey('my_branch_picker'),
                  initialValue: current.branchId,
                  items: [
                    for (final m in memberships)
                      DropdownMenuItem(
                        value: m.branchId,
                        child: Text(m.branchName),
                      ),
                  ],
                  onChanged: (v) => setState(() => _selectedBranchId = v),
                  decoration: const InputDecoration(
                    labelText: AppStrings.myBranchPickerLabel,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
              ],
              _MembershipHeader(membership: current),
              const SizedBox(height: AppSpacing.m),
              _MyProcesses(membership: current),
            ],
          ],
        ),
      ),
    );
  }
}

class _MembershipHeader extends StatelessWidget {
  const _MembershipHeader({required this.membership});
  final BranchMembership membership;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brandLemonPale,
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              child: const Icon(
                Icons.store_mall_directory_outlined,
                color: AppColors.brandInk,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    membership.branchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    membership.role.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyProcesses extends ConsumerWidget {
  const _MyProcesses({required this.membership});
  final BranchMembership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final processes =
        ref.watch(branchProcessesProvider(membership.branchId)).valueOrNull ??
        const [];
    final allowedTypes = membership.role.hasAllProcessPermissions
        ? BranchProcessType.values
        : membership.permissions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (allowedTypes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.m),
            child: Text(
              AppStrings.myBranchNoPermittedTypes,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.m),
            child: FilledButton.icon(
              key: const ValueKey('my_branch_process_add'),
              onPressed: () => showBranchProcessSheet(
                context,
                ref,
                branchId: membership.branchId,
                allowedTypes: allowedTypes,
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
            BranchProcessTile(
              process: p,
              // Durum menüsü yalnız izinli tiplerde (server yine denetler).
              canEdit: membership.canWrite(p.type),
            ),
            const SizedBox(height: AppSpacing.s),
          ],
      ],
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.invite});
  final BranchInvite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Şube adı kabul öncesi RLS gereği gelmeyebilir → güvenli
            // fallback başlık; davet eden işletme adı ayrı satırda gösterilir.
            Text(
              invite.branchName.isEmpty
                  ? AppStrings.myBranchInviteFallbackTitle
                  : invite.branchName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              [
                if (invite.ownerName.isNotEmpty)
                  '${AppStrings.myBranchInviteFrom}: ${invite.ownerName}',
                invite.role.label,
              ].join(' · '),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('branch_invite_reject_${invite.id}'),
                    onPressed: () => ref
                        .read(branchRepositoryProvider)
                        .respondInvite(invite.id, accept: false),
                    child: const Text(AppStrings.myBranchInviteReject),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: FilledButton(
                    key: ValueKey('branch_invite_accept_${invite.id}'),
                    onPressed: () => ref
                        .read(branchRepositoryProvider)
                        .respondInvite(invite.id, accept: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandLemon,
                      foregroundColor: AppColors.brandInk,
                    ),
                    child: const Text(AppStrings.myBranchInviteAccept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MyBranchEmpty extends StatelessWidget {
  const _MyBranchEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: const [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 40,
            color: AppColors.textMuted,
          ),
          SizedBox(height: AppSpacing.m),
          Text(
            AppStrings.myBranchEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
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
        title,
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
