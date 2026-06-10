import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/quick_action_tile.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../messaging/providers/messaging_providers.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../services/role_panel_cards.dart';

/// Panel tab'ının yeni kök ekranı.
///
/// Profil yoksa hâlâ misafir (bireysel) varsayılır; mevcut Fırın Paneli
/// ve Bayi Paneli ekranları kart push'larıyla açılır. Bu sayede tek bir
/// `/panel` route'u rolü değiştikçe farklı bir liste sunar — eski
/// `BakeryPanelScreen` `/panel/bakery` altında olduğu gibi korunur.
class RoleDashboardScreen extends ConsumerWidget {
  const RoleDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final account = profile?.accountType ?? AccountType.individual;
    final cards = RolePanelCards.forAccount(account);
    // M-10 — Panel "Mesajlar" kartı için gerçek okunmamış toplamı.
    final unread = ref.watch(totalUnreadMessagesProvider);
    final greeting = profile?.displayName.isNotEmpty == true
        ? '${AppStrings.panelGreetingPrefix}, ${profile!.displayName}'
        : AppStrings.panelTitle;

    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            FirinNetHeader(
              title: greeting,
              subtitle: RolePanelCards.subtitleFor(account),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: _RoleBadgeStrip(account: account),
            ),
            SectionLabel(title: _sectionTitleFor(account)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    QuickActionTile(
                      label: cards[i].label,
                      subtitle: cards[i].subtitle,
                      icon: cards[i].icon,
                      featured: i == 0,
                      badgeCount:
                          cards[i].route == AppRoutes.messages ? unread : 0,
                      onTap: () => _onTap(context, cards[i]),
                    ),
                    if (i != cards.length - 1)
                      const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sectionTitleFor(AccountType type) {
    switch (type) {
      case AccountType.commercial:
        return 'Atölye yönetimi';
      case AccountType.individual:
        return 'Sektör ağı';
      case AccountType.wholesaler:
        return 'Toptan ağ';
    }
  }

  void _onTap(BuildContext context, PanelCard card) {
    if (card.comingSoon || card.route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${card.label} — ${AppStrings.comingSoon}'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final route = card.route!;
    // Shell içindeki ana tab'lara go ile geç (alt tab'a hop);
    // diğer ekranlara push ile derinleş.
    if (route == AppRoutes.jobs ||
        route == AppRoutes.market ||
        route == AppRoutes.feed ||
        route == AppRoutes.groups) {
      context.go(route);
    } else {
      context.push(route);
    }
  }
}

/// Üst hero — rolü ve meslek rozetini kompakt gösterir.
class _RoleBadgeStrip extends ConsumerWidget {
  const _RoleBadgeStrip({required this.account});
  final AccountType account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
                width: 0.6,
              ),
              boxShadow: AppShadow.card,
            ),
            child: Icon(_iconFor(account), color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile?.roleBadge.isNotEmpty == true
                      ? profile!.roleBadge
                      : 'Profil oluşturmadın',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          if (profile == null)
            TextButton(
              onPressed: () => context.push(AppRoutes.createProfile),
              child: const Text('Oluştur'),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(AccountType type) {
    switch (type) {
      case AccountType.commercial:
        return Icons.storefront_rounded;
      case AccountType.individual:
        return Icons.person_rounded;
      case AccountType.wholesaler:
        return Icons.local_shipping_rounded;
    }
  }
}
