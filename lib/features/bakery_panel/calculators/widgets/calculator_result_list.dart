import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/premium/premium_card.dart';
import '../../../../core/widgets/premium/stat_card.dart';

/// Tek bir sonuç satırı (StatCard'a dönüşür). Saf gösterim verisi.
class CalcResultLine {
  const CalcResultLine(this.label, this.value, {this.icon, this.hero = false});

  final String label;
  final String value;
  final IconData? icon;

  /// `true` ise vurgulu (büyük) kart.
  final bool hero;
}

/// Hesaplama sonucu listesi — opsiyonel uyarı bandı + StatCard'lar.
///
/// Matematik içermez; yalnız servis çıktısını gösterir. Tüm modüller bu
/// widget ile sade ve tutarlı sonuç gösterir.
class CalculatorResultList extends StatelessWidget {
  const CalculatorResultList({
    super.key,
    required this.lines,
    this.warnings = const <String>[],
  });

  final List<CalcResultLine> lines;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final w in warnings) ...[
          _WarningBanner(message: w),
          const SizedBox(height: AppSpacing.s),
        ],
        for (var i = 0; i < lines.length; i++) ...[
          StatCard(
            icon: lines[i].icon,
            label: lines[i].label,
            value: lines[i].value,
            hero: lines[i].hero,
            warm: lines[i].hero,
            accent: lines[i].hero ? AppColors.softGold : null,
          ),
          if (i != lines.length - 1) const SizedBox(height: AppSpacing.m),
        ],
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.softGold,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
