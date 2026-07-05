import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../models/branch_models.dart';
import '../providers/branch_providers.dart';

/// Tek şube süreci kartı: tip ikonu + başlık + oluşturan + durum rozeti.
/// [canEdit] true ise durum menüsü görünür (server yine de izni denetler).
class BranchProcessTile extends ConsumerWidget {
  const BranchProcessTile({
    super.key,
    required this.process,
    this.canEdit = false,
  });

  final BranchProcess process;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = process;
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.brandLemonPale,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.brandLemonPressed.withValues(alpha: 0.28),
                  width: 0.7,
                ),
              ),
              child: Icon(p.type.icon, size: 18, color: AppColors.brandInk),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      p.type.label,
                      if (p.createdByName.isNotEmpty) p.createdByName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (p.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      p.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BranchProcessStatusChip(status: p.status),
                if (canEdit)
                  PopupMenuButton<BranchProcessStatus>(
                    key: ValueKey('process_status_menu_${p.id}'),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    onSelected: (status) async {
                      try {
                        await ref
                            .read(branchRepositoryProvider)
                            .updateProcess(p.id, status: status);
                      } on StateError catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      for (final s in BranchProcessStatus.values)
                        if (s != p.status)
                          PopupMenuItem(value: s, child: Text(s.label)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Süreç durum rozeti (beklemede/devam/tamamlandı/dikkat renk ailesi).
class BranchProcessStatusChip extends StatelessWidget {
  const BranchProcessStatusChip({super.key, required this.status});

  final BranchProcessStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      BranchProcessStatus.pending => (
        AppColors.surfaceVariant,
        AppColors.textMuted,
      ),
      BranchProcessStatus.inProgress => (
        AppColors.brandLemonPale,
        AppColors.brandInk,
      ),
      BranchProcessStatus.completed => (
        const Color(0xFFF3FBEF),
        const Color(0xFF166534),
      ),
      BranchProcessStatus.attention => (
        const Color(0xFFFFF1F2),
        const Color(0xFFB91C1C),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
