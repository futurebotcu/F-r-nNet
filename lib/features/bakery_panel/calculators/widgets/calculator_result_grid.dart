import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/premium/stat_card.dart';
import '../../models/recipe.dart' show RecipeResult;

/// Hamur hesabı sonucu — toplam hamur, fire sonrası net hamur ve tahmini
/// adet kartları. Saf gösterim; matematik içermez.
class CalculatorResultGrid extends StatelessWidget {
  const CalculatorResultGrid({super.key, required this.result});

  final RecipeResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.scale_outlined,
                label: 'Toplam hamur',
                value: '${NumberFormatter.decimal(result.totalDoughKg)} kg',
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: StatCard(
                icon: Icons.cleaning_services_outlined,
                label: 'Net hamur',
                value:
                    '${NumberFormatter.decimal(result.doughAfterWasteKg)} kg',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        StatCard(
          warm: true,
          hero: true,
          icon: Icons.bakery_dining_outlined,
          label: 'Tahmini adet',
          value: NumberFormatter.integer(result.estimatedPieces),
          accent: AppColors.softGold,
        ),
      ],
    );
  }
}
