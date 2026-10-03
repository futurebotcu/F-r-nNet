import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/firinnet_avatar.dart';
import '../../widgets/social_skeletons.dart';
import '../../../profile/models/public_profile_detail.dart';
import '../../models/social_profile.dart';

/// Donor (itsezlife) `user_profile_header.dart` pattern — avatar + name +
/// role badge + city + (kendi profilinde "Bu senin profilin" rozet).
///
/// V1 Profile Social Sprint — opsiyonel `detailAsync` ile avatar_url ve
/// worker fallback'li `effectiveProfessionBadge` desteklenir. Eski snapshot
/// hâlâ displayName + initial için authoritative.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profileAsync,
    required this.isSelf,
    this.detailAsync,
  });

  final AsyncValue<SocialProfile> profileAsync;
  final AsyncValue<PublicProfileDetail?>? detailAsync;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.l,
        AppSpacing.pageH,
        AppSpacing.m,
      ),
      child: profileAsync.when(
        loading: () => const _ProfileHeaderSkeleton(),
        error: (_, __) => const Text(
          AppStrings.publicProfileLoadError,
          style: AppTypography.body,
        ),
        data: (p) {
          final detail = detailAsync?.asData?.value;
          final avatarUrl = detail?.header.avatarUrl;
          final role = detail?.effectiveProfessionBadge ?? p.professionBadge;
          // M6A — code → label çevirimi (effectiveCity) öncelikli; snapshot
          // RPC eski text fallback.
          final city = detail?.header.effectiveCity ?? p.city;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ortak avatar: gerçek fotoğraf (ekran boyutunda decode,
              // memCacheWidth içeride) → yoksa/bozuksa baş harfler.
              FirinNetAvatar(
                key: const ValueKey('profile_header_avatar'),
                name: p.displayNameOrFallback,
                imageUrl: avatarUrl,
                size: FirinNetAvatarSize.xl,
                kind:
                    const {
                      'commercial',
                      'wholesaler',
                    }.contains(detail?.header.accountType)
                    ? FirinNetAvatarKind.business
                    : FirinNetAvatarKind.person,
              ),
              const SizedBox(width: AppSpacing.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.displayNameOrFallback,
                      style: AppTypography.detailTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (role != null && role.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        role,
                        // Rol/meslek: meta rolü, bir ton koyu (şehirden önce).
                        style: AppTypography.meta.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (city != null && city.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              city,
                              style: AppTypography.meta.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Bio header'da DEĞİL — ayrı "Hakkımda" bölümünde
                    // (ProfileAboutSection). Header sade: ad/meslek/şehir.
                    if (isSelf) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.m,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.softGold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: AppColors.softGold.withValues(alpha: 0.36),
                            width: 0.6,
                          ),
                        ),
                        child: const Text(
                          AppStrings.publicProfileSelfHint,
                          style: AppTypography.badge,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// İlk yükleme: statik iskelet (avatar + üç çubuk), spinner yok.
class _ProfileHeaderSkeleton extends StatelessWidget {
  const _ProfileHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('profile_header_skeleton'),
      children: [
        Container(
          width: FirinNetAvatarSize.xl,
          height: FirinNetAvatarSize.xl,
          decoration: const BoxDecoration(
            color: AppColors.surfaceLine,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.l),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBar(width: 160, height: 18),
              SizedBox(height: 10),
              SkeletonBar(width: 110),
              SizedBox(height: 8),
              SkeletonBar(width: 80, height: 10),
            ],
          ),
        ),
      ],
    );
  }
}
