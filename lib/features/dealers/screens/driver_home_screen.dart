import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../providers/dealer_providers.dart';

/// Şoför ana ekranı (Sprint 3) — READ-ONLY "Bana Atanan Bayiler".
///
/// Bireysel kullanıcı, ticari kullanıcı tarafından şoför olarak eklenip bayi
/// atandıysa burada yalnız o bayileri görür. İşlem/teslimat/tahsilat/gün sonu/
/// rapor gibi patron aksiyonları YOK. Yazma erişimi kapalı (RLS + UI).
class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dealersAssignedToMeProvider);
    return PremiumScaffold(
      appBar: AppBar(title: const Text('Bana Atanan Bayiler')),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Bayiler yüklenemedi. Tekrar deneyin.',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          data: (dealers) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.m,
                AppSpacing.pageH,
                AppSpacing.xxl,
              ),
              children: [
                const Text(
                  'Fırın tarafından sana atanan bayileri burada görebilirsin.',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.m),
                if (dealers.isEmpty)
                  const _DriverEmpty()
                else
                  ...[
                    for (final d in dealers) ...[
                      _AssignedDealerCard(
                        id: d.id,
                        name: d.name,
                        phone: d.phone,
                        area: d.area,
                        city: d.city,
                      ),
                      const SizedBox(height: AppSpacing.s),
                    ],
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AssignedDealerCard extends StatelessWidget {
  const _AssignedDealerCard({
    required this.id,
    required this.name,
    required this.phone,
    required this.area,
    required this.city,
  });
  final String id;
  final String name;
  final String phone;
  final String area;
  final String city;

  @override
  Widget build(BuildContext context) {
    final loc = [city, area].where((e) => e.isNotEmpty).join(' · ');
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(AppRoutes.driverDealerDetail(id)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            const Icon(Icons.storefront_rounded,
                color: AppColors.brandLemonPressed, size: 22),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  if (phone.isNotEmpty || loc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [if (phone.isNotEmpty) phone, if (loc.isNotEmpty) loc]
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
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

class _DriverEmpty extends StatelessWidget {
  const _DriverEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
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
          const Text('Henüz sana atanmış bayi yok',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
            'Fırın sana bayi atadığında burada görünecek.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}
