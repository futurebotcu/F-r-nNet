import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import 'interactions.dart';
import '../constants/app_products.dart';

/// Ekmek/Simit/Pide… hızlı seçim chip'leri.
///
/// V1.4 — Sprint A: sabit ürün listesinin sonuna "Diğer" chip'i eklenir.
/// "Diğer" seçilince inline `TextField` belirir; her keystroke'ta
/// [onSelected] güncellenir (trim'lenmiş değer). Boş bırakılırsa caller
/// `_product == null || isEmpty` kontrolüyle kaydı engeller.
class ProductChoiceChips extends StatefulWidget {
  const ProductChoiceChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.products = AppProducts.defaults,
    this.otherChipLabel = 'Diğer',
    this.otherFieldLabel = 'Ürün adı',
    this.otherFieldHint = 'Örn. Tahinli, Kurabiye',
  });

  final String? selected;
  final ValueChanged<String> onSelected;
  final List<String> products;
  final String otherChipLabel;
  final String otherFieldLabel;
  final String otherFieldHint;

  @override
  State<ProductChoiceChips> createState() => _ProductChoiceChipsState();
}

class _ProductChoiceChipsState extends State<ProductChoiceChips> {
  late final TextEditingController _otherCtrl;
  bool _otherMode = false;

  @override
  void initState() {
    super.initState();
    _otherCtrl = TextEditingController();
    _syncFromSelected();
  }

  @override
  void didUpdateWidget(covariant ProductChoiceChips old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _syncFromSelected();
  }

  void _syncFromSelected() {
    final v = widget.selected;
    if (v == null || v.isEmpty) {
      // selected temizlenirse Diğer modu kapalı kalır.
      return;
    }
    final inPredefined = widget.products.contains(v);
    if (inPredefined) {
      if (_otherMode) {
        _otherMode = false;
        _otherCtrl.clear();
      }
    } else {
      // Predefined dışı bir değer geldi — Diğer modunu aç ve TextField'ı doldur.
      _otherMode = true;
      if (_otherCtrl.text != v) _otherCtrl.text = v;
    }
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  void _onPredefined(String p) {
    setState(() {
      _otherMode = false;
      _otherCtrl.clear();
    });
    widget.onSelected(p);
  }

  void _onOtherChip() {
    setState(() => _otherMode = true);
    // Mevcut TextField içeriğini yansıt — boşsa selected boş string olur ve
    // caller boş guard'ına takılır.
    widget.onSelected(_otherCtrl.text.trim());
  }

  void _onOtherChanged(String v) {
    widget.onSelected(v.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final p in widget.products)
              PressScale(
                onTap: null,
                child: ChoiceChip(
                  label: Text(p),
                  selected: !_otherMode && p == widget.selected,
                  onSelected: (_) => _onPredefined(p),
                  selectedColor: AppColors.copper,
                  backgroundColor: AppColors.surfaceVariant,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
              ),
            PressScale(
              onTap: null,
              child: ChoiceChip(
                label: Text(widget.otherChipLabel),
                selected: _otherMode,
                onSelected: (_) => _onOtherChip(),
                selectedColor: AppColors.copper,
                backgroundColor: AppColors.surfaceVariant,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
              ),
            ),
          ],
        ),
        if (_otherMode) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _otherCtrl,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: widget.otherFieldLabel,
              hintText: widget.otherFieldHint,
            ),
            onChanged: _onOtherChanged,
          ),
        ],
      ],
    );
  }
}
