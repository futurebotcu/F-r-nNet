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

class SocialStoriesCarousel extends ConsumerWidget {
  const SocialStoriesCarousel({super.key});

  static const double _height = 104;

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
    final initial = (profile?.displayName.isNotEmpty ?? false)
        ? profile!.displayName[0].toUpperCase()
        : (user?.email?.isNotEmpty == true
            ? user!.email![0].toUpperCase()
            : 'M');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.softGold.withValues(alpha: 0.16),
                  border: Border.all(
                    color: AppColors.softGold.withValues(alpha: 0.32),
                    width: 0.8,
                  ),
                  boxShadow: AppShadow.subtle,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.copper,
                    border: Border.all(
                      color: AppColors.elevatedCard,
                      width: 1.6,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            AppStrings.storiesMyStoryLabel,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11.5,
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
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // FırınNet bakery halkası — sıcak bakır→buğday gradient ring
            // (Instagram gökkuşağı değil). Dış gradient + iç krem boşluk.
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(2.4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.copper, AppColors.copperMuted],
                ),
                boxShadow: AppShadow.subtle,
              ),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.softGold.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppColors.card,
                    width: 1.6,
                  ),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
