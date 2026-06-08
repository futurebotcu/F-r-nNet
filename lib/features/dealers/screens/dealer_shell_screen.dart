import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_bottom_nav.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/dealer_providers.dart';
import 'dealer_activity_screen.dart';
import 'dealer_end_of_day_tab_screen.dart';
import 'dealer_list_screen.dart';
import 'dealer_overview_screen.dart';
import 'dealer_reports_tab_screen.dart';

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
    final profile = ref.watch(profileControllerProvider);

    // Toptancı: mini-app'e hiç girmez. Mevcut DealerListScreen'in defansif
    // redirect pattern'i ile aynı — kart linki olmasa da deep-link / legacy
    // bookmark senaryosu için.
    if (profile?.accountType == AccountType.wholesaler) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.wholesaleCustomers);
      });
      return const PremiumScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Sprint 6B: tab indeksi `dealerShellTabIndexProvider`'dan okunur.
    // Genel Bakış CTA'ları başka tab'a programatik geçiş için aynı
    // provider'ı set eder. Default 0 (Genel Bakış).
    final index = ref.watch(dealerShellTabIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: index,
        children: const [
          // Sprint 6B: placeholder yerine gerçek Genel Bakış ekranı.
          DealerOverviewScreen(),
          // Mevcut DealerListScreen olduğu gibi — kendi PremiumScaffold +
          // AppBar'ı + arama + filtre chip + ekle butonu intakt.
          DealerListScreen(),
          // Sprint Activity: placeholder yerine cross-dealer hareket listesi.
          DealerActivityScreen(),
          // Sprint Raporlar: toplu + bayi bazlı rapor.
          DealerReportsTabScreen(),
          // Sprint Gün Sonu V1: pasif günlük rapor + plain text share.
          DealerEndOfDayTabScreen(),
        ],
      ),
      bottomNavigationBar: PremiumBottomNav(
        selectedIndex: index,
        onSelect: (i) =>
            ref.read(dealerShellTabIndexProvider.notifier).state = i,
        items: const [
          PremiumNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: AppStrings.dealerShellTabOverview,
          ),
          PremiumNavItem(
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront_rounded,
            label: AppStrings.dealerShellTabDealers,
          ),
          PremiumNavItem(
            icon: Icons.swap_vert_outlined,
            activeIcon: Icons.swap_vert_rounded,
            label: AppStrings.dealerShellTabActivity,
          ),
          PremiumNavItem(
            icon: Icons.analytics_outlined,
            activeIcon: Icons.analytics_rounded,
            label: AppStrings.dealerShellTabReports,
          ),
          PremiumNavItem(
            icon: Icons.event_available_outlined,
            activeIcon: Icons.event_available_rounded,
            label: AppStrings.dealerShellTabEndOfDay,
          ),
        ],
      ),
    );
  }
}
