import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../profile/models/bakery_profile.dart';

/// Signup öncesi rol seçim ekranı (V1.3).
///
/// 3 büyük rol kartı:
/// - Ticari (`commercial`)
/// - Bireysel (`individual`)
/// - Toptancı (`wholesaler`)
///
/// Seçim sonrası `/profile/create?role=<role>` push edilir.
class RoleSelectScreen extends ConsumerWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return PremiumScaffold(
      appBar: AppBar(
        title: const Text(AppStrings.authEntrySignUp),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.l,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              AppStrings.roleSelectTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              AppStrings.roleSelectSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _RoleCard(
              icon: Icons.storefront_rounded,
              title: AppStrings.roleCommercialTitle,
              subtitle: AppStrings.roleCommercialSub,
              onTap: () => _pick(context, AccountType.commercial),
            ),
            const SizedBox(height: AppSpacing.m),
            _RoleCard(
              icon: Icons.person_rounded,
              title: AppStrings.roleIndividualTitle,
              subtitle: AppStrings.roleIndividualSub,
              onTap: () => _pick(context, AccountType.individual),
            ),
            const SizedBox(height: AppSpacing.m),
            _RoleCard(
              icon: Icons.local_shipping_rounded,
              title: AppStrings.roleWholesalerTitle,
              subtitle: AppStrings.roleWholesalerSub,
              onTap: () => _pick(context, AccountType.wholesaler),
            ),
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext context, AccountType type) {
    context.push('${AppRoutes.createProfile}?role=${type.name}');
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.copper.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(
                color: AppColors.copper.withValues(alpha: 0.32),
                width: 0.6,
              ),
            ),
            child: Icon(icon, color: AppColors.softGold, size: 26),
          ),
          const SizedBox(width: AppSpacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.softGold,
            size: 22,
          ),
        ],
      ),
    );
  }
}
