import 'package:flutter/material.dart';

import '../../../app/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../profile/models/bakery_profile.dart';

/// Rol bazlı dashboard kartının ne yapacağını anlatan tek satır.
///
/// `route` doluysa kart push ile o ekrana gider; `null` ise [comingSoon]
/// `true` olur ve UI tarafı "yakında" placeholder davranışını verir.
/// Bu ayrım, ileride Supabase'e bağlanırken kart-eylem map'ini tek bir
/// JSON kaynaktan beslemeyi kolaylaştırıyor.
class PanelCard {
  const PanelCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    this.route,
    this.comingSoon = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final String? route;
  final bool comingSoon;
}

/// Her rol için 4 büyük dashboard aksiyonu.
///
/// Ortak akış (Feed / Gruplar / Market / İlanlar) zaten alt tab'larda;
/// burada sadece "Panel" tab'ı içinde gösterilen rol-özgü kısayollar var.
/// İleride Supabase'e geçişte bu mapping'i `account_type -> panel_cards`
/// olarak konfigürasyon tablosuna taşımak yeterli olacak.
class RolePanelCards {
  const RolePanelCards._();

  static List<PanelCard> forAccount(AccountType type) {
    switch (type) {
      case AccountType.commercial:
        return const [
          PanelCard(
            label: AppStrings.cardBakeryPanel,
            subtitle: AppStrings.cardBakeryPanelSub,
            icon: Icons.local_fire_department_rounded,
            route: AppRoutes.bakeryPanel,
          ),
          PanelCard(
            label: AppStrings.cardDealerPanel,
            subtitle: AppStrings.cardDealerPanelSub,
            icon: Icons.storefront_rounded,
            route: AppRoutes.dealers,
          ),
          PanelCard(
            label: AppStrings.cardMyRecipes,
            subtitle: AppStrings.cardMyRecipesSub,
            icon: Icons.menu_book_outlined,
            route: AppRoutes.recipes,
          ),
          PanelCard(
            label: AppStrings.cardMyListings,
            subtitle: AppStrings.cardMyListingsSub,
            icon: Icons.work_outline_rounded,
            route: AppRoutes.jobs,
          ),
          PanelCard(
            label: AppStrings.cardMessages,
            subtitle: AppStrings.cardMessagesSub,
            icon: Icons.chat_bubble_outline_rounded,
            comingSoon: true,
          ),
        ];
      case AccountType.individual:
        return const [
          PanelCard(
            label: AppStrings.cardJobAds,
            subtitle: AppStrings.cardJobAdsSub,
            icon: Icons.work_outline_rounded,
            route: AppRoutes.jobs,
          ),
          PanelCard(
            label: AppStrings.cardMyRecipes,
            subtitle: AppStrings.cardMyRecipesSub,
            icon: Icons.menu_book_outlined,
            route: AppRoutes.recipes,
          ),
          PanelCard(
            label: AppStrings.cardPostJobSeeker,
            subtitle: AppStrings.cardPostJobSeekerSub,
            icon: Icons.campaign_outlined,
            comingSoon: true,
          ),
          PanelCard(
            label: AppStrings.cardMessages,
            subtitle: AppStrings.cardMessagesSub,
            icon: Icons.chat_bubble_outline_rounded,
            comingSoon: true,
          ),
          PanelCard(
            label: AppStrings.cardMyProfile,
            subtitle: AppStrings.cardMyProfileSub,
            icon: Icons.person_outline_rounded,
            route: AppRoutes.profile,
          ),
        ];
      case AccountType.wholesaler:
        return const [
          PanelCard(
            label: AppStrings.cardPostProductListing,
            subtitle: AppStrings.cardPostProductListingSub,
            icon: Icons.add_business_outlined,
            route: AppRoutes.market,
          ),
          PanelCard(
            label: AppStrings.cardIncomingMessages,
            subtitle: AppStrings.cardIncomingMessagesSub,
            icon: Icons.mark_email_unread_outlined,
            comingSoon: true,
          ),
          PanelCard(
            label: AppStrings.cardCompanyProfile,
            subtitle: AppStrings.cardCompanyProfileSub,
            icon: Icons.business_outlined,
            route: AppRoutes.profile,
          ),
          PanelCard(
            label: AppStrings.cardPriceAnnouncements,
            subtitle: AppStrings.cardPriceAnnouncementsSub,
            icon: Icons.price_change_outlined,
            comingSoon: true,
          ),
        ];
    }
  }

  /// Greeting alt başlığı — role özgü.
  static String subtitleFor(AccountType type) {
    switch (type) {
      case AccountType.commercial:
        return AppStrings.panelRoleSubCommercial;
      case AccountType.individual:
        return AppStrings.panelRoleSubIndividual;
      case AccountType.wholesaler:
        return AppStrings.panelRoleSubWholesaler;
    }
  }
}
