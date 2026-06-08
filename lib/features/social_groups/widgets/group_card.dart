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
    [AppColors.surfaceVariant, AppColors.background],
    [AppColors.background, AppColors.surfaceVariant],
    [AppColors.surfaceVariant, AppColors.surface],
    [AppColors.surface, AppColors.surfaceVariant],
    [AppColors.elevatedCard, AppColors.background],
    [AppColors.background, AppColors.elevatedCard],
    [AppColors.surfaceVariant, AppColors.elevatedCard],
    [AppColors.elevatedCard, AppColors.surface],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = _seedGradients[group.visualSeed.abs() % 8];

    // V1 UX Reset — kompakt kart düzeni:
    //   * "Katılım onaylı" badge'i joined kullanıcıya gösterilmez (zaten onayı
    //     geçmiş); yer açılır, kategori şeridinde "Fir..." kesilmesi ortadan
    //     kalkar.
    //   * Joined kart → "Aç" CTA kaldırılır (tüm kart tap zaten açıyor).
    //   * Padding xs azaltıldı; description compact'ta gizlenir.
    final showApprovalBadge = group.isPrivate && !isJoined;
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.l),
          // Görsel kalite — daha ince/rafine hairline + premium yumuşak gölge.
          border: Border.all(
            color: AppColors.borderHairline.withValues(alpha: 0.7),
            width: 0.6,
          ),
          boxShadow: AppShadow.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.brandLemonPressed.withValues(alpha: 0.06),
            child: Padding(
              padding: EdgeInsets.all(compact ? AppSpacing.m : AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover / category strip
                  Container(
                    height: compact ? 56 : 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      border: Border.all(
                        color: AppColors.brandLemonSoft,
                        width: 0.6,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(
                              alpha: 0.82,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.m),
                            border: Border.all(
                              color: AppColors.borderHairline,
                              width: 0.6,
                            ),
                          ),
                          child: Icon(
                            _categoryIcon(group.category),
                            color: AppColors.brandLemonPressed,
                            size: 16,
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
                        if (showApprovalBadge)
                          _MiniBadge(
                            label: AppStrings.groupApprovalRequiredBadge,
                            color: AppColors.brandInk,
                          ),
                        if (isJoined)
                          _MiniBadge(
                            label: AppStrings.groupBadgeMember,
                            color: AppColors.success,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
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
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      group.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s),
                  _MembersRow(group: group),
                  // G.N4 — Owner kartında pending request count pill.
                  // Compact varyantta gösterilmez (yer kalmaz).
                  if (pendingRequestCount > 0 && !compact) ...[
                    const SizedBox(height: AppSpacing.s),
                    _PendingRequestsPill(count: pendingRequestCount),
                  ],
                  // V1 UX Reset — Joined kartlarda primary CTA gösterilmez;
                  // kullanıcı zaten üye, "Aç" tap'i kartın kendisinden.
                  // Non-joined → Katıl / Dolu butonları görünür.
                  if (!isJoined) ...[
                    const SizedBox(height: AppSpacing.s),
                    _PrimaryCta(
                      group: group,
                      isJoined: isJoined,
                      onPressed: onPrimary,
                    ),
                  ],
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
                    ? AppColors.brandLemonPressed
                    : AppColors.brandLemonPale,
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
      bg = AppColors.brandLemon;
      fg = AppColors.brandInk;
      enabled = true;
    } else if (group.isFull) {
      label = AppStrings.groupActionFull;
      bg = AppColors.surfaceLine;
      fg = AppColors.textMuted;
      enabled = false;
    } else if (group.isPrivate) {
      // V1 P0 — Private grup için liste kartında doğrudan `joinGroup`
      // çağırma yolu kapalı. "Katılma isteği gönder" CTA'sı; handler
      // `_GroupCardWired.onPrimary` private branch'ine dispatch eder
      // (requestJoinGroup RPC).
      label = AppStrings.groupJoinRequestSend;
      bg = AppColors.brandLemonPale;
      fg = AppColors.brandInk;
      enabled = true;
    } else {
      label = AppStrings.groupActionJoin;
      bg = AppColors.brandLemon;
      fg = AppColors.brandInk;
      enabled = true;
    }

    return SizedBox(
      width: double.infinity,
      height: 42,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 1.2,
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
        horizontal: AppSpacing.s,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.brandLemonSoft, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 13,
            color: AppColors.brandLemonPressed,
          ),
          const SizedBox(width: 5),
          Text(
            AppStrings.groupPendingRequestCount(count),
            style: const TextStyle(
              color: AppColors.brandLemonPressed,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.6),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 9,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}
