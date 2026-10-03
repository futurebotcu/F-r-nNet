// FırınNet Social V2 Commit 2 — Stories carousel (aktif).
//
// Donor: lib/stories/widgets/stories_carousel.dart. FırınNet adaptasyonu:
//   * Donor `UserStoriesAvatar` (gradient story ring) ALMA — kullanıcı
//     kararı: Instagram gradient ring zorlaması istemiyoruz.
//   * Sade FırınNet kart: avatar + isim + ince halka (var olduğunda).
//   * Aktif story yoksa carousel **gizlenir** (story row ekran şişirmez).
//   * "Hikayem" slotu hep görünür (auth varsa create push, guest CTA).
//   * Tıklama:
//       - "Hikayem" → /social/stories/create (auth gerekli)
//       - Bir kullanıcı avatarı → /social/stories/viewer?ownerId=...

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/social_profile.dart';
import '../providers/social_providers.dart';
import 'models/social_story.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/firinnet_avatar.dart';

class SocialStoriesCarousel extends ConsumerWidget {
  const SocialStoriesCarousel({super.key});

  static const double _height = 92;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAuthUserProvider);
    final storiesAsync = ref.watch(socialFreshStoriesProvider);
    final stories = storiesAsync.maybeWhen(
      data: (l) => l,
      orElse: () => const <SocialStory>[],
    );

    // Distinct owner list newest first — her kullanıcı carousel'de tek
    // avatar olarak görünür.
    final seen = <String>{};
    final distinctOwners = <SocialStory>[];
    for (final s in stories) {
      if (seen.add(s.ownerId)) distinctOwners.add(s);
    }

    // Aktif story yok + auth'lu kullanıcı yok → carousel hiç gösterme
    // (ekran şişirme yok). Auth varsa "Hikayem" slot'unu göster.
    if (distinctOwners.isEmpty && user == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageH,
          vertical: AppSpacing.s,
        ),
        // +1: "Hikayem" slot (auth'lu kullanıcı varsa) en başta.
        itemCount: (user != null ? 1 : 0) + distinctOwners.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.m),
        itemBuilder: (_, i) {
          if (user != null && i == 0) {
            // V1 P0 — Senin Hikayen slot: create page'e push.
            return _MyStorySlot(
              onTap: () {
                if (!AuthRequiredGuard.canWriteWithRef(ref)) {
                  showAuthRequiredSheet(context, ref);
                  return;
                }
                context.push(AppRoutes.storyCreate);
              },
            );
          }
          final offset = user != null ? i - 1 : i;
          final story = distinctOwners[offset];
          return _OwnerStorySlot(
            ownerId: story.ownerId,
            onTap: () => context.push(
              '${AppRoutes.storyViewer}?ownerId=${story.ownerId}',
            ),
          );
        },
      ),
    );
  }
}

class _MyStorySlot extends ConsumerWidget {
  const _MyStorySlot({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final user = ref.watch(currentAuthUserProvider);
    final myName = (profile?.displayName.isNotEmpty ?? false)
        ? profile!.displayName
        : (user?.email ?? '');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              FirinNetAvatar(
                name: myName,
                imageUrl: profile?.avatarUrl,
                size: 54,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandLemonPressed,
                    border: Border.all(
                      color: AppColors.elevatedCard,
                      width: 1.6,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.brandInk,
                    size: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.storiesMyStoryLabel,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerStorySlot extends ConsumerWidget {
  const _OwnerStorySlot({required this.ownerId, required this.onTap});
  final String ownerId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(socialProfileProvider(ownerId));
    final name = profileAsync.maybeWhen(
      data: (p) => p.displayNameOrFallback,
      orElse: () => SocialProfile.fallbackName,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium lemon accent ring; clean social identity.
            Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(2.4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandLemonPale, AppColors.brandLemonSoft],
                ),
                boxShadow: AppShadow.subtle,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.card, width: 1.6),
                ),
                child: FirinNetAvatar(name: name, size: 46),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
