// FırınNet Feed Boundary V1 — premium yönlendirme sheet'i.
//
// Composer publish'i boundary'ye takıldığında kaba bir "yasak" yerine
// kaliteli açıklama + doğru alana CTA gösterilir. Metin asla silinmez;
// "Metni düzenle" composer'a (text korunmuş halde) geri döner.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../services/feed_boundary_classifier.dart';

/// Sheet sonucu.
enum FeedBoundaryAction { edit, redirected, cancelled }

/// Kategori → copy + CTA route eşlemesi.
class _BoundaryCopy {
  const _BoundaryCopy({
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.ctaRoute,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final String? ctaRoute;
}

_BoundaryCopy _copyFor(FeedBoundaryResult result) {
  switch (result.destination) {
    case FeedBoundaryDestination.market:
      return const _BoundaryCopy(
        icon: Icons.storefront_rounded,
        title: AppStrings.boundaryCommercialTitle,
        body: AppStrings.boundaryCommercialBody,
        ctaLabel: AppStrings.boundaryCommercialCta,
        ctaRoute: AppRoutes.market,
      );
    case FeedBoundaryDestination.jobListings:
      return const _BoundaryCopy(
        icon: Icons.badge_rounded,
        title: AppStrings.boundaryJobTitle,
        body: AppStrings.boundaryJobBody,
        ctaLabel: AppStrings.boundaryJobCta,
        ctaRoute: AppRoutes.jobOfferNew,
      );
    case FeedBoundaryDestination.jobSeekListing:
      return const _BoundaryCopy(
        icon: Icons.handshake_rounded,
        title: AppStrings.boundaryJobSeekTitle,
        body: AppStrings.boundaryJobSeekBody,
        ctaLabel: AppStrings.boundaryJobSeekCta,
        ctaRoute: AppRoutes.jobSeekNew,
      );
    case FeedBoundaryDestination.workplaceListings:
      // Deep preselect (listing_type=bakery_transfer) P1 — form route mevcut.
      return const _BoundaryCopy(
        icon: Icons.store_mall_directory_rounded,
        title: AppStrings.boundaryWorkplaceTitle,
        body: AppStrings.boundaryWorkplaceBody,
        ctaLabel: AppStrings.boundaryWorkplaceCta,
        ctaRoute: AppRoutes.marketListingNew,
      );
    case FeedBoundaryDestination.equipmentListings:
      // Deep preselect (listing_type=equipment_sale) P1.
      return const _BoundaryCopy(
        icon: Icons.precision_manufacturing_rounded,
        title: AppStrings.boundaryEquipmentTitle,
        body: AppStrings.boundaryEquipmentBody,
        ctaLabel: AppStrings.boundaryEquipmentCta,
        ctaRoute: AppRoutes.marketListingNew,
      );
    case FeedBoundaryDestination.safetyRewrite:
      return result.category == FeedBoundaryCategory.scamOrIllegal
          ? const _BoundaryCopy(
              icon: Icons.gpp_maybe_rounded,
              title: AppStrings.boundaryScamTitle,
              body: AppStrings.boundaryScamBody,
            )
          : const _BoundaryCopy(
              icon: Icons.sentiment_satisfied_alt_rounded,
              title: AppStrings.boundaryProfanityTitle,
              body: AppStrings.boundaryProfanityBody,
            );
    case FeedBoundaryDestination.feedAllowed:
      // Çağıran allowed sonuçta sheet açmaz; güvenli fallback.
      return const _BoundaryCopy(
        icon: Icons.info_outline_rounded,
        title: AppStrings.boundaryWhyLabel,
        body: AppStrings.boundaryWhyBody,
      );
  }
}

/// Boundary sheet'ini açar; kullanıcının seçimini döner.
/// CTA seçilirse ilgili route'a push edilir ve [FeedBoundaryAction.redirected]
/// döner — çağıran feed post OLUŞTURMAZ, composer metni korunur.
Future<FeedBoundaryAction> showFeedBoundarySheet(
  BuildContext context,
  FeedBoundaryResult result,
) async {
  final copy = _copyFor(result);
  final action = await showModalBottomSheet<FeedBoundaryAction>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppColors.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brandLemonPale,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(
                      color:
                          AppColors.brandLemonPressed.withValues(alpha: 0.4),
                      width: 0.6,
                    ),
                  ),
                  child: Icon(copy.icon, size: 24, color: AppColors.brandInk),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Text(
                    copy.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                      letterSpacing: -0.2,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              copy.body,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            // "Neden Feed'de değil?" — yönlendirme kategorilerinde küçük not.
            if (copy.ctaRoute != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      AppStrings.boundaryWhyLabel,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      AppStrings.boundaryWhyBody,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.m),
            ],
            if (copy.ctaLabel != null)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(ctx).pop(FeedBoundaryAction.redirected),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(copy.ctaLabel!),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.copper,
                    foregroundColor: AppColors.brandInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            if (copy.ctaLabel != null) const SizedBox(height: AppSpacing.s),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(FeedBoundaryAction.edit),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(
                    color: AppColors.borderHairline,
                    width: 0.8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
                child: const Text(
                  AppStrings.boundaryEditCta,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(FeedBoundaryAction.cancelled),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                child: const Text(
                  AppStrings.boundaryCancelCta,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  final resolved = action ?? FeedBoundaryAction.cancelled;
  if (resolved == FeedBoundaryAction.redirected &&
      copy.ctaRoute != null &&
      context.mounted) {
    context.push(copy.ctaRoute!);
  }
  return resolved;
}
