// Tek onboarding sayfası — hero görsel + başlık + açıklama.
//
// Responsive: küçük ekranlarda taşmaz (SingleChildScrollView + minHeight),
// büyük ekranlarda orantılı ortalanır. Sayfa açılışında yumuşak fade + yukarı
// kayma mikro-animasyonu (tek-seferlik, controller'sız).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../models/onboarding_page_data.dart';
import 'onboarding_hero.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroSize = math.min(
          244.0,
          math.min(constraints.maxWidth * 0.66, constraints.maxHeight * 0.44),
        );
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.l,
              ),
              child: _Entrance(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OnboardingHero(kind: data.kind, size: heroSize),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      data.body,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tek-seferlik fade + yukarı kayma girişi (controller gerektirmez).
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppDuration.normal,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 18),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
