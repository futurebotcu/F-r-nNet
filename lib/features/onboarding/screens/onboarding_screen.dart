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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.copper, AppColors.copperMuted],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.copper.withValues(alpha: 0.32),
                      blurRadius: 32,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppStrings.onboardingTitle,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                AppStrings.onboardingSubtitle,
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
                AppStrings.onboardingFooter,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
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
      icon: Icons.bakery_dining_rounded,
      label: 'Atölyenden anlık paylaş',
    ),
    _HighlightItem(
      icon: Icons.storefront_rounded,
      label: 'Tedarikçi ve ekipman ağı',
    ),
    _HighlightItem(
      icon: Icons.summarize_rounded,
      label: 'Gün sonu cebinde, tek tap',
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
                    color: AppColors.softGold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon,
                      color: AppColors.softGold, size: 17),
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
