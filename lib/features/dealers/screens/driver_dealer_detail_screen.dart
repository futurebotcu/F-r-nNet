import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/dealer_transaction.dart';
import '../providers/dealer_providers.dart';

/// Şoför için READ-ONLY bayi detayı (Sprint 3).
///
/// Bayi temel bilgisi + son bakiye + son hareketler. Hiçbir patron/işlem
/// aksiyonu (teslimat/tahsilat/iade/düzeltme/gün sonu/rapor) YOK. Veriye erişim
/// atama-bazlı RLS ile sınırlıdır.
class DriverDealerDetailScreen extends ConsumerWidget {
  const DriverDealerDetailScreen({super.key, required this.dealerId});
  final String dealerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealerAsync = ref.watch(dealerByIdProvider(dealerId));
    final balanceAsync = ref.watch(balanceSummaryProvider(dealerId));
    final txAsync = ref.watch(transactionsByDealerProvider(dealerId));

    return PremiumScaffold(
      appBar: AppBar(
        title: Text(dealerAsync.valueOrNull?.name ?? 'Bayi'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            // ── Bayi bilgisi ──
            dealerAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (d) {
                if (d == null) return const SizedBox.shrink();
                final loc =
                    [d.city, d.area].where((e) => e.isNotEmpty).join(' · ');
                return PremiumCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        if (d.phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(d.phone,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ],
                        if (loc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(loc,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.m),

            // ── Bakiye özeti (read-only) ──
            balanceAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.m),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (b) => PremiumCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Güncel Bakiye',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                      ),
                      Text(
                        '₺${b.currentBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: b.currentBalance > 0
                              ? AppColors.danger
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            const Text('Son Hareketler',
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.s),

            // ── Hareketler (read-only) ──
            txAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.m),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text('Hareketler yüklenemedi.',
                  style: TextStyle(color: AppColors.textSecondary)),
              data: (txs) {
                if (txs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      border: Border.all(
                          color: AppColors.borderHairline, width: 0.8),
                    ),
                    child: const Text('Henüz hareket yok.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600)),
                  );
                }
                return Column(
                  children: [
                    for (final t in txs.take(50)) ...[
                      _TxRow(tx: t),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});
  final DealerTransaction tx;

  @override
  Widget build(BuildContext context) {
    final negative = tx.type == DealerTransactionType.payment ||
        tx.type == DealerTransactionType.returned;
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.productName?.isNotEmpty == true
                        ? '${tx.type.label} · ${tx.productName}'
                        : tx.type.label,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  if (tx.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(tx.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Text(
              '${negative ? '−' : '+'}₺${tx.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: negative ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
