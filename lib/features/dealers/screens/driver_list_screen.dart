import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../providers/dealer_providers.dart';

/// Şoförler — patron/ticari kullanıcı yönetim listesi (Sprint 2).
///
/// En üstte "Genel Hesap" (Sprint 5'te dolacak placeholder), altında aktif/pasif
/// şoför listesi + "Şoför Ekle". Şoför login erişimi bu sprintte AÇILMADI.
class DriverListScreen extends ConsumerWidget {
  const DriverListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driversListProvider);
    return PremiumScaffold(
      appBar: AppBar(
        title: const Text('Şoförler'),
        actions: [
          IconButton(
            tooltip: 'Şoför Ekle',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => context.push(AppRoutes.dealerDriverNew),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Padding(
            padding: EdgeInsets.all(AppSpacing.l),
            child: Center(
              child: Text(
                'Şoförler yüklenemedi. Tekrar deneyin.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          data: (drivers) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.m,
                AppSpacing.pageH,
                AppSpacing.xxl,
              ),
              children: [
                const _GeneralAccountCard(),
                const SizedBox(height: AppSpacing.m),
                if (drivers.isEmpty)
                  const _DriversEmpty()
                else
                  ...[
                    for (final d in drivers) ...[
                      _DriverRow(
                        id: d.id,
                        name: d.name,
                        phone: d.phone,
                        isActive: d.isActive,
                        assignedCount: d.assignedDealerCount,
                      ),
                      const SizedBox(height: AppSpacing.s),
                    ],
                  ],
                const SizedBox(height: AppSpacing.m),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.dealerDriverNew),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Şoför Ekle'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandLemon,
                      foregroundColor: AppColors.brandInk,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14.5),
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

/// Genel Hesap — Sprint 5'te tüm şoför özeti gelecek; şimdilik placeholder.
class _GeneralAccountCard extends StatelessWidget {
  const _GeneralAccountCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.softGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              child: const Icon(Icons.summarize_rounded,
                  color: AppColors.softGold, size: 20),
            ),
            const SizedBox(width: AppSpacing.m),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Genel Hesap',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text(
                    'Tüm şoför özeti yakında (Sprint 5).',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600),
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

class _DriverRow extends StatelessWidget {
  const _DriverRow({
    required this.id,
    required this.name,
    required this.phone,
    required this.isActive,
    required this.assignedCount,
  });
  final String id;
  final String name;
  final String phone;
  final bool isActive;
  final int assignedCount;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(AppRoutes.dealerDriver(id)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            _DriverInitial(name: name),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      if (!isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: const Text('Pasif',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (phone.isNotEmpty) phone,
                      '$assignedCount bayi',
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DriverInitial extends StatelessWidget {
  const _DriverInitial({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brandLemonPale,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.brandLemonSoft, width: 0.8),
      ),
      child: Text(
        letter,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.brandInk),
      ),
    );
  }
}

class _DriversEmpty extends StatelessWidget {
  const _DriversEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.softGold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: const Icon(Icons.local_shipping_outlined,
                color: AppColors.softGold, size: 26),
          ),
          const SizedBox(height: AppSpacing.m),
          const Text('Henüz şoför yok',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
            'Şoför ekleyip kendi bayilerinden bazılarını ona atayabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}
