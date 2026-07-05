import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/branch_activity.dart';
import '../providers/branch_providers.dart';

/// V2 — şube aktivite geçmişi: filtre chip'leri + olay satırları.
///
/// Ticari şube detayında (Geçmiş tabı) ve bireysel Şube İşlerim'de ortak
/// kullanılır. Veri sınırı RLS'tedir: kullanıcı yalnız erişebildiği şubenin
/// log'unu alır; bu widget yalnız verilen [branchId] için render eder.
/// [maxEntries] bireysel yüzeyde listeyi kompakt tutmak içindir.
class BranchActivityList extends ConsumerStatefulWidget {
  const BranchActivityList({
    super.key,
    required this.branchId,
    this.maxEntries,
  });

  final String branchId;
  final int? maxEntries;

  @override
  ConsumerState<BranchActivityList> createState() => _BranchActivityListState();
}

class _BranchActivityListState extends ConsumerState<BranchActivityList> {
  BranchActivityFilter _filter = BranchActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final all =
        ref.watch(branchActivityProvider(widget.branchId)).valueOrNull ??
        const <BranchActivityEntry>[];
    var entries = all.where(_filter.matches).toList(growable: false);
    if (widget.maxEntries != null && entries.length > widget.maxEntries!) {
      entries = entries.sublist(0, widget.maxEntries!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in BranchActivityFilter.values) ...[
                ChoiceChip(
                  key: ValueKey('branch_activity_filter_${f.name}'),
                  label: Text(f.label),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: AppColors.brandLemonPale,
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              AppStrings.branchActivityEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          )
        else
          for (final e in entries) _ActivityTile(entry: e),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry});

  final BranchActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final accent = entry.isAttention
        ? const Color(0xFFB91C1C)
        : entry.isCompleted
        ? const Color(0xFF166534)
        : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(entry.icon, size: 16, color: accent),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  [
                    if (entry.actorName.isNotEmpty) entry.actorName,
                    _timeLabel(entry.createdAt),
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime? at) {
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'şimdi';
    if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
    if (d.inHours < 24) return '${d.inHours} sa önce';
    if (d.inDays < 7) return '${d.inDays} gün önce';
    return '${at.day.toString().padLeft(2, '0')}.'
        '${at.month.toString().padLeft(2, '0')}.${at.year}';
  }
}
