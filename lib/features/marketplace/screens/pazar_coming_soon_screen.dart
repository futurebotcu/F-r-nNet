// Navigation IA Sprint — Pazar sekmesi "Yakında" yüzeyi.
//
// Pazar şimdilik aktif B2B modül DEĞİL. Boş/yarım ekran yerine modern, sade,
// şeffaf bir coming-soon: B2B tedarik + teklif ağı vizyonunu anlatır, "Yakında"
// rozeti taşır. Backend/fake data YOK — yalnız bilgilendirme yüzeyi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../notifications/widgets/notifications_header_action.dart';

class PazarComingSoonScreen extends ConsumerWidget {
  const PazarComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const FirinNetHeader(
              title: AppStrings.navPazar,
              subtitle: AppStrings.marketSubtitle,
              actions: [NotificationsHeaderAction()],
            ),
            const Divider(height: 1, color: AppColors.borderHairline),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  AppSpacing.xl,
                  AppSpacing.pageH,
                  AppSpacing.xxl,
                ),
                children: const [
                  _Hero(),
                  SizedBox(height: AppSpacing.xl),
                  _Bullet(
                    icon: Icons.storefront_rounded,
                    title: AppStrings.pazarBulletSuppliersTitle,
                    body: AppStrings.pazarBulletSuppliersBody,
                  ),
                  SizedBox(height: AppSpacing.m),
                  _Bullet(
                    icon: Icons.request_quote_rounded,
                    title: AppStrings.pazarBulletOffersTitle,
                    body: AppStrings.pazarBulletOffersBody,
                  ),
                  SizedBox(height: AppSpacing.m),
                  _Bullet(
                    icon: Icons.campaign_rounded,
                    title: AppStrings.pazarBulletCampaignsTitle,
                    body: AppStrings.pazarBulletCampaignsBody,
                  ),
                  SizedBox(height: AppSpacing.xl),
                  _Footnote(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      warm: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandLemonPale,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                  border: Border.all(
                    color: AppColors.brandLemonSoft,
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  color: AppColors.brandLemonPressed,
                  size: 26,
                ),
              ),
              const Spacer(),
              const _ComingSoonBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            AppStrings.pazarComingTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            AppStrings.pazarComingSubtitle,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandLemonPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Text(
        AppStrings.pazarComingBadge,
        style: TextStyle(
          color: AppColors.brandInk,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: Icon(icon, color: AppColors.brandInk, size: 20),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Text(
            AppStrings.pazarComingFootnote,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
