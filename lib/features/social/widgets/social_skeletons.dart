import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';

/// Sosyal yüzeylerin (mesajlar, bildirimler, kullanıcı listeleri, profil,
/// Akademi) İLK yükleme iskeleti. Statik gri bloklar — animasyon/shimmer
/// yok (jank yok). Ortada tek başına dev spinner yerine kullanılır; sonraki
/// sayfa yüklemesi listede küçük satır-içi göstergede kalır.
class SkeletonBar extends StatelessWidget {
  const SkeletonBar({super.key, this.width, this.height = 12});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceLine,
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
    );
  }
}

/// Tek liste satırı iskeleti: avatar dairesi + iki çubuk (isim / önizleme).
class SocialRowSkeleton extends StatelessWidget {
  const SocialRowSkeleton({super.key, this.avatarSize = 40, this.card = true});

  final double avatarSize;

  /// true → kart yüzeyi (mesaj listesi gibi), false → düz satır.
  final bool card;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: const BoxDecoration(
            color: AppColors.surfaceLine,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBar(width: c.maxWidth * 0.55),
                const SizedBox(height: 8),
                SkeletonBar(width: c.maxWidth * 0.85, height: 10),
              ],
            ),
          ),
        ),
      ],
    );
    if (!card) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageH,
          vertical: AppSpacing.s,
        ),
        child: row,
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: AppShadow.card,
      ),
      child: row,
    );
  }
}

/// [count] satırlık liste iskeleti (kaydırılamaz; üst liste içine gömülür).
class SocialListSkeleton extends StatelessWidget {
  const SocialListSkeleton({
    super.key,
    this.count = 5,
    this.avatarSize = 40,
    this.card = true,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.pageH,
      AppSpacing.s,
      AppSpacing.pageH,
      AppSpacing.l,
    ),
  });

  final int count;
  final double avatarSize;
  final bool card;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.socialLoadingLabel,
      child: Padding(
        padding: card ? padding : EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0 && card) const SizedBox(height: AppSpacing.s),
              SocialRowSkeleton(avatarSize: avatarSize, card: card),
            ],
          ],
        ),
      ),
    );
  }
}

/// Görsel + başlık kartı iskeleti (Akademi tarif kartı gibi).
class SocialCardSkeleton extends StatelessWidget {
  const SocialCardSkeleton({super.key, this.mediaAspect = 16 / 9});

  final double mediaAspect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: AppShadow.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: mediaAspect,
            child: const ColoredBox(color: AppColors.surfaceLine),
          ),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBar(width: 180, height: 14),
                SizedBox(height: 8),
                SkeletonBar(width: 120, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Statik iskelet kart — gönderi kartının yerleşimini (avatar, isim, metin,
/// görsel, aksiyonlar) gri bloklarla taklit eder.
class FeedSkeletonCard extends StatelessWidget {
  const FeedSkeletonCard({super.key, this.withMedia = false});

  final bool withMedia;

  static Widget _bar(double width, {double height = 12}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceLine,
      borderRadius: BorderRadius.circular(AppRadius.s),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        10,
        AppSpacing.pageH,
        10,
      ),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLine,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_bar(120), const SizedBox(height: 8), _bar(72)],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          _bar(double.infinity),
          const SizedBox(height: 8),
          _bar(220),
          if (withMedia) ...[
            const SizedBox(height: AppSpacing.m),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLine,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [_bar(28), _bar(28), _bar(28), _bar(28)],
          ),
        ],
      ),
    );
  }
}
