import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_strings.dart';
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
        loading: () => const SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const Text(
          AppStrings.publicProfileLoadError,
          style: TextStyle(color: AppColors.textSecondary),
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
              _Avatar(avatarUrl: avatarUrl, initial: p.initial),
              const SizedBox(width: AppSpacing.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.displayNameOrFallback,
                      style: AppTypography.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (role != null && role.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        role,
                        style: const TextStyle(
                          color: AppColors.softGold,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (city != null && city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              city,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
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
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: AppColors.softGold.withValues(alpha: 0.36),
                            width: 0.6,
                          ),
                        ),
                        child: const Text(
                          AppStrings.publicProfileSelfHint,
                          style: TextStyle(
                            color: AppColors.softGold,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, required this.initial});

  final String? avatarUrl;
  final String initial;

  @override
  Widget build(BuildContext context) {
    const double size = 72;
    final borderRadius = BorderRadius.circular(AppRadius.l);
    final hasUrl = avatarUrl != null && avatarUrl!.isNotEmpty;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // copper → softGold sıcak ramp; beyaz initial ile yüksek kontrast.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.copper, AppColors.softGold],
        ),
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 32,
        ),
      ),
    );
    final inner = hasUrl
        ? ClipRRect(
            borderRadius: borderRadius,
            child: CachedNetworkImage(
              imageUrl: avatarUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            ),
          )
        : fallback;
    // İnce hairline çerçeve + çok yumuşak gölge ile premium yükseliş.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
        boxShadow: AppShadow.subtle,
      ),
      child: inner,
    );
  }
}
