import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/firinnet_avatar.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../widgets/social_skeletons.dart';
import '../../academy/academy_navigation.dart';
import '../../academy/providers/academy_providers.dart';
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
    // Bot haritası tap anında hazır olsun (autoDispose → izlenmeli); bot
    // satırları Akademi avatarıyla çizilir.
    final bots = ref.watch(academyBotsByIdProvider).valueOrNull ?? const {};
    final idsAsync = switch (kind) {
      UserListKind.followers => ref.watch(socialFollowersIdsProvider(userId)),
      UserListKind.following => ref.watch(socialFollowingIdsProvider(userId)),
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
          loading: () => const SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: SocialListSkeleton(
              key: ValueKey('user_list_skeleton'),
              card: false,
              count: 8,
            ),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.all(AppSpacing.l),
            child: Center(
              child: Text(
                AppStrings.publicProfileLoadError,
                style: AppTypography.body,
              ),
            ),
          ),
          data: (ids) {
            if (ids.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Center(
                  child: Text(emptyText, style: AppTypography.body),
                ),
              );
            }
            // Profil snapshot'larını batch ile al.
            final profilesAsync = ref.watch(socialProfilesBatchProvider(ids));
            return profilesAsync.when(
              loading: () => const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: SocialListSkeleton(
                  key: ValueKey('user_list_skeleton'),
                  card: false,
                  count: 8,
                ),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(AppSpacing.l),
                child: Center(
                  child: Text(
                    AppStrings.publicProfileLoadError,
                    style: AppTypography.body,
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
                separatorBuilder: (_, __) =>
                    const Divider(height: 0, color: AppColors.borderHairline),
                itemBuilder: (_, i) {
                  final id = ids[i];
                  final p = byId[id] ?? SocialProfile(id: id);
                  final bot = bots[id];
                  return _UserTile(
                    profile: p,
                    isAcademyBot: bot != null && !bot.isHumor,
                    // Akademi botu → toplu Akademi sayfası (bot adı ekran
                    // başlığı olmaz).
                    onTap: () => openUserProfileOrAcademy(context, ref, id),
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
  const _UserTile({
    required this.profile,
    required this.onTap,
    this.isAcademyBot = false,
  });

  final SocialProfile profile;
  final bool isAcademyBot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: FirinNetAvatar(
        name: profile.displayNameOrFallback,
        size: FirinNetAvatarSize.m,
        kind: isAcademyBot
            ? FirinNetAvatarKind.academy
            : FirinNetAvatarKind.person,
      ),
      title: Text(
        profile.displayNameOrFallback,
        style: AppTypography.authorName,
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
    return Text(parts.join(' · '), style: AppTypography.meta);
  }
}
