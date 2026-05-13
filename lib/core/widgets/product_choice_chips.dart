import 'package:flutter/material.dart';

import '../constants/app_products.dart';

/// Ekmek/Simit/Pide… hızlı seçim chip'leri.
class ProductChoiceChips extends StatelessWidget {
  const ProductChoiceChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.products = AppProducts.defaults,
  });

  final String? selected;
  final ValueChanged<String> onSelected;
  final List<String> products;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: products.map((p) {
        final isSelected = p == selected;
        return ChoiceChip(
          label: Text(p),
          selected: isSelected,
          onSelected: (_) => onSelected(p),
        );
      }).toList(),
    );
  }
}
