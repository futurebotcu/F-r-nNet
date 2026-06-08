import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../models/recipe_record.dart';

/// Reçete görünürlük rozeti — list kartında ve detayda kullanılır.
class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({super.key, required this.visibility});
  final RecipeVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final isPublic = visibility.isPublic;
    final label = isPublic ? 'PROFİLDE AÇIK' : 'GİZLİ';
    final icon = isPublic ? Icons.public_rounded : Icons.lock_outline_rounded;
    final color = isPublic ? AppColors.success : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 9.5,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}
