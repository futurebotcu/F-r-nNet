import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/premium/premium_card.dart';
import '../../../../core/widgets/premium/premium_scaffold.dart';

/// Hesaplama modül ekranları için ortak iskelet.
///
/// Üstte opsiyonel ipucu, ardından girdi alanları, "Hesapla" butonu ve
/// (varsa) sonuç bölümü. Matematik/iş mantığı içermez — yalnız düzen verir;
/// her modül kendi girdi widget'larını ve sonuç widget'ını besler.
class CalculatorFormScaffold extends StatelessWidget {
  const CalculatorFormScaffold({
    super.key,
    required this.title,
    required this.inputs,
    required this.onCalculate,
    this.result,
    this.hint,
    this.calculateLabel = 'Hesapla',
  });

  final String title;
  final List<Widget> inputs;
  final VoidCallback onCalculate;

  /// Sonuç bölümü — null ise henüz hesaplanmadı.
  final Widget? result;
  final String? hint;
  final String calculateLabel;

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            if (hint != null) ...[
              _Hint(text: hint!),
              const SizedBox(height: AppSpacing.l),
            ],
            for (var i = 0; i < inputs.length; i++) ...[
              inputs[i],
              if (i != inputs.length - 1) const SizedBox(height: AppSpacing.s),
            ],
            const SizedBox(height: AppSpacing.l),
            AppPrimaryButton(
              label: calculateLabel,
              icon: Icons.calculate_rounded,
              onPressed: onCalculate,
            ),
            if (result != null) ...[
              const SizedBox(height: AppSpacing.xl),
              const _ResultSectionLabel(),
              result!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.softGold, size: 18),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSectionLabel extends StatelessWidget {
  const _ResultSectionLabel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(2, 0, 0, AppSpacing.s),
      child: Text(
        'SONUÇ',
        style: TextStyle(
          color: AppColors.softGold,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
