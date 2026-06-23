import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_bottom_nav.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/dealer_providers.dart';
import 'dealer_activity_screen.dart';
import 'dealer_list_screen.dart';
import 'dealer_overview_screen.dart';
import 'dealer_reports_tab_screen.dart';
import 'driver_home_screen.dart';
import 'driver_list_screen.dart';

/// Bayi Defteri mini-app shell (Sprint 6A).
///
/// `/dealers` root route'unun yeni builder'ı. İçinde 5 tab + bottom
/// navigation barındırır. Default tab **Genel Bakış** (mini-app ana
/// sayfası hissi için); ikinci tab **Bayiler** mevcut
/// [DealerListScreen]'i olduğu gibi embedler.
///
/// Toptancı kullanıcı shell'e hiç girmez — üst seviye redirect mevcut
/// [DealerListScreen]'in defansif redirect'iyle aynı pattern'i kullanır
/// (post-frame `context.go(AppRoutes.wholesaleCustomers)`).
///
/// Sprint 6A kapsamı: shell skeleton + tab placeholder'lar. Genel
/// Bakış içeriği (KPI tile + hızlı eylem + son hareketler) Sprint 6B,
/// ilk donor lift (cashier_calculator) Sprint 6C.
class DealerShellScreen extends ConsumerWidget {
  const DealerShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountType = ref.watch(
      profileControllerProvider.select((p) => p?.accountType),
    );
    final isIndividual = accountType == AccountType.individual;
    final isWholesaler = accountType == AccountType.wholesaler;
    // Patron = commercial / wholesaler → Şoförler (şoför yönetimi) tabı + owner
    // yetkileri. Bireysel kullanıcı ASLA patron değildir.
    final isPatron = accountType == AccountType.commercial || isWholesaler;

    // Bireysel: "kendi verisi var mı?" + "aktif şoför mü?" sorguları çözülene
    // kadar bekle → mode (owner ↔ driverScoped) flash'ı önlenir.
    if (isIndividual) {
      final hasData = ref.watch(individualHasOwnLedgerDataProvider);
      final driverStatus = ref.watch(individualActiveDriverProvider);
      final stillLoading = (hasData.isLoading && !hasData.hasValue) ||
          (driverStatus.isLoading && !driverStatus.hasValue);
      if (stillLoading) {
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator()),
        );
      }
    }

    // mode: bireysel + AKTİF şoför → driverScoped (atanmış bayiler scoped
    // defter); bireysel + şoför DEĞİL → owner (kişisel defter); patron → owner.
    final driverScoped =
        ref.watch(dealerShellModeProvider) == DealerShellMode.driverScoped;

    // Savunma: driverScoped (aktif şoför) ama atanmış bayi/şoför kaydı henüz
    // görünmüyorsa davet/boş şoför ekranı. (Normalde driverScoped ⇒ atama var.)
    if (driverScoped) {
      final assigned =
          ref.watch(dealersAssignedToMeProvider).valueOrNull ?? const [];
      final hasPanel = assigned.isNotEmpty ||
          (ref.watch(isAssignedDriverProvider).valueOrNull ?? false);
      if (!hasPanel) return const DriverHomeScreen();
    }

    final dealersTabLabel =
        isWholesaler ? 'Müşteriler' : AppStrings.dealerShellTabDealers;

    // Şoförler tabı YALNIZ patron'da → bireysel (owner kişisel defter veya
    // scoped şoför defteri) 4 tab (0..3); patron 5 tab (0..4).
    final index =
        ref.watch(dealerShellTabIndexProvider).clamp(0, isPatron ? 4 : 3);

    // Bireysel + bekleyen davet (henüz aktif şoför değil) → kişisel defter
    // üstünde davet banner'ı (kabul → aktif şoför → scoped'a geçer). Kişisel
    // defter KAYBOLMAZ. Banner davet yoksa kendini gizler.
    final showInviteBanner = isIndividual && !driverScoped;

    final scaffold = Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          if (showInviteBanner)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.s,
                AppSpacing.pageH,
                0,
              ),
              child: MyDriverInvitesCard(),
            ),
          Expanded(
            child: IndexedStack(
              index: index,
              children: [
                const DealerOverviewScreen(),
                const DealerListScreen(),
                const DealerActivityScreen(),
                const DealerReportsTabScreen(),
                // Şoförler: patron yönetimi — yalnız commercial/wholesaler.
                if (isPatron) const DriverListScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: PremiumBottomNav(
        selectedIndex: index,
        onSelect: (i) =>
            ref.read(dealerShellTabIndexProvider.notifier).state = i,
        items: [
          const PremiumNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: AppStrings.dealerShellTabOverview,
          ),
          PremiumNavItem(
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront_rounded,
            label: dealersTabLabel,
          ),
          const PremiumNavItem(
            icon: Icons.swap_vert_outlined,
            activeIcon: Icons.swap_vert_rounded,
            label: AppStrings.dealerShellTabActivity,
          ),
          const PremiumNavItem(
            icon: Icons.analytics_outlined,
            activeIcon: Icons.analytics_rounded,
            label: AppStrings.dealerShellTabReports,
          ),
          if (isPatron)
            const PremiumNavItem(
              icon: Icons.local_shipping_outlined,
              activeIcon: Icons.local_shipping_rounded,
              label: 'Şoförler',
            ),
        ],
      ),
    );

    // UI-NAV-004: mini-app içi tab >0 iken Android geri → tab 0'a dön
    // (tek geri tüm mini-app'i kapatmasın). Tab 0'da → normal pop (panele döner).
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(dealerShellTabIndexProvider.notifier).state = 0;
      },
      child: scaffold,
    );
  }
}
