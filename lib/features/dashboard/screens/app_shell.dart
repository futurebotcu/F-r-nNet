import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_bottom_nav.dart';
import '../../messaging/providers/messaging_providers.dart';

/// Navigation IA Sprint — alt nav: Topluluk · Pazar · İlanlar · Mesajlar · Panel
///
/// * Topluluk = Feed (Genel Akış) + Gruplar segmentli sosyal alan.
/// * Pazar    = "Yakında" B2B/teklif ağı yüzeyi (mini nokta rozet).
/// * İlanlar  = Eleman + İş yeri + Ekipman segmentli ilan merkezi.
/// * Mesajlar = tüm konuşmalar (okunmamış sayaç rozeti).
/// * Panel    = işletme araçları merkezi.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_TabSpec>[
    _TabSpec(
      AppRoutes.community,
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum_rounded,
      label: AppStrings.navCommunity,
    ),
    _TabSpec(
      AppRoutes.pazar,
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront_rounded,
      label: AppStrings.navPazar,
      comingSoon: true,
    ),
    _TabSpec(
      AppRoutes.listings,
      icon: Icons.work_outline_rounded,
      activeIcon: Icons.work_rounded,
      label: AppStrings.navListings,
    ),
    _TabSpec(
      AppRoutes.messages,
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: AppStrings.navMessages,
    ),
    _TabSpec(
      AppRoutes.panel,
      icon: Icons.dashboard_customize_outlined,
      activeIcon: Icons.dashboard_customize_rounded,
      label: AppStrings.navPanel,
    ),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexFor(location);
    // Mesajlar sekmesi okunmamış rozeti — mevcut provider korunur.
    final unread = ref.watch(totalUnreadMessagesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: PremiumBottomNav(
        items: [
          for (final t in _tabs)
            PremiumNavItem(
              icon: t.icon,
              activeIcon: t.activeIcon,
              label: t.label,
              comingSoon: t.comingSoon,
              badgeCount: t.route == AppRoutes.messages ? unread : 0,
            ),
        ],
        selectedIndex: index,
        onSelect: (i) => context.go(_tabs[i].route),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(
    this.route, {
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.comingSoon = false,
  });

  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool comingSoon;
}
