// Navigation IA Sprint — İlanlar sekmesi.
//
// Tek "İlanlar" kapsayıcısı altında üç segment:
//   * Eleman   → JobsScreen (embedded) — Usta Arıyor / İş Arıyor alt-segmenti
//   * İş yeri  → MarketplaceScreen (embedded, listing_type='bakery_transfer')
//   * Ekipman  → MarketplaceScreen (embedded, listing_type='equipment_sale')
//
// Çocuk ekranlar kendi header'larını çizmez; tek "İlanlar" başlığı + segmente
// duyarlı "+" burada. Lazy IndexedStack → segment geçişinde reload/spinner yok.
//
// "+" segment bağlamı:
//   * Eleman: hesap tipine göre commercial/wholesaler → Usta Arıyor formu;
//     bireysel → İş Arıyor formu (JobsScreen'in commercial-only kuralıyla
//     tutarlı, ekstra guard'a gerek kalmadan doğru forma götürür).
//   * İş yeri / Ekipman: marketplace ilan formu.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/segment_tab_bar.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../jobs/screens/jobs_screen.dart';
import '../../marketplace/data/marketplace_taxonomy.dart';
import '../../marketplace/screens/marketplace_screen.dart';
import '../../notifications/widgets/notifications_header_action.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';

class ListingsScreen extends ConsumerStatefulWidget {
  const ListingsScreen({super.key, this.initialSegment = 0});

  /// 0 = Eleman, 1 = İş yeri, 2 = Ekipman.
  final int initialSegment;

  @override
  ConsumerState<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends ConsumerState<ListingsScreen> {
  late int _segment = widget.initialSegment.clamp(0, 2);
  late final Set<int> _visited = <int>{_segment};

  void _select(int i) {
    if (i == _segment) return;
    setState(() {
      _segment = i;
      _visited.add(i);
    });
  }

  Future<void> _onAdd() async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    if (!mounted) return;
    switch (_segment) {
      case 0:
        // Eleman: hesap tipine göre doğru forma.
        final profile = ref.read(profileControllerProvider);
        final isCommercial = profile?.accountType == AccountType.commercial ||
            profile?.accountType == AccountType.wholesaler;
        context.push(
          isCommercial ? AppRoutes.jobOfferNew : AppRoutes.jobSeekNew,
        );
      case 1:
      case 2:
        // İş yeri / Ekipman: marketplace ilan formu (tip formda seçilir).
        context.push(AppRoutes.marketListingNew);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FirinNetHeader(
              title: AppStrings.listingsTitle,
              subtitle: AppStrings.listingsSubtitle,
              actions: [
                const NotificationsHeaderAction(),
                const SizedBox(width: 4),
                HeaderActionButton(
                  icon: Icons.add_rounded,
                  tooltip: AppStrings.marketListingAddCta,
                  onTap: _onAdd,
                ),
              ],
            ),
            const Divider(height: 1, color: AppColors.borderHairline),
            SegmentTabBar(
              labels: const [
                AppStrings.listingsSegStaff,
                AppStrings.listingsSegWorkplace,
                AppStrings.listingsSegEquipment,
              ],
              index: _segment,
              onChanged: _select,
            ),
            Expanded(
              child: IndexedStack(
                index: _segment,
                children: [
                  _visited.contains(0)
                      ? const JobsScreen(embedded: true)
                      : const SizedBox.shrink(),
                  _visited.contains(1)
                      ? const MarketplaceScreen(
                          embedded: true,
                          forceListingType:
                              MarketplaceTaxonomy.listingTypeBakeryTransfer,
                        )
                      : const SizedBox.shrink(),
                  _visited.contains(2)
                      ? const MarketplaceScreen(
                          embedded: true,
                          forceListingType:
                              MarketplaceTaxonomy.listingTypeEquipmentSale,
                        )
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
