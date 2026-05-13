import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../features/feed/models/post_type.dart';

/// Feed post kartı — tip rozeti, etkileşim toggle, etiket tap, opsiyonel
/// grup highlight şeridi.
class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.author,
    required this.role,
    required this.timeAgo,
    required this.content,
    required this.likeCount,
    required this.commentCount,
    this.imageGradient,
    this.tags = const <String>[],
    this.type = PostType.production,
    this.isLiked = false,
    this.isSaved = false,
    this.groupName,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onShare,
    this.onTagTap,
    this.onGoToGroup,
  });

  final String author;
  final String role;
  final String timeAgo;
  final String content;
  final int likeCount;
  final int commentCount;
  final List<Color>? imageGradient;
  final List<String> tags;

  final PostType type;
  final bool isLiked;
  final bool isSaved;

  /// Group highlight türünde kart için kaynak grup adı.
  final String? groupName;

  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final ValueChanged<String>? onTagTap;
  final VoidCallback? onGoToGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHighlight = type == PostType.groupHighlight;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(
          color: isHighlight
              ? AppColors.copper.withValues(alpha: 0.32)
              : AppColors.borderHairline,
          width: isHighlight ? 0.8 : 0.6,
        ),
        boxShadow: isHighlight ? AppShadow.copper : AppShadow.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group highlight ribbon
          if (isHighlight && groupName != null)
            _GroupHighlightRibbon(
              groupName: groupName!,
              onTap: onGoToGroup,
            ),
          // Yazar + tip rozeti satırı
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.elevatedCard,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    author.isNotEmpty ? author[0].toUpperCase() : '?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.softGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        author,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$role · $timeAgo',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _TypeBadge(type: type),
              ],
            ),
          ),

          // Görsel — placeholder gradient
          if (imageGradient != null)
            AspectRatio(
              aspectRatio: 5 / 4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: imageGradient!,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_outlined,
                        size: 36,
                        color:
                            AppColors.textMuted.withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Görsel yüklenmedi',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted
                              .withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // İçerik
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: Text(
              content,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),

          // Etiketler
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                0,
                AppSpacing.l,
                AppSpacing.m,
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in tags)
                    InkWell(
                      onTap: onTagTap == null ? null : () => onTagTap!(t),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: AppColors.softGold.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '#$t',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.softGold,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Etkileşim satırı
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s,
              0,
              AppSpacing.s,
              AppSpacing.s,
            ),
            child: Row(
              children: [
                _Action(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  label: '$likeCount',
                  active: isLiked,
                  onTap: onLike,
                ),
                _Action(
                  icon: Icons.mode_comment_outlined,
                  label: '$commentCount',
                  onTap: onComment,
                ),
                _Action(
                  icon: Icons.send_outlined,
                  label: AppStrings.feedActionShare,
                  onTap: onShare,
                ),
                const Spacer(),
                _Action(
                  icon: isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  label: '',
                  active: isSaved,
                  onTap: onSave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final PostType type;

  @override
  Widget build(BuildContext context) {
    final accent = type.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: accent.withValues(alpha: 0.36),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            type.label.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHighlightRibbon extends StatelessWidget {
  const _GroupHighlightRibbon({required this.groupName, this.onTap});
  final String groupName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.copper.withValues(alpha: 0.10),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: 9,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.forum_rounded,
                size: 14,
                color: AppColors.softGold,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: groupName,
                        style: const TextStyle(
                          color: AppColors.softGold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                        text: AppStrings.feedGroupHighlightSuffix,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.feedActionGoToGroup,
                        style: TextStyle(
                          color: AppColors.softGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.softGold,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.copper : AppColors.textSecondary;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
