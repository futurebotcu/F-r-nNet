// B2B Pazar — yatay kategori filtre chip satırı.
//
// Marketplace'in _ListingTypeChipRow deseninin birebir muadili: ilk chip
// "Tümü" (null), sonra kategoriler. Kanonik DealerFilterChip kullanır.

import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../dealers/widgets/dealer_filter_chip.dart';

class B2bCategoryChipRow extends StatelessWidget {
  const B2bCategoryChipRow({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String> categories;

  /// Seçili kategori; `null` = Tümü.
  final String? selected;
  final void Function(String? category) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        children: [
          DealerFilterChip(
            label: 'Tümü',
            selected: selected == null,
            onSelected: (_) => onSelect(null),
          ),
          const SizedBox(width: AppSpacing.s),
          for (final c in categories) ...[
            DealerFilterChip(
              label: c,
              selected: selected == c,
              onSelected: (_) => onSelect(c),
            ),
            const SizedBox(width: AppSpacing.s),
          ],
        ],
      ),
    );
  }
}
