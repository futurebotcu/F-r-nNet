// Onboarding hero görselleri — sayfa türüne göre premium, asset'siz
// kompozisyonlar (brand hariç: ilk sayfa gerçek FırınNet marka ikonunu gösterir).
//
// White-first, Bumble sarısı (brandLemon) vurgulu, çok hafif sıcak krem
// (brandLemonPale) yüzeyler + hairline çizgiler. Ağır gradient/gölge yok.
// 240px referans tasarım FittedBox ile küçük ekranlara ölçeklenir.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../models/onboarding_page_data.dart';

/// Marka ikonu asset yolu (pubspec assets'te tanımlı).
const String _brandIconAsset = 'assets/branding/firinnet_app_icon.png';

class OnboardingHero extends StatelessWidget {
  const OnboardingHero({super.key, required this.kind, this.size = 244});

  final OnboardingHeroKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 244,
          height: 244,
          child: switch (kind) {
            OnboardingHeroKind.brand => const _BrandHero(),
            OnboardingHeroKind.social => const _SocialHero(),
            OnboardingHeroKind.market => const _MarketHero(),
            OnboardingHeroKind.ledger => const _LedgerHero(),
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────── ortak parçalar

/// Yumuşak pale-lemon arka halo.
class _Halo extends StatelessWidget {
  const _Halo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      height: 232,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandLemonPale,
      ),
    );
  }
}

/// Beyaz premium kart sarmalayıcı (hairline + yumuşak gölge).
class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(AppSpacing.l),
    this.shadow = AppShadow.soft,
  });
  final Widget child;
  final double? width;
  final EdgeInsets padding;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

/// İçerik iskeleti için yuvarlatılmış nötr çizgi.
class _Line extends StatelessWidget {
  const _Line({required this.w, this.h = 8, this.strong = false});
  final double w;
  final double h;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: strong ? const Color(0xFFD6DAE0) : const Color(0xFFE9ECF0),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}

/// Lemon yuvarlak rozet (ikon taşıyıcı).
class _LemonBadge extends StatelessWidget {
  const _LemonBadge({required this.icon, this.size = 40});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandLemonPale,
      ),
      child: Icon(icon, size: size * 0.55, color: AppColors.brandInk),
    );
  }
}

// ─────────────────────────────────────────── 1) BRAND

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const _Halo(),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(38),
            boxShadow: AppShadow.floating,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(38),
            child: Image.asset(
              _brandIconAsset,
              width: 158,
              height: 158,
              fit: BoxFit.cover,
              // Test/asset eksikliğine karşı sade lemon flame fallback.
              errorBuilder: (_, __, ___) => Container(
                width: 158,
                height: 158,
                alignment: Alignment.center,
                color: AppColors.brandLemonPale,
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 76,
                  color: AppColors.brandLemonPressed,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────── 2) SOCIAL

class _SocialHero extends StatelessWidget {
  const _SocialHero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const _Halo(),
        // Arka derinlik kartı.
        Positioned(
          top: 30,
          child: Transform.rotate(
            angle: -0.05,
            child: _Card(
              width: 188,
              padding: const EdgeInsets.all(AppSpacing.l),
              shadow: AppShadow.subtle,
              child: const SizedBox(height: 96),
            ),
          ),
        ),
        // Ön post kartı.
        _Card(
          width: 196,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _LemonBadge(icon: Icons.person_rounded, size: 38),
                  const SizedBox(width: AppSpacing.m),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _Line(w: 88, h: 10, strong: true),
                      SizedBox(height: 6),
                      _Line(w: 54, h: 7),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              const _Line(w: 164, h: 8),
              const SizedBox(height: 7),
              const _Line(w: 118, h: 8),
              const SizedBox(height: AppSpacing.m),
              Row(
                children: const [
                  Icon(Icons.favorite_rounded,
                      size: 18, color: AppColors.brandLemonPressed),
                  SizedBox(width: 6),
                  _Line(w: 18, h: 7),
                  SizedBox(width: AppSpacing.l),
                  Icon(Icons.mode_comment_outlined,
                      size: 16, color: AppColors.textMuted),
                  SizedBox(width: 6),
                  _Line(w: 14, h: 7),
                ],
              ),
            ],
          ),
        ),
        // Yüzen beğeni rozeti.
        Positioned(
          right: 18,
          top: 22,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandLemon,
              boxShadow: AppShadow.card,
            ),
            child: const Icon(Icons.favorite_rounded,
                size: 20, color: AppColors.brandInk),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────── 3) MARKET

class _MarketHero extends StatelessWidget {
  const _MarketHero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const _Halo(),
        // Arka kart.
        Positioned(
          left: 26,
          bottom: 34,
          child: Transform.rotate(
            angle: 0.06,
            child: _Card(
              width: 120,
              padding: const EdgeInsets.all(AppSpacing.m),
              shadow: AppShadow.subtle,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _Line(w: 64, h: 8, strong: true),
                  SizedBox(height: 8),
                  _Line(w: 92, h: 7),
                ],
              ),
            ),
          ),
        ),
        // Ön ilan kartı.
        _Card(
          width: 188,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Görsel alanı.
              Container(
                height: 92,
                decoration: const BoxDecoration(
                  color: AppColors.brandLemonPale,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.l),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.inventory_2_rounded,
                    size: 38, color: AppColors.brandLemonPressed),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.brandLemon,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: const Icon(Icons.sell_rounded,
                              size: 13, color: AppColors.brandInk),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        const _Line(w: 56, h: 9, strong: true),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s),
                    const _Line(w: 150, h: 7),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────── 4) LEDGER

class _LedgerHero extends StatelessWidget {
  const _LedgerHero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const _Halo(),
        _Card(
          width: 198,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _Line(w: 74, h: 9, strong: true),
                  Icon(Icons.trending_up_rounded,
                      size: 18, color: AppColors.success),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              // Büyük değer satırı (örn. tutar).
              const _Line(w: 116, h: 16, strong: true),
              const SizedBox(height: AppSpacing.l),
              // Mini bar grafik.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  _Bar(h: 24, soft: true),
                  _Bar(h: 38),
                  _Bar(h: 30, soft: true),
                  _Bar(h: 50),
                  _Bar(h: 42, soft: true),
                ],
              ),
              const SizedBox(height: 6),
              const _Line(w: 158, h: 5),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mini bar grafik çubuğu.
class _Bar extends StatelessWidget {
  const _Bar({required this.h, this.soft = false});
  final double h;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        width: 16,
        height: h,
        decoration: BoxDecoration(
          color: soft ? AppColors.brandLemonSoft : AppColors.brandLemon,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
