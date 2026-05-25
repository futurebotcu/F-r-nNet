import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../profile/providers/profile_provider.dart';

/// Feed üstünde görünen "Ne paylaşmak istersin?" inline composer kartı
/// (Social UI Polish Sprint 1). Avatar + placeholder + 3 hızlı tip ikon
/// (Fotoğraf / Soru / Üretim). Kart veya ikon tap'i mevcut composer
/// route'una gider (preselect type Sprint 2'ye ertelendi).
///
/// Guest tap: `runGuardedMutation` paterniyle auth required sheet açılır.
/// FAB ile birlikte yaşar — alternatif giriş yolu.
class InlineComposerCard extends ConsumerWidget {
  const InlineComposerCard({super.key});

  Future<void> _openComposer(BuildContext context, WidgetRef ref) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    if (!context.mounted) return;
    context.push(AppRoutes.socialComposer);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final initial = (profile?.displayName.isNotEmpty ?? false)
        ? profile!.displayName[0].toUpperCase()
        : 'M';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.s,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openComposer(context, ref),
          borderRadius: BorderRadius.circular(AppRadius.l),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.s,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.l),
              border: Border.all(
                color: AppColors.borderHairline,
                width: 0.6,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.softGold.withValues(alpha: 0.14),
                        border: Border.all(
                          color: AppColors.softGold.withValues(alpha: 0.28),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: AppColors.softGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    const Expanded(
                      child: Text(
                        AppStrings.feedComposerInlinePlaceholder,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                const Divider(
                  height: 0.6,
                  thickness: 0.6,
                  color: AppColors.borderHairline,
                ),
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: [
                    Expanded(
                      child: _ComposerQuickTile(
                        icon: Icons.photo_camera_outlined,
                        label: AppStrings.feedComposerInlineCtaPhoto,
                        onTap: () => _openComposer(context, ref),
                      ),
                    ),
                    Expanded(
                      child: _ComposerQuickTile(
                        icon: Icons.help_outline_rounded,
                        label: AppStrings.feedComposerInlineCtaQuestion,
                        onTap: () => _openComposer(context, ref),
                      ),
                    ),
                    Expanded(
                      child: _ComposerQuickTile(
                        icon: Icons.bakery_dining_rounded,
                        label: AppStrings.feedComposerInlineCtaProduction,
                        onTap: () => _openComposer(context, ref),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerQuickTile extends StatelessWidget {
  const _ComposerQuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.s),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s,
            horizontal: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.softGold),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
