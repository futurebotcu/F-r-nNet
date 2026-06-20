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
    // fix/driver-normal-dealer-shell: mod hesap tipinden türetilir. Bireysel
    // şoför = driverScoped → AYNI normal Bayi Yönetimi shell'i; tek fark
    // Şoförler tabı yok ve veri atanmış bayilerle sınırlı (repo decorator).
    final driverScoped =
        ref.watch(dealerShellModeProvider) == DealerShellMode.driverScoped;

    if (driverScoped) {
      // Henüz atanmamış (davet bekleyen) şoför: ayrı panel DEĞİL, sadece davet
      // kartı + boş durum. Atanmış şoför → normal shell (aşağıda).
      final assigned =
          ref.watch(dealersAssignedToMeProvider).valueOrNull ?? const [];
      final hasPanel = assigned.isNotEmpty ||
          (ref.watch(isAssignedDriverProvider).valueOrNull ?? false);
      if (!hasPanel) return const DriverHomeScreen();
    } else {
      // Toptancı: mini-app'e hiç girmez → defansif redirect.
      final accountType = ref
          .watch(profileControllerProvider.select((p) => p?.accountType));
      if (accountType == AccountType.wholesaler) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(AppRoutes.wholesaleCustomers);
        });
        return const PremiumScaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
    }

    // Tab indeksi `dealerShellTabIndexProvider`'dan okunur (Genel Bakış
    // CTA'ları programatik tab geçişi için aynı provider'ı set eder). Driver
    // modda Şoförler tabı olmadığı için 0..3'e clamp edilir.
    final index =
        ref.watch(dealerShellTabIndexProvider).clamp(0, driverScoped ? 3 : 4);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: index,
        children: [
          const DealerOverviewScreen(),
          const DealerListScreen(),
          const DealerActivityScreen(),
          const DealerReportsTabScreen(),
          // Şoförler: patron tarafı yönetim — bireysel şoföre gösterilmez.
          if (!driverScoped) const DriverListScreen(),
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
          const PremiumNavItem(
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront_rounded,
            label: AppStrings.dealerShellTabDealers,
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
          if (!driverScoped)
            const PremiumNavItem(
              icon: Icons.local_shipping_outlined,
              activeIcon: Icons.local_shipping_rounded,
              label: 'Şoförler',
            ),
        ],
      ),
    );
  }
}
