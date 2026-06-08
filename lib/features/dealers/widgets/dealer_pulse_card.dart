import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../models/dealer_pulse_snapshot.dart';
import '../providers/dealer_providers.dart';

/// Bayi Defteri "Nabız" kartı (Sprint 3.5).
///
/// Genel Bakış ekranında KPI grid ile Son Hareketler arasına monte edilir.
/// 3 metrik (Teslimat / Tahsilat / Net Değişim) için bugünün değerini
/// EMA baseline (son 20 non-empty gün) ile karşılaştırır; arrow + delta%
/// + "normalden" insight gösterir.
///
/// Concept inspired by evan361425/flutter-pos-system GoalsCardView
/// (Apache-2.0): EMA-over-20-non-empty-days baseline + bugünü hariç
/// tutma pattern'i. Donor widget kodu kopyalanmadı; FırınNet style
/// (compact 3-row, white/lemon) sifirdan yazildi. See
/// THIRD_PARTY_LICENSES.md.
class DealerPulseCard extends ConsumerWidget {
  const DealerPulseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulseAsync = ref.watch(dealerPulseProvider);
    return pulseAsync.when(
      loading: () => const _PulseLoadingCard(),
      error: (e, _) => _PulseErrorCard(message: '$e'),
      data: (snap) => _PulseCard(snapshot: snap),
    );
  }
}

class _PulseLoadingCard extends StatelessWidget {
  const _PulseLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.xl,
      ),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PulseErrorCard extends StatelessWidget {
  const _PulseErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
      ),
    );
  }
}

class _PulseCard extends StatelessWidget {
  const _PulseCard({required this.snapshot});

  final DealerPulseSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart_rounded,
                size: 18,
                color: AppColors.copper,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                AppStrings.dealerPulseTitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.copper,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.dealerPulseSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          if (!snapshot.hasSufficientBaseline)
            const _InsufficientBaseline()
          else ...[
            _PulseRow(
              label: AppStrings.dealerPulseMetricDelivery,
              today: snapshot.todayDelivery,
              baseline: snapshot.baselineDelivery,
              accent: AppColors.copper,
            ),
            const _RowDivider(),
            _PulseRow(
              label: AppStrings.dealerPulseMetricPayment,
              today: snapshot.todayPayment,
              baseline: snapshot.baselinePayment,
              accent: AppColors.success,
            ),
            const _RowDivider(),
            _PulseRow(
              label: AppStrings.dealerPulseMetricNetChange,
              today: snapshot.todayNetChange,
              baseline: snapshot.baselineNetChange,
              accent: AppColors.softGold,
              isSigned: true,
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '${snapshot.baselineDays} günlük baseline',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Divider(height: 0.5, thickness: 0.5, color: Color(0xFFEFE6DB)),
    );
  }
}

class _InsufficientBaseline extends StatelessWidget {
  const _InsufficientBaseline();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        children: [
          const Icon(
            Icons.timelapse_rounded,
            size: 22,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.dealerPulseInsufficientTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.dealerPulseInsufficientBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRow extends StatelessWidget {
  const _PulseRow({
    required this.label,
    required this.today,
    required this.baseline,
    required this.accent,
    this.isSigned = false,
  });

  final String label;
  final double today;
  final double baseline;
  final Color accent;

  /// true ise (örn. Net Değişim) tutar işaretli gösterilir
  /// (negatif → −₺X). Diğer metrikler gross pozitif.
  final bool isSigned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = today - baseline;
    final deltaPct = baseline == 0
        ? null
        : ((today - baseline) / baseline * 100);
    final direction = _Direction.fromDelta(delta);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatToday(today, isSigned: isSigned),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(direction.icon, size: 16, color: direction.color),
                  const SizedBox(width: 4),
                  Text(
                    _formatDelta(deltaPct, direction),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: direction.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${NumberFormatter.currency(baseline.abs())} '
                '${AppStrings.dealerPulseBaselineSuffix}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatToday(double value, {required bool isSigned}) {
    if (!isSigned) return NumberFormatter.currency(value.abs());
    if (value == 0) return NumberFormatter.currency(0);
    final sign = value >= 0 ? '+' : '−';
    return '$sign${NumberFormatter.currency(value.abs())}';
  }

  String _formatDelta(double? pct, _Direction d) {
    if (pct == null) {
      // Baseline 0 olduğunda yüzde tanımsız; sadece "yeni" göster.
      return d == _Direction.flat ? AppStrings.dealerPulseFlat : 'yeni';
    }
    final rounded = pct.abs().round();
    if (d == _Direction.flat) return AppStrings.dealerPulseFlat;
    final sign = pct > 0 ? '+' : '−';
    return '$sign%$rounded';
  }
}

enum _Direction {
  up,
  down,
  flat;

  static _Direction fromDelta(double d) {
    if (d > 0.01) return _Direction.up;
    if (d < -0.01) return _Direction.down;
    return _Direction.flat;
  }

  IconData get icon {
    switch (this) {
      case _Direction.up:
        return Icons.arrow_upward_rounded;
      case _Direction.down:
        return Icons.arrow_downward_rounded;
      case _Direction.flat:
        return Icons.remove_rounded;
    }
  }

  Color get color {
    switch (this) {
      case _Direction.up:
        return Color(0xFF10B981);
      case _Direction.down:
        return Color(0xFFEF4444);
      case _Direction.flat:
        return AppColors.textMuted;
    }
  }
}
