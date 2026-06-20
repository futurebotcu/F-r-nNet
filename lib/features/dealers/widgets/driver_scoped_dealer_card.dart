import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../models/dealer.dart';
import '../models/dealer_balance_summary.dart';
import '../models/dealer_transaction.dart';
import 'dealer_avatar.dart';

/// Şoför-scoped Bayiler ekranı için bayi kartı (Yol B+ UI hizalaması).
///
/// Normal `DealerListScreen._DealerCard` ile aynı görsel dili kullanır
/// (avatar + ad + bölge·çalışma tipi + hairline + bakiye footer + son
/// hareket) ama veri parent'tan prop olarak gelir. Hem patron scoped
/// shell (`DriverScopedDealerShell`) hem bireysel şoför panelinde
/// (`DriverHomeScreen`) kullanılır. Normal ekran dosyalarına dokunmaz.
class DriverScopedDealerCard extends StatelessWidget {
  const DriverScopedDealerCard({
    super.key,
    required this.dealer,
    this.balance,
    this.lastTx,
    this.onTap,
  });

  final Dealer dealer;

  /// Tam bayi bakiyesi (driver-scoped değil — bakiye hesabı değişmez).
  final DealerBalanceSummary? balance;

  /// Bu bayide şoförün en son hareketi (varsa).
  final DealerTransaction? lastTx;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.l),
      warm: !dealer.isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DealerAvatar(
                dealer: dealer,
                size: 42,
                palette: DealerAvatarPalette.autoActivity,
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
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
                        ),
                        if (!dealer.isActive)
                          _PassiveBadge(),
                      ],
                    ),
                    const SizedBox(height: 5),
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
          if (balance != null) ...[
            const SizedBox(height: AppSpacing.m),
            const Divider(
              height: 1,
              thickness: 0.6,
              color: AppColors.borderHairline,
            ),
            const SizedBox(height: AppSpacing.m),
            _BalanceFooter(balance: balance!, lastTx: lastTx),
          ],
        ],
      ),
    );
  }
}

class _PassiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const color = AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.6),
      ),
      child: Text(
        AppStrings.dealerCardPassiveBadge.toUpperCase(),
        style: const TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _BalanceFooter extends StatelessWidget {
  const _BalanceFooter({required this.balance, this.lastTx});
  final DealerBalanceSummary balance;
  final DealerTransaction? lastTx;

  @override
  Widget build(BuildContext context) {
    final value = balance.currentBalance;
    final color = value > 0
        ? AppColors.copper
        : value < 0
            ? AppColors.success
            : AppColors.textMuted;
    final label = value > 0
        ? AppStrings.dealerCardBalanceLabel
        : value < 0
            ? AppStrings.dealerCardCreditLabel
            : AppStrings.dealerCardClosedLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 2),
              Text(
                NumberFormatter.currency(value.abs()),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        if (lastTx != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.dealerCardLastTxLabel.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _shortLabel(lastTx!),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _shortLabel(DealerTransaction t) {
    final diff = DateTime.now().difference(t.createdAt).inDays;
    final ago = diff == 0 ? 'bugün' : '$diff g önce';
    switch (t.type) {
      case DealerTransactionType.delivery:
        return 'Teslim · $ago';
      case DealerTransactionType.returned:
        return 'İade · $ago';
      case DealerTransactionType.payment:
        return 'Ödeme · $ago';
      case DealerTransactionType.adjustment:
        return 'Düzeltme · $ago';
    }
  }
}
