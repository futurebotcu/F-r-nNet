import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../models/dealer.dart';
import '../providers/dealer_providers.dart';

/// Toptancı kullanıcı için müşteri/bayi listesi.
///
/// Altyapı `dealers` + `dealer_transactions` + ... ile paylaşılır;
/// `customer_type = 'wholesale_customer'` ile süzülür. Detay ekranı yine
/// mevcut `DealerDetailScreen` (aksiyon mantığı aynı: teslimat / tahsilat /
/// iade / düzeltme / fiyat / not).
///
/// UI etiketleri toptancıya uygun: "Müşteriler", "Müşteri Ekle".
class WholesaleCustomersScreen extends ConsumerStatefulWidget {
  const WholesaleCustomersScreen({super.key});

  @override
  ConsumerState<WholesaleCustomersScreen> createState() =>
      _WholesaleCustomersScreenState();
}

class _WholesaleCustomersScreenState
    extends ConsumerState<WholesaleCustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      dealersByTypeProvider(DealerCustomerType.wholesaleCustomer),
    );

    return PremiumScaffold(
      appBar: AppBar(
        title: const Text('Müşteriler'),
        actions: [
          // Toptancı da patron/owner: aynı şoför yönetimi (davet/atama/özet)
          // mevcut DriverListScreen ile reuse edilir (ayrı sistem yok).
          IconButton(
            tooltip: 'Şoförler',
            onPressed: () => context.push(AppRoutes.dealerDrivers),
            icon: const Icon(Icons.local_shipping_outlined),
          ),
          IconButton(
            tooltip: 'Müşteri ekle',
            onPressed: () => context.push(AppRoutes.wholesaleCustomerNew),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.wholesaleCustomerNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Müşteri ekle'),
        backgroundColor: AppColors.copper,
        foregroundColor: AppColors.brandInk,
      ),
      body: SafeArea(
        top: false,
        child: async.when(
          skipLoadingOnReload: true,
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
          error: (e, _) => ErrorRetryState(
            onRetry: () => ref.invalidate(
              dealersByTypeProvider(DealerCustomerType.wholesaleCustomer),
            ),
          ),
          data: (all) {
            if (all.isEmpty) {
              return EmptyState(
                title: 'Henüz müşterin yok',
                subtitle:
                    'Müşterilerini ekledikçe teslimat, tahsilat ve hesap '
                    'durumunu tek yerden yöneteceksin.',
                icon: Icons.storefront_rounded,
                actionLabel: 'İlk müşteriyi ekle',
                onAction: () => context.push(AppRoutes.wholesaleCustomerNew),
              );
            }
            final q = _query.toLowerCase();
            final filtered = q.isEmpty
                ? all
                : all
                      .where(
                        (d) =>
                            d.name.toLowerCase().contains(q) ||
                            d.area.toLowerCase().contains(q) ||
                            d.contactName.toLowerCase().contains(q),
                      )
                      .toList();
            return ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl + 40),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    AppSpacing.s,
                    AppSpacing.pageH,
                    AppSpacing.s,
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Müşteri adı, bölge, kişi ara…',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.softGold,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.l,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SectionLabel(
                  title: 'Müşterilerim',
                  topGap: AppSpacing.s,
                  bottomGap: AppSpacing.s,
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageH,
                    ),
                    child: PremiumCard(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Text(
                        'Filtreyle eşleşen müşteri yok.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  for (final d in filtered)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageH,
                        0,
                        AppSpacing.pageH,
                        AppSpacing.s,
                      ),
                      child: _CustomerCard(dealer: d),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CustomerCard extends ConsumerWidget {
  const _CustomerCard({required this.dealer});
  final Dealer dealer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceSummaryProvider(dealer.id));
    return PremiumCard(
      onTap: () => context.push('${AppRoutes.dealers}/${dealer.id}'),
      padding: const EdgeInsets.all(AppSpacing.l),
      warm: !dealer.isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: dealer.isActive
                      ? AppColors.softGold.withValues(alpha: 0.14)
                      : AppColors.surfaceLine.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                alignment: Alignment.center,
                child: Text(
                  dealer.name.isNotEmpty ? dealer.name[0].toUpperCase() : 'M',
                  style: TextStyle(
                    color: dealer.isActive
                        ? AppColors.softGold
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dealer.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (dealer.area.isNotEmpty) dealer.area,
                        dealer.workingType.label,
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          const Divider(
            height: 1,
            thickness: 0.6,
            color: AppColors.borderHairline,
          ),
          const SizedBox(height: AppSpacing.m),
          balance.when(
            loading: () => const SizedBox(
              height: 36,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                ),
              ),
            ),
            error: (e, _) => Text(
              'Bakiye okunamadı: $e',
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
            data: (s) {
              final balanceColor = s.currentBalance > 0
                  ? AppColors.copper
                  : s.currentBalance < 0
                  ? AppColors.success
                  : AppColors.textSecondary;
              final label = s.currentBalance > 0
                  ? 'Bakiye'
                  : s.currentBalance < 0
                  ? 'Alacak'
                  : 'Kapalı';
              return Row(
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    NumberFormatter.currency(s.currentBalance.abs()),
                    style: TextStyle(
                      color: balanceColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
