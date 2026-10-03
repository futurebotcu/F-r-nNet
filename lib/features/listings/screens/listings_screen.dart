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
//   * Eleman: commercial/wholesaler → "Personel arıyorum / İş arıyorum"
//     seçim sheet'i; bireysel → doğrudan İş Arıyor formu (JobsScreen'in
//     commercial-only kuralıyla tutarlı).
//   * İş yeri / Ekipman: marketplace ilan formu; ilan tipi segmentten
//     (`?type=`) önceden seçili gelir. Tooltip segmente göre değişir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
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
        // Eleman: ticari/toptancı hem personel arayabilir hem iş arayabilir →
        // küçük seçim sheet'i. Bireysel yalnız "İş arıyorum" → doğrudan form.
        final profile = ref.read(profileControllerProvider);
        final isCommercial =
            profile?.accountType == AccountType.commercial ||
            profile?.accountType == AccountType.wholesaler;
        if (!isCommercial) {
          context.push(AppRoutes.jobSeekNew);
          return;
        }
        final route = await _chooseStaffListingKind();
        if (route != null && mounted) context.push(route);
      case 1:
      case 2:
        // İş yeri / Ekipman: marketplace ilan formu, tip segmentten gelir.
        final type = _segment == 1
            ? MarketplaceTaxonomy.listingTypeBakeryTransfer
            : MarketplaceTaxonomy.listingTypeEquipmentSale;
        context.push(
          Uri(
            path: AppRoutes.marketListingNew,
            queryParameters: {'type': type},
          ).toString(),
        );
    }
  }

  Future<String?> _chooseStaffListingKind() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  AppSpacing.l,
                  AppSpacing.pageH,
                  AppSpacing.s,
                ),
                child: Text(
                  AppStrings.listingsChooserTitle,
                  style: AppTypography.sectionTitle,
                ),
              ),
              ListTile(
                key: const ValueKey('listings_choose_hiring'),
                leading: const Icon(
                  Icons.work_outline_rounded,
                  color: AppColors.textPrimary,
                ),
                title: const Text(AppStrings.listingsChooserHiring),
                subtitle: const Text(AppStrings.listingsChooserHiringSub),
                onTap: () => Navigator.of(ctx).pop(AppRoutes.jobOfferNew),
              ),
              ListTile(
                key: const ValueKey('listings_choose_seeking'),
                leading: const Icon(
                  Icons.person_search_outlined,
                  color: AppColors.textPrimary,
                ),
                title: const Text(AppStrings.listingsChooserSeeking),
                subtitle: const Text(AppStrings.listingsChooserSeekingSub),
                onTap: () => Navigator.of(ctx).pop(AppRoutes.jobSeekNew),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _addTooltip => switch (_segment) {
    1 => AppStrings.listingsAddWorkplaceTooltip,
    2 => AppStrings.listingsAddEquipmentTooltip,
    _ => AppStrings.listingsAddStaffTooltip,
  };

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
                  tooltip: _addTooltip,
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
