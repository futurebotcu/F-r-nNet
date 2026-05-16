import 'package:flutter/material.dart';

import '../../../app/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../profile/models/bakery_profile.dart';

/// Rol bazlı dashboard kartı.
///
/// `route` doluysa kart push ile o ekrana gider; `null` ise [comingSoon]
/// `true` olur ve UI tarafı "yakında" placeholder davranışını verir.
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

/// Her rol için panel kart hiyerarşisi (V1.2 final).
///
/// Ticari: Fırın Paneli + Bayi Paneli ana modüller, sonra Hesaplama Makinesi
/// ve Reçetelerim araçlar, sonra destek (İlanlar, Mesajlar).
///
/// Bireysel: İş Arıyorum + Ustalık Bilgilerim + Çalışma Geçmişim ana iş;
/// Hesaplama + Reçeteler araçlar; sonra İş İlanları (genel), Mesajlar
/// (yakında), Profilim.
///
/// Toptancı: Müşteriler/Bayiler + ürün ilanı; profil + mesajlar.
class RolePanelCards {
  const RolePanelCards._();

  static List<PanelCard> forAccount(AccountType type) {
    switch (type) {
      case AccountType.commercial:
        return const [
          // Ana modüller
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
          // Araçlar
          PanelCard(
            label: AppStrings.cardCalculator,
            subtitle: AppStrings.cardCalculatorSub,
            icon: Icons.calculate_rounded,
            route: AppRoutes.calculator,
          ),
          PanelCard(
            label: AppStrings.cardMyRecipes,
            subtitle: AppStrings.cardMyRecipesSub,
            icon: Icons.menu_book_outlined,
            route: AppRoutes.recipes,
          ),
          // Destek
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
            route: AppRoutes.messages,
          ),
        ];

      case AccountType.individual:
        return const [
          // Ana iş — usta kendini tanıtır + iş ilanı verir
          PanelCard(
            label: AppStrings.cardPostJobSeeker,
            subtitle: AppStrings.cardPostJobSeekerSub,
            icon: Icons.campaign_outlined,
            route: AppRoutes.jobSeek,
          ),
          PanelCard(
            label: AppStrings.cardWorkerProfile,
            subtitle: AppStrings.cardWorkerProfileSub,
            icon: Icons.badge_outlined,
            route: AppRoutes.workerProfile,
          ),
          PanelCard(
            label: AppStrings.cardWorkerExperiences,
            subtitle: AppStrings.cardWorkerExperiencesSub,
            icon: Icons.history_edu_outlined,
            route: AppRoutes.workerExperiences,
          ),
          // Araçlar
          PanelCard(
            label: AppStrings.cardCalculator,
            subtitle: AppStrings.cardCalculatorSub,
            icon: Icons.calculate_rounded,
            route: AppRoutes.calculator,
          ),
          PanelCard(
            label: AppStrings.cardMyRecipes,
            subtitle: AppStrings.cardMyRecipesSub,
            icon: Icons.menu_book_outlined,
            route: AppRoutes.recipes,
          ),
          // Destek
          PanelCard(
            label: AppStrings.cardJobAds,
            subtitle: AppStrings.cardJobAdsSub,
            icon: Icons.work_outline_rounded,
            route: AppRoutes.jobs,
          ),
          PanelCard(
            label: AppStrings.cardMessages,
            subtitle: AppStrings.cardMessagesSub,
            icon: Icons.chat_bubble_outline_rounded,
            route: AppRoutes.messages,
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
          // Ana modül — müşteri yönetimi (dealers altyapısı paylaşılır)
          PanelCard(
            label: AppStrings.cardWholesaleCustomers,
            subtitle: AppStrings.cardWholesaleCustomersSub,
            icon: Icons.storefront_rounded,
            route: AppRoutes.wholesaleCustomers,
          ),
          // V1 sprint sonrası — Marketplace yayını gerçek backend'e bağlandı.
          PanelCard(
            label: AppStrings.cardPostProductListing,
            subtitle: AppStrings.cardPostProductListingSub,
            icon: Icons.add_business_outlined,
            route: AppRoutes.marketListingNew,
          ),
          PanelCard(
            label: AppStrings.cardCompanyProfile,
            subtitle: AppStrings.cardCompanyProfileSub,
            icon: Icons.business_outlined,
            route: AppRoutes.profile,
          ),
          PanelCard(
            label: AppStrings.cardIncomingMessages,
            subtitle: AppStrings.cardIncomingMessagesSub,
            icon: Icons.mark_email_unread_outlined,
            route: AppRoutes.messages,
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
