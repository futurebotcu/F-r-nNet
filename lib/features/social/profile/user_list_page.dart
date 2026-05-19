import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/social_profile.dart';
import '../providers/social_providers.dart';

/// FırınNet Social — Followers / Following list page (donor-first F2).
///
/// Donor (itsezlife) `user_profile_followers.dart` + `_followings.dart`
/// pattern'ından port. Tek widget iki mod (`UserListKind.followers` /
/// `.following`); aynı list + tap-to-profile davranışı.
enum UserListKind { followers, following }

class SocialUserListPage extends ConsumerWidget {
  const SocialUserListPage({
    super.key,
    required this.userId,
    required this.kind,
  });

  final String userId;
  final UserListKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idsAsync = switch (kind) {
      UserListKind.followers =>
        ref.watch(socialFollowersIdsProvider(userId)),
      UserListKind.following =>
        ref.watch(socialFollowingIdsProvider(userId)),
    };
    final title = kind == UserListKind.followers
        ? AppStrings.followersListTitle
        : AppStrings.followingListTitle;
    final emptyText = kind == UserListKind.followers
        ? AppStrings.followersEmpty
        : AppStrings.followingEmpty;
    return PremiumScaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: idsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Padding(
            padding: EdgeInsets.all(AppSpacing.l),
            child: Center(
              child: Text(
                AppStrings.publicProfileLoadError,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          data: (ids) {
            if (ids.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Center(
                  child: Text(
                    emptyText,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }
            // Profil snapshot'larını batch ile al.
            final profilesAsync = ref.watch(socialProfilesBatchProvider(ids));
            return profilesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(AppSpacing.l),
                child: Center(
                  child: Text(
                    AppStrings.publicProfileLoadError,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              data: (byId) => ListView.separated(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                  vertical: AppSpacing.s,
                ),
                itemCount: ids.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 0,
                  color: AppColors.borderHairline,
                ),
                itemBuilder: (_, i) {
                  final id = ids[i];
                  final p = byId[id] ?? SocialProfile(id: id);
                  return _UserTile(
                    profile: p,
                    onTap: () => context.push(
                      '${AppRoutes.userPublicProfile}/$id',
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.profile, required this.onTap});

  final SocialProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.softGold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
        alignment: Alignment.center,
        child: Text(
          profile.initial,
          style: const TextStyle(
            color: AppColors.softGold,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(
        profile.displayNameOrFallback,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _buildSubtitle(profile),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
        size: 20,
      ),
    );
  }

  Widget? _buildSubtitle(SocialProfile p) {
    final parts = <String>[
      if (p.professionBadge?.isNotEmpty == true) p.professionBadge!,
      if (p.city?.isNotEmpty == true) p.city!,
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
      ),
    );
  }
}
