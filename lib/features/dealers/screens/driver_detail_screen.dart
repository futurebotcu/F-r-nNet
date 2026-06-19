import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/dealer.dart';
import '../providers/dealer_providers.dart';

/// Şoför detayı (Sprint 2): bilgiler + aktif/pasif + atanmış bayiler + "Bayi Ata".
/// İşlem özeti Sprint 3'te aktif olacak (driver_id bu sprintte yazılmıyor) →
/// placeholder.
class DriverDetailScreen extends ConsumerWidget {
  const DriverDetailScreen({super.key, required this.driverId});
  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverAsync = ref.watch(driverByIdProvider(driverId));
    return PremiumScaffold(
      appBar: AppBar(
        title: const Text('Şoför'),
        actions: [
          IconButton(
            tooltip: 'Bayileri Düzenle',
            icon: const Icon(Icons.edit_location_alt_outlined),
            onPressed: () =>
                context.push(AppRoutes.dealerDriverAssign(driverId)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: driverAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Şoför yüklenemedi.',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          data: (driver) {
            if (driver == null) {
              return const Center(
                child: Text('Şoför bulunamadı.',
                    style: TextStyle(color: AppColors.textSecondary)),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.m,
                AppSpacing.pageH,
                AppSpacing.xxl,
              ),
              children: [
                // ── Bilgi kartı + aktif/pasif ──
                PremiumCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driver.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        if (driver.phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(driver.phone,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ],
                        if (driver.note.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s),
                          Text(driver.note,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.4)),
                        ],
                        const SizedBox(height: AppSpacing.s),
                        Row(
                          children: [
                            const Text('Aktif',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const Spacer(),
                            Switch(
                              value: driver.isActive,
                              onChanged: (v) async {
                                await ref
                                    .read(dealerRepositoryProvider)
                                    .updateDriver(
                                        driver.copyWith(isActive: v));
                                ref.invalidate(driverByIdProvider(driverId));
                                ref.invalidate(driversListProvider);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),

                // ── Atanmış bayiler ──
                Row(
                  children: [
                    const Text('Atanmış Bayiler',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => context
                          .push(AppRoutes.dealerDriverAssign(driverId)),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Bayi Ata'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _AssignedDealers(driverId: driverId),

                const SizedBox(height: AppSpacing.l),

                // ── İşlemler placeholder (Sprint 3) ──
                PremiumCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            color: AppColors.textMuted, size: 20),
                        const SizedBox(width: AppSpacing.m),
                        const Expanded(
                          child: Text(
                            'İşlem özeti (teslimat/tahsilat/iade) Sprint 3\'te '
                            'aktif olacak.',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                                height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AssignedDealers extends ConsumerWidget {
  const _AssignedDealers({required this.driverId});
  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idsAsync = ref.watch(assignedDealerIdsProvider(driverId));
    final dealersAsync = ref.watch(dealersListProvider);
    return idsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.m),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Text('Atamalar yüklenemedi.',
          style: TextStyle(color: AppColors.textSecondary)),
      data: (ids) {
        if (ids.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppColors.borderHairline, width: 0.8),
            ),
            child: const Text(
              'Henüz bayi atanmadı. "Bayi Ata" ile kendi bayilerinden seç.',
              style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600),
            ),
          );
        }
        final dealers = dealersAsync.valueOrNull ?? const <Dealer>[];
        final byId = {for (final d in dealers) d.id: d};
        return Column(
          children: [
            for (final id in ids)
              PremiumCard(
                padding: EdgeInsets.zero,
                onTap: () => context.push('${AppRoutes.dealers}/$id'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          byId[id]?.name ?? 'Bayi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
