import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../models/dealer_transaction.dart';

/// Şoför-scoped Hareketler ekranı için işlem satırı (Yol B+ UI hizalaması).
///
/// Normal `DealerActivityScreen._ActivityRow` ile aynı görsel dili
/// kullanır: 36×36 renkli ikon kutucuğu + bayi adı + relatif tarih + renk
/// kodlu işaretli tutar (tabularFigures). Bir [PremiumCard] içinde divider
/// ile dizilmek üzere tasarlandı. Normal ekran dosyalarına dokunmaz.
class DriverScopedTxTile extends StatelessWidget {
  const DriverScopedTxTile({
    super.key,
    required this.tx,
    required this.dealerName,
    this.onTap,
  });

  final DealerTransaction tx;
  final String dealerName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, sign) = _meta(tx.type);
    final formatted = '$sign${NumberFormatter.currency(tx.amount.abs())}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.s),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$dealerName · ${tx.type.label}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _shortDate(tx.createdAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Text(
              formatted,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _meta(DealerTransactionType t) {
    switch (t) {
      case DealerTransactionType.delivery:
        return (Icons.bakery_dining_rounded, AppColors.copper, '+');
      case DealerTransactionType.returned:
        return (Icons.assignment_returned_rounded, AppColors.info, '−');
      case DealerTransactionType.payment:
        return (Icons.payments_rounded, AppColors.success, '−');
      case DealerTransactionType.adjustment:
        return (Icons.tune_rounded, AppColors.softGold, '±');
    }
  }

  String _shortDate(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final atDay = DateTime(at.year, at.month, at.day);
    if (atDay == today) return DateFormat('HH:mm').format(at);
    if (atDay == today.subtract(const Duration(days: 1))) {
      return AppStrings.dealerActivityGroupYesterday;
    }
    return DateFormat('d MMM', 'tr_TR').format(at);
  }
}

/// Tarih bucket'ı (Bugün / Dün / Bu hafta / Daha eski).
class TxDateGroup {
  const TxDateGroup({required this.label, required this.txs});
  final String label;
  final List<DealerTransaction> txs;
}

/// İşlemleri normal Hareketler ekranıyla aynı bucket düzeninde gruplar.
List<TxDateGroup> groupDriverTxByDate(List<DealerTransaction> txs) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekStart = today.subtract(Duration(days: today.weekday - 1));

  final buckets = <String, List<DealerTransaction>>{
    AppStrings.dealerActivityGroupToday: [],
    AppStrings.dealerActivityGroupYesterday: [],
    AppStrings.dealerActivityGroupThisWeek: [],
    AppStrings.dealerActivityGroupOlder: [],
  };
  for (final t in txs) {
    final at = t.createdAt;
    if (!at.isBefore(today)) {
      buckets[AppStrings.dealerActivityGroupToday]!.add(t);
    } else if (!at.isBefore(yesterday)) {
      buckets[AppStrings.dealerActivityGroupYesterday]!.add(t);
    } else if (!at.isBefore(weekStart)) {
      buckets[AppStrings.dealerActivityGroupThisWeek]!.add(t);
    } else {
      buckets[AppStrings.dealerActivityGroupOlder]!.add(t);
    }
  }
  const order = [
    AppStrings.dealerActivityGroupToday,
    AppStrings.dealerActivityGroupYesterday,
    AppStrings.dealerActivityGroupThisWeek,
    AppStrings.dealerActivityGroupOlder,
  ];
  return [
    for (final label in order)
      if (buckets[label]!.isNotEmpty)
        TxDateGroup(label: label, txs: buckets[label]!),
  ];
}

/// Tarihe göre gruplanmış işlem listesi — normal Hareketler ekranının
/// kart+divider dilini birebir kullanır. Hem patron scoped Hareketler hem
/// bireysel Hareketlerim için paylaşılır.
class DriverScopedTxList extends StatelessWidget {
  const DriverScopedTxList({
    super.key,
    required this.txs,
    required this.dealerNames,
    this.onTapTx,
    this.padding,
  });

  final List<DealerTransaction> txs;
  final Map<String, String> dealerNames;
  final void Function(DealerTransaction tx)? onTapTx;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final groups = groupDriverTxByDate(txs);
    return ListView.builder(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.s,
            AppSpacing.pageH,
            AppSpacing.xl,
          ),
      itemCount: groups.length,
      itemBuilder: (_, gi) {
        final g = groups[gi];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.s,
                  bottom: AppSpacing.s,
                ),
                child: Text(
                  g.label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                ),
              ),
              PremiumCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < g.txs.length; i++) ...[
                      DriverScopedTxTile(
                        tx: g.txs[i],
                        dealerName: dealerNames[g.txs[i].dealerId] ?? '—',
                        onTap: onTapTx == null
                            ? null
                            : () => onTapTx!(g.txs[i]),
                      ),
                      if (i < g.txs.length - 1)
                        const Divider(
                          height: 0.6,
                          thickness: 0.6,
                          color: AppColors.borderHairline,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
