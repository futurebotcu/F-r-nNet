// Tedarikçi Paneli S1 — Panel sekmesi tedarikçi (wholesaler) ana ekranı.
//
// Amaç: tedarikçi girişte 3 saniyede "bugün ne yapmalıyım"ı görsün.
// Üç blok, hepsi GERÇEK veriden (mevcut B2B provider'ları; yeni tablo/RPC
// yok):
//   1. Mağaza durumu — vitrin kartı + plan rozeti + profil tamamlanma (5 adım).
//      Mağaza yoksa tek CTA: "Mağazanı oluştur".
//   2. Bugün — 4 KPI: ağdaki açık talep · yayında ürün/limit · aktif
//      kampanya/limit · ilgilenen müşteri. Her biri ilgili Pazar sekmesine gider.
//   3. Hızlı işlemler — Ürün ekle (paywall) · Kampanya oluştur (paywall) ·
//      Talepleri gör · Mağazayı düzenle.
//
// Durumlar: ilk yükleme → skeleton; mağaza hatası → ErrorRetryState (tüm
// provider'lar invalidate); KPI provider'ı tek tek yüklenirken "—".
// Yetki: bu widget yalnız AccountType.wholesaler için kurulur (RoleDashboard);
// yazma kısıtı server-side (RLS + can_add_* helper'ları), paywall UI aynası.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/firinnet_avatar.dart';
import '../../../core/widgets/interactions.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_list_skeleton.dart';
import '../../../core/widgets/premium/quick_action_tile.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../b2b_market/models/b2b_campaign.dart';
import '../../b2b_market/models/b2b_product.dart';
import '../../b2b_market/models/b2b_quote_lead.dart';
import '../../b2b_market/models/b2b_quote_request.dart';
import '../../b2b_market/models/b2b_store.dart';
import '../../b2b_market/providers/b2b_providers.dart';
import '../../subscriptions/models/business_entitlements.dart';
import '../../subscriptions/models/business_plan.dart';
import '../../subscriptions/models/supplier_paywall.dart';
import '../../subscriptions/providers/subscription_providers.dart';
import '../../subscriptions/widgets/paywall_sheet.dart';

/// Mağaza profili tamamlanma hesabı (saf fonksiyon — test edilebilir).
///
/// 5 adım: logo · açıklama · hizmet bölgesi · kategori · yayında ürün.
class SupplierStoreCompletion {
  const SupplierStoreCompletion._(this.steps);

  final List<(String label, bool done)> steps;

  static SupplierStoreCompletion of(B2bStore store, List<B2bProduct> products) {
    return SupplierStoreCompletion._([
      (AppStrings.supPanelStepLogo, (store.logoUrl ?? '').isNotEmpty),
      (AppStrings.supPanelStepDescription, store.description.trim().isNotEmpty),
      (AppStrings.supPanelStepRegions, store.serviceRegions.isNotEmpty),
      (AppStrings.supPanelStepCategories, store.categories.isNotEmpty),
      (AppStrings.supPanelStepProduct, products.any((p) => p.published)),
    ]);
  }

  int get done => steps.where((s) => s.$2).length;
  int get total => steps.length;
  bool get complete => done == total;
  double get ratio => total == 0 ? 0 : done / total;
}

class SupplierPanelHome extends ConsumerWidget {
  const SupplierPanelHome({super.key});

  static void _invalidateAll(WidgetRef ref) {
    ref.invalidate(b2bMyStoreProvider);
    ref.invalidate(b2bMyProductsProvider);
    ref.invalidate(b2bMyCampaignsProvider);
    ref.invalidate(b2bOpenQuoteRequestsProvider);
    ref.invalidate(b2bSupplierLeadsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(b2bMyStoreProvider);
    final productsAsync = ref.watch(b2bMyProductsProvider);
    final campaignsAsync = ref.watch(b2bMyCampaignsProvider);
    final requestsAsync = ref.watch(b2bOpenQuoteRequestsProvider);
    final leadsAsync = ref.watch(b2bSupplierLeadsProvider);
    final entitlement = ref.watch(myEntitlementProvider).valueOrNull;

    return storeAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const PremiumListSkeleton(
        key: ValueKey('supplier_panel_skeleton'),
        itemCount: 3,
        itemHeight: 96,
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          AppSpacing.m,
          AppSpacing.pageH,
          AppSpacing.s,
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        child: ErrorRetryState(
          key: const ValueKey('supplier_panel_error'),
          compact: true,
          title: AppStrings.supPanelErrorTitle,
          onRetry: () => _invalidateAll(ref),
        ),
      ),
      data: (store) {
        final products = productsAsync.valueOrNull ?? const <B2bProduct>[];
        final campaigns = campaignsAsync.valueOrNull ?? const <B2bCampaign>[];
        final hasStore = store.id.isNotEmpty && store.name.trim().isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(
              title: AppStrings.supPanelSectionStore,
              topGap: AppSpacing.l,
              trailingLabel: hasStore ? AppStrings.supPanelOpenStore : null,
              onTrailingTap: hasStore
                  ? () =>
                        context.go(AppRoutes.pazarTab(AppRoutes.pazarTabStore))
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: hasStore
                  ? _StoreStatusCard(
                      store: store,
                      completion: SupplierStoreCompletion.of(store, products),
                      entitlement: entitlement,
                    )
                  : const _NoStoreCard(),
            ),
            SectionLabel(title: AppStrings.supPanelSectionKpi),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: _KpiGrid(
                products: productsAsync,
                campaigns: campaignsAsync,
                requests: requestsAsync,
                leads: leadsAsync,
                entitlement: entitlement,
              ),
            ),
            SectionLabel(title: AppStrings.supPanelSectionQuick),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: _QuickActions(
                products: products,
                campaigns: campaigns,
                entitlement: entitlement,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Mağaza durumu
// ---------------------------------------------------------------------------

class _StoreStatusCard extends StatelessWidget {
  const _StoreStatusCard({
    required this.store,
    required this.completion,
    required this.entitlement,
  });

  final B2bStore store;
  final SupplierStoreCompletion completion;
  final BusinessEntitlements? entitlement;

  @override
  Widget build(BuildContext context) {
    final planLabel = _planLabel(entitlement);
    return PremiumCard(
      key: const ValueKey('supplier_panel_store_card'),
      warm: true,
      onTap: () => context.go(AppRoutes.pazarTab(AppRoutes.pazarTabStore)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FirinNetAvatar(
                name: store.name,
                imageUrl: store.logoUrl,
                size: FirinNetAvatarSize.m,
                kind: FirinNetAvatarKind.business,
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _metaLine(store),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (planLabel != null) ...[
                const SizedBox(width: AppSpacing.s),
                _PlanChip(label: planLabel),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          _CompletionBar(completion: completion),
        ],
      ),
    );
  }

  static String _metaLine(B2bStore store) {
    final parts = <String>[
      if (store.serviceRegions.isNotEmpty)
        store.serviceRegions.take(2).join(', '),
      if (store.categories.isNotEmpty) store.categories.take(2).join(', '),
    ];
    return parts.isEmpty ? AppStrings.supPanelCompletion : parts.join(' · ');
  }

  static String? _planLabel(BusinessEntitlements? e) {
    if (e == null) return null;
    if (e.supplierLaunchFreeActive) return AppStrings.supPanelPlanLaunch;
    switch (e.supplierEffectivePlan) {
      case BusinessPlan.premium:
      case BusinessPlan.pro:
        return AppStrings.supPanelPlanPremium;
      case BusinessPlan.free:
        return AppStrings.supPanelPlanFree;
    }
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.brandLemon,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppTypography.badge.copyWith(color: AppColors.brandInk),
      ),
    );
  }
}

class _CompletionBar extends StatelessWidget {
  const _CompletionBar({required this.completion});
  final SupplierStoreCompletion completion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                completion.complete
                    ? AppStrings.supPanelCompletionDone
                    : AppStrings.supPanelCompletion,
                style: AppTypography.infoLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${completion.done}/${completion.total}',
              key: const ValueKey('supplier_panel_completion'),
              style: AppTypography.infoLabel.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: completion.ratio,
            minHeight: 6,
            backgroundColor: AppColors.surfaceLine,
            valueColor: AlwaysStoppedAnimation<Color>(
              completion.complete ? AppColors.success : AppColors.brandInk,
            ),
          ),
        ),
        if (!completion.complete) ...[
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in completion.steps)
                _StepChip(label: s.$1, done: s.$2),
            ],
          ),
        ],
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: done ? AppColors.surface : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: done ? AppColors.brandLemonSoft : AppColors.borderHairline,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 13,
            color: done ? AppColors.successInk : AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          // Büyük yazı ölçeğinde (1.3x+) dar ekranda chip satırı taşmasın.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.chipLabel.copyWith(
                color: done ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoStoreCard extends StatelessWidget {
  const _NoStoreCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      key: const ValueKey('supplier_panel_no_store'),
      warm: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandLemonPale,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(
                    color: AppColors.brandLemonSoft,
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.brandInk,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  AppStrings.supPanelNoStoreTitle,
                  style: AppTypography.cardTitle.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            AppStrings.supPanelNoStoreSub,
            style: AppTypography.body.copyWith(fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              key: const ValueKey('supplier_panel_no_store_cta'),
              onPressed: () => context.push(AppRoutes.b2bStoreEdit),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(AppStrings.supPanelNoStoreCta),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. KPI
// ---------------------------------------------------------------------------

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.products,
    required this.campaigns,
    required this.requests,
    required this.leads,
    required this.entitlement,
  });

  final AsyncValue<List<B2bProduct>> products;
  final AsyncValue<List<B2bCampaign>> campaigns;
  final AsyncValue<List<B2bQuoteRequest>> requests;
  final AsyncValue<List<B2bQuoteLead>> leads;
  final BusinessEntitlements? entitlement;

  @override
  Widget build(BuildContext context) {
    final openCount = requests.valueOrNull?.length;
    final productList = products.valueOrNull;
    final campaignList = campaigns.valueOrNull;
    final leadCount = leads.valueOrNull?.where((l) => l.isInterested).length;

    final publishedProducts = productList?.where((p) => p.published).length;
    final draftProducts = productList == null
        ? null
        : productList.length - publishedProducts!;
    final activeCampaigns = campaignList?.where((c) => c.isActive).length;
    final inactiveCampaigns = campaignList == null
        ? null
        : campaignList.length - activeCampaigns!;

    final tiles = <Widget>[
      _KpiTile(
        key: const ValueKey('supplier_kpi_requests'),
        icon: Icons.request_quote_outlined,
        label: AppStrings.supPanelKpiOpenRequests,
        value: _n(openCount),
        helper: AppStrings.supPanelKpiOpenRequestsHelper,
        highlight: (openCount ?? 0) > 0,
        onTap: () => context.go(AppRoutes.pazarTab(AppRoutes.pazarTabRequests)),
      ),
      _KpiTile(
        key: const ValueKey('supplier_kpi_products'),
        icon: Icons.inventory_2_outlined,
        label: AppStrings.supPanelKpiProducts,
        value: _withLimit(publishedProducts, entitlement?.supplierProductLimit),
        helper: _countHint(draftProducts, AppStrings.supPanelKpiDrafts),
        onTap: () => context.go(AppRoutes.pazarTab('urunler')),
      ),
      _KpiTile(
        key: const ValueKey('supplier_kpi_campaigns'),
        icon: Icons.campaign_outlined,
        label: AppStrings.supPanelKpiCampaigns,
        value: _withLimit(activeCampaigns, entitlement?.supplierCampaignLimit),
        helper: _countHint(inactiveCampaigns, AppStrings.supPanelKpiExpired),
        onTap: () => context.go(AppRoutes.pazarTab('kampanyalar')),
      ),
      _KpiTile(
        key: const ValueKey('supplier_kpi_leads'),
        icon: Icons.handshake_outlined,
        label: AppStrings.supPanelKpiLeads,
        value: _n(leadCount),
        helper: AppStrings.supPanelKpiLeadsHelper,
        highlight: (leadCount ?? 0) > 0,
        onTap: () => context.go(AppRoutes.pazarTab(AppRoutes.pazarTabRequests)),
      ),
    ];

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: AppSpacing.s),
              Expanded(child: tiles[1]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[2]),
              const SizedBox(width: AppSpacing.s),
              Expanded(child: tiles[3]),
            ],
          ),
        ),
      ],
    );
  }

  static String _n(int? v) => v == null ? '—' : '$v';

  /// "yayında / limit" — limit < 0 (sınırsız) veya bilinmiyorsa yalnız sayı.
  static String _withLimit(int? count, int? limit) {
    if (count == null) return '—';
    if (limit == null || limit < 0) return '$count';
    return '$count / $limit';
  }

  /// Yardımcı satır: "2 taslak" gibi; sıfır/bilinmiyor → boş (satır gizlenir).
  static String? _countHint(int? n, String suffix) {
    if (n == null || n <= 0) return null;
    return '$n $suffix';
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.helper,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? helper;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? AppColors.brandInk : AppColors.textSecondary;
    return PressScale(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: '$label $value',
        child: PremiumCard(
          onTap: onTap,
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.infoLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AppTypography.headlineSmall.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              // Yardımcı satır her kartta yer tutar → grid satırları hizalı.
              const SizedBox(height: 2),
              Text(
                helper ?? ' ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Hızlı işlemler
// ---------------------------------------------------------------------------

class _QuickActions extends ConsumerWidget {
  const _QuickActions({
    required this.products,
    required this.campaigns,
    required this.entitlement,
  });

  final List<B2bProduct> products;
  final List<B2bCampaign> campaigns;
  final BusinessEntitlements? entitlement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void addProduct() {
      // Limit dolduysa paywall; entitlement henüz yoksa form açılır (server
      // yine korur — Mağazam sekmesiyle aynı kural).
      final e = entitlement;
      final lock = e == null
          ? null
          : SupplierPaywall.productLock(e, products.length);
      if (lock != null) {
        showPaywallSheet(context, lock);
        return;
      }
      context.push(AppRoutes.b2bProductNew);
    }

    void addCampaign() {
      final e = entitlement;
      final active = campaigns.where((c) => c.isActive).length;
      final lock = e == null ? null : SupplierPaywall.campaignLock(e, active);
      if (lock != null) {
        showPaywallSheet(context, lock);
        return;
      }
      context.push(AppRoutes.b2bCampaignNew);
    }

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: QuickActionMini(
                  key: const ValueKey('supplier_quick_add_product'),
                  label: AppStrings.supPanelQuickAddProduct,
                  icon: Icons.add_box_outlined,
                  onTap: addProduct,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: QuickActionMini(
                  key: const ValueKey('supplier_quick_add_campaign'),
                  label: AppStrings.supPanelQuickAddCampaign,
                  icon: Icons.campaign_outlined,
                  onTap: addCampaign,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: QuickActionMini(
                  key: const ValueKey('supplier_quick_requests'),
                  label: AppStrings.supPanelQuickRequests,
                  icon: Icons.request_quote_outlined,
                  onTap: () => context.go(
                    AppRoutes.pazarTab(AppRoutes.pazarTabRequests),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: QuickActionMini(
                  key: const ValueKey('supplier_quick_edit_store'),
                  label: AppStrings.supPanelQuickEditStore,
                  icon: Icons.edit_outlined,
                  onTap: () => context.push(AppRoutes.b2bStoreEdit),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
