import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../models/feed_insight.dart';

/// Feed içine serpiştirilen küçük insight rozet kartı.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight});

  final FeedInsight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentFor(insight.kind);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.10),
            AppColors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(
          color: accent.withValues(alpha: 0.32),
          width: 0.6,
        ),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.s),
              border: Border.all(
                color: accent.withValues(alpha: 0.36),
                width: 0.6,
              ),
            ),
            child: Icon(insight.kind.icon, color: accent, size: 19),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  insight.kind.label.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.headline,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  insight.body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _accentFor(FeedInsightKind k) {
    switch (k) {
      case FeedInsightKind.trending:
        return AppColors.copper;
      case FeedInsightKind.topConversation:
        return AppColors.softGold;
      case FeedInsightKind.newGroups:
        return AppColors.success;
    }
  }
}
