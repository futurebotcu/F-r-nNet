// Navigation IA Sprint — Topluluk sekmesi.
//
// Feed (Genel Akış) + Gruplar tek "Topluluk" kapsayıcısında segmentli. Çocuk
// ekranlar `embedded: true` ile kendi header'larını çizmez; tek "Topluluk"
// başlığı + SegmentTabBar burada. Lazy IndexedStack: bir segment ilk ziyaret
// edildiğinde kurulur ve canlı kalır → segment geçişinde reload/spinner flash
// yok, scroll pozisyonu korunur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/segment_tab_bar.dart';
import '../../notifications/widgets/notifications_header_action.dart';
import '../../social/feed/social_feed_page.dart';
import '../../social_groups/screens/groups_list_screen.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, this.initialSegment = 0});

  /// 0 = Genel Akış (Feed), 1 = Gruplar. Eski /groups redirect'i `?seg=groups`
  /// ile 1 geçirir.
  final int initialSegment;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  late int _segment = widget.initialSegment.clamp(0, 1);
  late final Set<int> _visited = <int>{_segment};

  void _select(int i) {
    if (i == _segment) return;
    setState(() {
      _segment = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FirinNetHeader(
              title: AppStrings.communityTitle,
              subtitle: AppStrings.communitySubtitle,
              actions: [
                const NotificationsHeaderAction(),
                const SizedBox(width: 4),
                // Gruplar segmentinde "+" grup oluştur; Genel Akış'ta profil
                // avatarı (eski feed header davranışı korunur — profil ana
                // nav'dan çıktığı için tek erişim noktası).
                if (_segment == 1)
                  HeaderActionButton(
                    icon: Icons.add_rounded,
                    tooltip: AppStrings.groupsCreateTooltip,
                    onTap: () => context.push(AppRoutes.groupCreate),
                  )
                else
                  const ProfileAvatarAction(),
              ],
            ),
            const Divider(height: 1, color: AppColors.borderHairline),
            SegmentTabBar(
              labels: const [
                AppStrings.communitySegFeed,
                AppStrings.communitySegGroups,
              ],
              index: _segment,
              onChanged: _select,
            ),
            Expanded(
              child: IndexedStack(
                index: _segment,
                children: [
                  _visited.contains(0)
                      ? const SocialFeedPage(embedded: true)
                      : const SizedBox.shrink(),
                  _visited.contains(1)
                      ? const GroupsListScreen(embedded: true)
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
