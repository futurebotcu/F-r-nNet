import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

/// Liste ilk yüklemesi için hafif, statik iskelet (animasyon yok).
///
/// Ortada tek büyük spinner yerine kartların yerini tutan sakin gri
/// bloklar: sayfa "boş/donmuş" görünmez, veri gelince düzen zıplamaz.
/// Erişilebilirlik için tek bir "Yükleniyor" semantik etiketi taşır.
class PremiumListSkeleton extends StatelessWidget {
  const PremiumListSkeleton({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 84,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.pageH,
      AppSpacing.s,
      AppSpacing.pageH,
      AppSpacing.xxl,
    ),
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  static const Color _block = Color(0xFFF1F2F4);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Yükleniyor',
      container: true,
      child: ExcludeSemantics(
        child: ListView.separated(
          key: const ValueKey('premium_list_skeleton'),
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.m),
          itemBuilder: (_, __) => Container(
            height: itemHeight,
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.l),
              border: Border.all(color: AppColors.borderHairline, width: 0.6),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _block,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(widthFactor: 0.6, child: _bar(12)),
                      const SizedBox(height: 8),
                      FractionallySizedBox(widthFactor: 0.85, child: _bar(10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(double h) => Container(
    height: h,
    decoration: BoxDecoration(
      color: _block,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
  );
}
