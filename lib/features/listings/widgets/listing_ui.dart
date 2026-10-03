// İlanlar polish 2 — ilan kartı/detay/form ekranlarının ortak küçük parçaları.
//
//   * ListingSectionHeader — form ve detay bölüm başlığı (tek tipografi).
//   * ListingInfoRow       — detayda etiket/değer satırı (boş değer çizilmez).
//   * ListingStickyBar     — alt sabit CTA çubuğu: SafeArea + klavye açıkken
//                            klavyenin üstünde kalır.
//   * ListingSkeletonList  — ilk yüklemede tek büyük spinner yerine hafif,
//                            statik kart yer tutucuları (shimmer yok).

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';

/// Form/detay bölüm başlığı ("Temel bilgi", "Konum", "Açıklama"…).
class ListingSectionHeader extends StatelessWidget {
  const ListingSectionHeader(this.label, {super.key, this.top = AppSpacing.l});

  final String label;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: AppSpacing.s),
      child: Semantics(
        header: true,
        child: Text(label, style: AppTypography.sectionTitle),
      ),
    );
  }
}

/// Detayda etiket → değer satırı. Değer boşsa hiç çizilmez ("—" yok).
class ListingInfoRow extends StatelessWidget {
  const ListingInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String? value;

  /// "—", "null", boş gibi anlamsız değerler gizlenir.
  static bool isMeaningful(String? v) {
    final t = (v ?? '').trim();
    return t.isNotEmpty && t != '—' && t != '-' && t.toLowerCase() != 'null';
  }

  @override
  Widget build(BuildContext context) {
    if (!isMeaningful(value)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: AppTypography.infoLabel)),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            flex: 3,
            child: Text(
              value!.trim(),
              textAlign: TextAlign.right,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alt sabit CTA çubuğu. `Scaffold.bottomNavigationBar` içinde kullanılır;
/// klavye açıkken klavye yüksekliği kadar yukarı itilir → birincil CTA
/// her zaman erişilebilir.
class ListingStickyBar extends StatelessWidget {
  const ListingStickyBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.borderHairline, width: 0.6),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.s,
              AppSpacing.pageH,
              AppSpacing.m,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// İlk yükleme yer tutucusu: 3 statik kart iskeleti (animasyon yok).
class ListingSkeletonList extends StatelessWidget {
  const ListingSkeletonList({
    super.key,
    this.count = 3,
    this.withImage = false,
  });

  final int count;

  /// Market kartı gibi üstte görsel alanı olan kartlar için.
  final bool withImage;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.listingsLoadingLabel,
      child: Padding(
        key: const ValueKey('listing_skeleton'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          AppSpacing.s,
          AppSpacing.pageH,
          AppSpacing.l,
        ),
        child: Column(
          children: [
            for (var i = 0; i < count; i++) ...[
              _SkeletonCard(withImage: withImage),
              if (i != count - 1) const SizedBox(height: AppSpacing.m),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.withImage});
  final bool withImage;

  static const Color _bone = Color(0xFFEDEFF2);

  Widget _bar(double widthFactor, double height) => FractionallySizedBox(
    widthFactor: widthFactor,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: _bone,
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(
          color: AppColors.borderHairline.withValues(alpha: 0.7),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (withImage)
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(color: Color(0xFFF4F5F7)),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!withImage) ...[
                  _bar(0.38, 18),
                  const SizedBox(height: AppSpacing.m),
                ],
                _bar(0.85, 16),
                const SizedBox(height: AppSpacing.s),
                _bar(0.45, 14),
                const SizedBox(height: AppSpacing.s),
                _bar(0.6, 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
