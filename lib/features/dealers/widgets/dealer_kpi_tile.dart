import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';

/// Bayi Defteri KPI kartı — Genel Bakış / Raporlar / (Gün Sonu V1)
/// ortak widget'ı (Quality Patch v2).
///
/// Daha önce iki ekranda birebir aynı private `_KpiTile` class'ı vardı;
/// burada paylaşılmış halde tutuluyor. Render davranışı değişmedi:
/// uppercase label + emphasized warm card + tabularFigures (sayı/para
/// için), `isCount=true` ise feature kapanır.
class DealerKpiTile extends StatelessWidget {
  const DealerKpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    this.emphasized = false,
    this.isCount = false,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final Color accent;

  /// Emphasized: warm card (sıcak ton) + headlineSmall typografi.
  /// Net Değişim full-width tile için kullanılır.
  final bool emphasized;

  /// Sayı: tabularFigures feature kapanır (para tutarı değil count).
  final bool isCount;

  /// `MainAxisSize.min` vs `max`. Full-width emphasized tile için min;
  /// grid içindeki kartlar için max (kart yüksekliği eşitlenir).
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      warm: emphasized,
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: fullWidth ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style:
                (emphasized
                        ? theme.textTheme.headlineSmall
                        : theme.textTheme.titleLarge)
                    ?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontFeatures: isCount
                          ? null
                          : const [FontFeature.tabularFigures()],
                    ),
          ),
        ],
      ),
    );
  }
}
