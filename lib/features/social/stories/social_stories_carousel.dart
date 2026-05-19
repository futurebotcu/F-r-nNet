// FırınNet — Donor-first stories carousel (iskelet).
//
// Donor: lib/stories/widgets/stories_carousel.dart (StoriesCarousel). Donor
// pattern: feed üstünde 124px yükseklikte yatay liste; ilk eleman "My Story"
// (own avatar + add button), ardından following users + her birinin son
// hikayesi.
//
// FırınNet V1 iskelet:
//   * "Hikayem" slot (own avatar + add icon)
//   * Following stories henüz yok — V5'te story create + view eklenecek.
//   * Tap V1'de no-op (story creation route'u yok); tooltip ile bilgilendirme.
//
// Geleneksel donor widget tree korunur, sadece tıklama davranışı V1'de
// pasif. V5'te `CreateStoriesPage` ve `StoriesPage` viewer aktive edilecek.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_provider.dart';

class SocialStoriesCarousel extends ConsumerWidget {
  const SocialStoriesCarousel({super.key});

  static const double _height = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageH,
          vertical: AppSpacing.s,
        ),
        itemCount: 1, // V1: sadece "Hikayem" slot
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.m),
        itemBuilder: (_, i) => const _MyStoryAvatar(),
      ),
    );
  }
}

class _MyStoryAvatar extends ConsumerWidget {
  const _MyStoryAvatar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final user = ref.watch(currentAuthUserProvider);
    final initial = (profile?.displayName.isNotEmpty ?? false)
        ? profile!.displayName[0].toUpperCase()
        : (user?.email?.isNotEmpty == true
            ? user!.email![0].toUpperCase()
            : 'M');
    return Tooltip(
      message: AppStrings.storiesEmptyHint,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.softGold,
                      AppColors.copper,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.elevatedCard,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.softGold.withValues(alpha: 0.16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AppColors.softGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
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
