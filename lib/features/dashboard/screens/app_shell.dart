import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/premium/premium_bottom_nav.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  // V Nav-Profile-To-Jobs:
  // Sektör ağı kalitesi için ilanlar (work) ana navigasyonda görünür hale
  // getirildi. Profil ana tab'dan çıkarıldı (Feed header avatar üzerinden
  // erişilir); ProfileScreen ve /profile route geriye dönük kalır.
  static const _tabs = <_TabSpec>[
    _TabSpec(
      AppRoutes.feed,
      PremiumNavItem(
        icon: Icons.dynamic_feed_outlined,
        activeIcon: Icons.dynamic_feed_rounded,
        label: 'Feed',
      ),
    ),
    _TabSpec(
      AppRoutes.groups,
      PremiumNavItem(
        icon: Icons.groups_2_outlined,
        activeIcon: Icons.groups_2_rounded,
        label: 'Gruplar',
      ),
    ),
    _TabSpec(
      AppRoutes.market,
      PremiumNavItem(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_rounded,
        label: 'Market',
      ),
    ),
    _TabSpec(
      AppRoutes.jobs,
      PremiumNavItem(
        icon: Icons.work_outline_rounded,
        activeIcon: Icons.work_rounded,
        label: 'İlanlar',
      ),
    ),
    _TabSpec(
      AppRoutes.panel,
      PremiumNavItem(
        icon: Icons.dashboard_customize_outlined,
        activeIcon: Icons.dashboard_customize_rounded,
        label: 'Panel',
      ),
    ),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexFor(location);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: PremiumBottomNav(
        items: [for (final t in _tabs) t.item],
        selectedIndex: index,
        onSelect: (i) => context.go(_tabs[i].route),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.route, this.item);
  final String route;
  final PremiumNavItem item;
}
