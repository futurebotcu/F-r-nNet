import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../models/social_profile.dart';

/// Donor (itsezlife) `user_profile_header.dart` pattern — avatar + name +
/// role badge + city + (kendi profilinde "Bu senin profilin" rozet).
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profileAsync,
    required this.isSelf,
  });

  final AsyncValue<SocialProfile> profileAsync;
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
          final role = p.professionBadge;
          final city = p.city;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.softGold, AppColors.copperMuted],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                alignment: Alignment.center,
                child: Text(
                  p.initial,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.displayNameOrFallback,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        letterSpacing: -0.3,
                      ),
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
