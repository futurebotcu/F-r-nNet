import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../models/group_category.dart';
import '../models/social_group.dart';

/// Grupların hem listelerde hem Feed carousel'inde kullanılan ortak kartı.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    required this.isJoined,
    required this.onPrimary,
    this.onTap,
    this.compact = false,
    this.width,
    this.pendingRequestCount = 0,
  });

  final SocialGroup group;
  final bool isJoined;

  /// Kartın CTA butonu için davranış (Katıl / Aç).
  final VoidCallback onPrimary;

  /// Kartın kendisine tap (genelde Aç ile aynı).
  final VoidCallback? onTap;

  /// `true` → Feed carousel'de kullanılan dar kart varyantı.
  final bool compact;
  final double? width;

  /// G.N4 — Owner kartında "X bekleyen istek" badge'i için.
  /// 0 ise badge gizlenir. Card kendi içinde owner logic bilmez; çağıran
  /// (groups_list_screen) owner-check'i yapar ve count'u pass eder.
  /// Compact varyantta gizlenir (carousel yüksekliği taşmasın).
  final int pendingRequestCount;

  static const _seedGradients = <List<Color>>[
    [Color(0xFFF3E6D3), Color(0xFFE5D2B0)],
    [Color(0xFFEDDDC4), Color(0xFFDFCCA8)],
    [Color(0xFFF2E2C6), Color(0xFFE4D0AC)],
    [Color(0xFFF5E8CF), Color(0xFFE8D6AE)],
    [Color(0xFFEEE0C4), Color(0xFFE0CDA8)],
    [Color(0xFFF3E5C8), Color(0xFFE6D2A8)],
    [Color(0xFFEEDDC0), Color(0xFFE0CBA4)],
    [Color(0xFFF1E2C5), Color(0xFFE4D0A8)],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = _seedGradients[group.visualSeed.abs() % 8];

    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
            color: AppColors.borderHairline,
            width: 0.6,
          ),
          boxShadow: AppShadow.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.softGold.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover / category strip
                  Container(
                    height: compact ? 64 : 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      border: Border.all(
                        color: AppColors.copper.withValues(alpha: 0.2),
                        width: 0.6,
                      ),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.7),
                            borderRadius:
                                BorderRadius.circular(AppRadius.s),
                            border: Border.all(
                              color: AppColors.softGold.withValues(alpha: 0.25),
                              width: 0.6,
                            ),
                          ),
                          child: Icon(
                            _categoryIcon(group.category),
                            color: AppColors.softGold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: Text(
                            group.category.label,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.isPrivate)
                          _MiniBadge(
                            // V1 P1-D / G.N5 — Private gruplar listede
                            // görünür ama içerik gated. Tek terim:
                            // "Katılım onaylı" — kullanıcı gizli değil,
                            // onaylı katılım olduğunu anlasın.
                            label: AppStrings.groupApprovalRequiredBadge,
                            color: AppColors.softGold,
                          ),
                        if (isJoined)
                          Padding(
                            padding: EdgeInsets.only(
                              left: group.isPrivate ? 4 : 0,
                            ),
                            child: _MiniBadge(
                              label: AppStrings.groupBadgeMember,
                              color: AppColors.success,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    group.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 14.5 : 16,
                      letterSpacing: -0.2,
                      height: 1.15,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  _MembersRow(group: group),
                  // G.N4 — Owner kartında pending request count pill.
                  // Compact varyantta (Joined carousel) yer kalmaz; sadece
                  // full kart varyantında gösterilir.
                  if (pendingRequestCount > 0 && !compact) ...[
                    const SizedBox(height: AppSpacing.s),
                    _PendingRequestsPill(count: pendingRequestCount),
                  ],
                  const SizedBox(height: AppSpacing.m),
                  _PrimaryCta(
                    group: group,
                    isJoined: isJoined,
                    onPressed: onPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(GroupCategory c) {
    switch (c) {
      case GroupCategory.bakers:
        return Icons.bakery_dining_rounded;
      case GroupCategory.flour:
        return Icons.grain_rounded;
      case GroupCategory.dealer:
        return Icons.local_shipping_rounded;
      case GroupCategory.equipment:
        return Icons.build_rounded;
      case GroupCategory.jobs:
        return Icons.work_rounded;
      case GroupCategory.recipe:
        return Icons.menu_book_rounded;
      case GroupCategory.regional:
        return Icons.place_rounded;
      case GroupCategory.wholesale:
        return Icons.warehouse_rounded;
    }
  }
}

class _MembersRow extends StatelessWidget {
  const _MembersRow({required this.group});
  final SocialGroup group;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormatter.integer(group.currentMemberCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.group_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              group.isUnlimited
                  ? '$fmt üye · ${AppStrings.groupBadgeUnlimited.toLowerCase()}'
                  : '$fmt / ${NumberFormatter.integer(group.maxMembers!)} üye',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (group.city.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    group.city,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (!group.isUnlimited)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: group.fillRatio,
              minHeight: 3,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                group.isFull
                    ? AppColors.danger
                    : group.fillRatio > 0.8
                        ? AppColors.copper
                        : AppColors.softGold,
              ),
            ),
          ),
      ],
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.group,
    required this.isJoined,
    required this.onPressed,
  });
  final SocialGroup group;
  final bool isJoined;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bg;
    final Color fg;
    final bool enabled;

    if (isJoined) {
      label = AppStrings.groupActionOpen;
      bg = AppColors.copper;
      fg = AppColors.textPrimary;
      enabled = true;
    } else if (group.isFull) {
      label = AppStrings.groupActionFull;
      bg = AppColors.surfaceLine;
      fg = AppColors.textMuted;
      enabled = false;
    } else {
      label = AppStrings.groupActionJoin;
      bg = AppColors.copper;
      fg = AppColors.textPrimary;
      enabled = true;
    }

    return SizedBox(
      width: double.infinity,
      height: 40,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.s),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// G.N4 — Owner kartında "X bekleyen istek" sinyali.
///
/// Sadece [GroupCard.pendingRequestCount] > 0 olduğunda render edilir;
/// `compact` varyantta gösterilmez. Owner grup detayına girmeden
/// bekleyen istek olduğunu fark etsin diye var.
class _PendingRequestsPill extends StatelessWidget {
  const _PendingRequestsPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.copper.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.copper.withValues(alpha: 0.36),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 13,
            color: AppColors.copper,
          ),
          const SizedBox(width: 6),
          Text(
            AppStrings.groupPendingRequestCount(count),
            style: const TextStyle(
              color: AppColors.copper,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: 0.36),
          width: 0.6,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 9.5,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
