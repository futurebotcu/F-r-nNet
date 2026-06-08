import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../profile/providers/profile_provider.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: AppDuration.normal,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 10),
                  child: child,
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.l),
                    border: Border.all(
                      color: AppColors.borderHairline,
                      width: 0.6,
                    ),
                    boxShadow: AppShadow.card,
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.primary,
                    size: 38,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Hoş geldin\nFırınNet\'e',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                Text(
                  'Sektör akışı, gruplar, ilanlar ve bayi takibi tek yerde.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                const _OnboardingHighlights(),
                const Spacer(flex: 2),
                AppPrimaryButton(
                  label: AppStrings.createProfile,
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: () => context.push(AppRoutes.createProfile),
                ),
                const SizedBox(height: AppSpacing.s),
                SizedBox(
                  height: 54,
                  child: TextButton(
                    onPressed: () {
                      ref.read(profileControllerProvider.notifier).useGuest();
                      context.go(AppRoutes.feed);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text(AppStrings.continueAsGuest),
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Kayıtsız keşfedebilir, hesabını sonra oluşturabilirsin.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingHighlights extends StatelessWidget {
  const _OnboardingHighlights();

  static const _items = <_HighlightItem>[
    _HighlightItem(
      icon: Icons.dynamic_feed_rounded,
      label: 'Fırıncılar, ustalar ve tedarikçilerle aynı akışta buluş.',
    ),
    _HighlightItem(
      icon: Icons.groups_rounded,
      label: 'Bölgen, ürün tipin veya ihtiyacın için gruplara katıl.',
    ),
    _HighlightItem(
      icon: Icons.storefront_rounded,
      label: 'Ürün, tedarik, iş ve fırsatları tek yerde takip et.',
    ),
    _HighlightItem(
      icon: Icons.receipt_long_rounded,
      label: 'Bayi, tahsilat, hareket ve gün sonunu düzenli tut.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      width: 0.6,
                    ),
                  ),
                  child: Icon(item.icon, color: AppColors.primary, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HighlightItem {
  const _HighlightItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
