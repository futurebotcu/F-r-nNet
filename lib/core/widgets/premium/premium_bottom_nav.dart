import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../widgets/interactions.dart';

/// FirinNet alt navigasyonu - ince hairline ust cizgi, soft lemon vurgu.
/// Secili: ikon/etiket koyu, ustte ince pale lemon indicator.
class PremiumBottomNav extends StatelessWidget {
  const PremiumBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<PremiumNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: AppShadow.subtle,
            ),
            height: 70,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: PressScale(
                      onTap: null,
                      child: _NavTile(
                        item: items[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelect(i),
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

class PremiumNavItem {
  const PremiumNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
    this.comingSoon = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Okunmamış sayaç (Mesajlar). 0 → rozet gösterilmez.
  final int badgeCount;

  /// "Yakında" mini rozeti (Pazar tab'ı).
  final bool comingSoon;
}

/// İkonun sağ-üstüne okunmamış sayaç rozeti veya "Yakında" noktası yerleştirir.
class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({
    super.key,
    required this.icon,
    required this.badgeCount,
    required this.comingSoon,
  });

  final Widget icon;
  final int badgeCount;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    if (badgeCount <= 0 && !comingSoon) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        if (badgeCount > 0)
          Positioned(
            top: -5,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          )
        else if (comingSoon)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.brandLemonPressed,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PremiumNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // White surface uzerinde aktif sekme soft lemon indicator + koyu ikon.
    final color = selected ? AppColors.brandInk : AppColors.onBackgroundMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            AnimatedOpacity(
              duration: AppDuration.fast,
              opacity: selected ? 1 : 0,
              // Sade tek-renk pale lemon cizgi.
              child: Container(
                margin: const EdgeInsets.only(top: 0),
                height: 2,
                width: 24,
                decoration: BoxDecoration(
                  color: AppColors.brandLemonPale,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: AppDuration.fast,
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: _IconWithBadge(
                      key: ValueKey(selected),
                      icon: Icon(
                        selected ? item.activeIcon : item.icon,
                        color: color,
                        size: 24,
                      ),
                      badgeCount: item.badgeCount,
                      comingSoon: item.comingSoon,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
