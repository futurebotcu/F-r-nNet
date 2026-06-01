import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';

class JobOpportunityCard extends StatelessWidget {
  const JobOpportunityCard({
    super.key,
    required this.position,
    required this.business,
    required this.city,
    required this.salary,
    required this.experience,
    required this.badge,
    this.shift,
    this.featured = false,
    this.onApply,
    this.applyLabel,
    this.applyIcon,
    this.applyEnabled = true,
  });

  final String position;
  final String business;
  final String city;
  final String salary;
  final String experience;
  final String badge;
  final String? shift;
  final bool featured;

  /// Parent callback. `null` ise CTA gizlenir (sessiz snackbar yerine
  /// dürüst davranış — parent açıkça "bu kart için aksiyon yok" diyor).
  final VoidCallback? onApply;

  /// Default `AppStrings.jobsApply` ("Başvur"). Job seek kartı için
  /// "İletişime geç" geçilir.
  final String? applyLabel;

  /// Default `Icons.send_rounded`. Job seek için chat ikonu da geçilebilir.
  final IconData? applyIcon;

  /// `false` ise buton görünür ama disabled (örn. kendi ilanı / closed).
  final bool applyEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: featured ? AppColors.elevatedCard : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.l),
        // İş İlanları Polish V1 — daha yumuşak/rafine hairline (P0 dili).
        border: Border.all(
          color: featured
              ? AppColors.copper.withValues(alpha: 0.32)
              : AppColors.borderHairline.withValues(alpha: 0.7),
          width: featured ? 0.8 : 0.6,
        ),
        boxShadow: featured ? AppShadow.copper : AppShadow.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.copper.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  border: featured
                      ? Border.all(
                          color: AppColors.copper.withValues(alpha: 0.3),
                          width: 0.6,
                        )
                      : null,
                ),
                child: const Icon(
                  Icons.bakery_dining_rounded,
                  color: AppColors.softGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      position,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.2,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      business,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.softGold,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.borderHairline,
                    width: 0.6,
                  ),
                ),
                child: Text(
                  badge,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Row(
            children: [
              _Tag(icon: Icons.place_outlined, label: city),
              const SizedBox(width: AppSpacing.s),
              _Tag(icon: Icons.payments_outlined, label: salary),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              _Tag(
                  icon: Icons.workspace_premium_outlined, label: experience),
              const SizedBox(width: AppSpacing.s),
              _Tag(
                icon: Icons.schedule_rounded,
                label: shift ?? '—',
              ),
            ],
          ),
          // V1 — Job messaging gerçek oldu: onApply parent'tan geçilir.
          // Parent vermezse CTA hiç render edilmez (boş snackbar/no-op yok).
          if (onApply != null) ...[
            const SizedBox(height: AppSpacing.l),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: applyEnabled ? onApply : null,
                icon: Icon(applyIcon ?? Icons.send_rounded, size: 16),
                label: Text(applyLabel ?? AppStrings.jobsApply),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.copper,
                  foregroundColor: Colors.white,
                  // İş İlanları Polish V1 — global buton radius standardı (m).
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.s),
          border: Border.all(
            color: AppColors.borderHairline,
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.softGold),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
