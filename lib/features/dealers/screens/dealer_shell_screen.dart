import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
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
    // feat/driver-real-scoped-shell: bireysel şoför, normal Bayi Yönetimi
    // shell'ini scoped modda reuse eder. Bu mod yalnız DriverHomeScreen'in
    // sardığı ProviderScope içinde set edilir; profile gating'i atlanır.
    if (ref.watch(dealerShellModeProvider) == DealerShellMode.driverScoped) {
      return const _DriverScopedShell();
    }

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

    // Ürün modeli: bireysel kullanıcı = ŞOFÖR (patron değil). Bayi Yönetimi'ne
    // girince patron defteri/Şoförler yönetimi DEĞİL, "Bana Atanan Bayiler"
    // şoför görünümü açılır (davet kartı / atanan bayiler / güvenli boş durum).
    // Patron defteri fallback'i bireysele GÖSTERİLMEZ.
    if (profile?.accountType == AccountType.individual) {
      return const DriverHomeScreen();
    }
    // Ticari (commercial) → patron Bayi Yönetimi shell'i (Şoförler tabı dahil).

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
          // Raporlar: toplu + bayi bazlı rapor (+ Gün Sonu erişimi içeride).
          DealerReportsTabScreen(),
          // Şoförler: patron tarafı yönetim (davet/atama/özet).
          DriverListScreen(),
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
            icon: Icons.local_shipping_outlined,
            activeIcon: Icons.local_shipping_rounded,
            label: 'Şoförler',
          ),
        ],
      ),
    );
  }
}

/// Bireysel şoför scoped shell: normal Bayi Yönetimi tab ekranlarının
/// (overview/list/activity/reports) AYNISINI, tek "Bayi Yönetimi" başlığı +
/// "Şoför modunda…" alt bilgisi + 4-tab bottom nav ile render eder. Şoförler
/// tabı ve Gün Sonu yok; owner-only CTA'lar ekran içinde gizlenir. Data scope
/// `DriverScopedDealerRepository` (provider override) ile sağlanır.
class _DriverScopedShell extends ConsumerWidget {
  const _DriverScopedShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tab index owner ile aynı provider'ı paylaşır (overview CTA tab-switch
    // çalışsın); driver shell 4 tab olduğu için 0..3'e clamp edilir.
    final index = ref.watch(dealerShellTabIndexProvider).clamp(0, 3);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bayi Yönetimi'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(26),
          child: Padding(
            padding: EdgeInsets.only(
                left: AppSpacing.pageH, right: AppSpacing.pageH, bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Şoför modunda · Sana atanmış bayiler gösteriliyor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: index,
          children: const [
            DealerOverviewScreen(),
            DealerListScreen(),
            DealerActivityScreen(),
            DealerReportsTabScreen(),
          ],
        ),
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
        ],
      ),
    );
  }
}
