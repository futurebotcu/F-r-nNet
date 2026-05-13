import 'package:flutter/material.dart';

/// Feed içine serpiştirilen küçük "sosyal büyüme" rozet kartı.
/// Veriden bağımsız tasarım — backend olduğunda metric'lere bağlanır.
enum FeedInsightKind {
  trending,        // Bugün ağda öne çıkanlar
  topConversation, // Bu hafta en çok konuşulan konu
  newGroups,       // Yeni katılan gruplar
}

extension FeedInsightKindLabel on FeedInsightKind {
  String get label {
    switch (this) {
      case FeedInsightKind.trending:
        return 'Bugün ağda öne çıkanlar';
      case FeedInsightKind.topConversation:
        return 'Bu hafta en çok konuşulan';
      case FeedInsightKind.newGroups:
        return 'Yeni katılan gruplar';
    }
  }

  IconData get icon {
    switch (this) {
      case FeedInsightKind.trending:
        return Icons.local_fire_department_rounded;
      case FeedInsightKind.topConversation:
        return Icons.forum_rounded;
      case FeedInsightKind.newGroups:
        return Icons.group_add_rounded;
    }
  }
}

class FeedInsight {
  const FeedInsight({
    required this.kind,
    required this.headline,
    required this.body,
  });

  final FeedInsightKind kind;
  final String headline;
  final String body;
}
