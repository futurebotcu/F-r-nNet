import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_bottom_nav.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import 'dealer_list_screen.dart';

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
class DealerShellScreen extends ConsumerStatefulWidget {
  const DealerShellScreen({super.key});

  @override
  ConsumerState<DealerShellScreen> createState() => _DealerShellScreenState();
}

class _DealerShellScreenState extends ConsumerState<DealerShellScreen> {
  /// Default tab = Genel Bakış (mini-app ana sayfası hissi).
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileControllerProvider);

    // Toptancı: mini-app'e hiç girmez. Mevcut DealerListScreen'in defansif
    // redirect pattern'i ile aynı — kart linki olmasa da deep-link / legacy
    // bookmark senaryosu için.
    if (profile?.accountType == AccountType.wholesaler) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.wholesaleCustomers);
      });
      return const PremiumScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: const [
          _OverviewTab(),
          // Mevcut DealerListScreen olduğu gibi — kendi PremiumScaffold +
          // AppBar'ı + arama + filtre chip + ekle butonu intakt.
          DealerListScreen(),
          _ActivityPlaceholderTab(),
          _ReportsPlaceholderTab(),
          _EndOfDayPlaceholderTab(),
        ],
      ),
      bottomNavigationBar: PremiumBottomNav(
        selectedIndex: _index,
        onSelect: (i) => setState(() => _index = i),
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

/// Genel Bakış tab — Sprint 6A placeholder.
///
/// Gerçek içerik (KPI tile + hızlı eylem + son hareketler) Sprint 6B.
/// Bu sürüm "mini-app ana sayfası" hissi vermek için intentional bir
/// karşılama kartı + planlanmış özellikler listesi gösterir.
class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumScaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dealerShellTabOverview),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pageH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumCard(
                warm: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.dealerShellTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      AppStrings.dealerShellOverviewWelcomeBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s,
                ),
                child: Text(
                  AppStrings.dealerShellOverviewUpcomingTitle.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              const _UpcomingItem(
                icon: Icons.summarize_outlined,
                label: AppStrings.dealerShellOverviewUpcomingSummary,
              ),
              const _UpcomingItem(
                icon: Icons.bolt_outlined,
                label: AppStrings.dealerShellOverviewUpcomingQuickActions,
              ),
              const _UpcomingItem(
                icon: Icons.history_outlined,
                label: AppStrings.dealerShellOverviewUpcomingRecentActivity,
              ),
              const _UpcomingItem(
                icon: Icons.account_balance_wallet_outlined,
                label: AppStrings.dealerShellOverviewUpcomingOpenBalance,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingItem extends StatelessWidget {
  const _UpcomingItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.softGold, size: 22),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.softGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                AppStrings.dealerShellPlaceholderTitle.toLowerCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.softGold,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hareketler tab placeholder — cross-dealer tx feed yakında.
class _ActivityPlaceholderTab extends StatelessWidget {
  const _ActivityPlaceholderTab();
  @override
  Widget build(BuildContext context) {
    return _PlaceholderScaffold(
      title: AppStrings.dealerShellTabActivity,
      icon: Icons.swap_vert_rounded,
      body: AppStrings.dealerShellPlaceholderActivityBody,
    );
  }
}

/// Raporlar tab placeholder — toplu rapor için ileride.
class _ReportsPlaceholderTab extends StatelessWidget {
  const _ReportsPlaceholderTab();
  @override
  Widget build(BuildContext context) {
    return _PlaceholderScaffold(
      title: AppStrings.dealerShellTabReports,
      icon: Icons.analytics_rounded,
      body: AppStrings.dealerShellPlaceholderReportsBody,
    );
  }
}

/// Gün Sonu tab placeholder — Sprint 4 (settlement) içerik dolduracak.
class _EndOfDayPlaceholderTab extends StatelessWidget {
  const _EndOfDayPlaceholderTab();
  @override
  Widget build(BuildContext context) {
    return _PlaceholderScaffold(
      title: AppStrings.dealerShellTabEndOfDay,
      icon: Icons.event_available_rounded,
      body: AppStrings.dealerShellPlaceholderEndOfDayBody,
    );
  }
}

/// Ortak placeholder şablonu — AppBar + merkezi "Yakında" kart.
class _PlaceholderScaffold extends StatelessWidget {
  const _PlaceholderScaffold({
    required this.title,
    required this.icon,
    required this.body,
  });

  final String title;
  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumScaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: AppColors.borderHairline,
                      width: 0.8,
                    ),
                  ),
                  child: Icon(icon, size: 36, color: AppColors.softGold),
                ),
                const SizedBox(height: AppSpacing.l),
                Text(
                  AppStrings.dealerShellPlaceholderTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
