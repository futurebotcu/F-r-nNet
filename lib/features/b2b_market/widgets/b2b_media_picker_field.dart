// B2B Pazar — mock görsel alanı.
//
// GERÇEK DOSYA SEÇME / UPLOAD YOK (image_picker kullanılmaz). Yalnız kategori/
// placeholder görsel seçimi gibi davranır: kullanıcı hazır bir placeholder
// görsel seçer; bu seçim mock'tur ve backend'e yazılmaz. Video alanı bu
// sürümde yoktur.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

/// Seçilebilir placeholder görsel seçenekleri (gerçek görsel değil, ikon).
class B2bMediaOption {
  const B2bMediaOption(this.key, this.icon);
  final String key;
  final IconData icon;
}

const List<B2bMediaOption> kB2bMediaOptions = <B2bMediaOption>[
  B2bMediaOption('Un', Icons.grain_rounded),
  B2bMediaOption('Çuval', Icons.shopping_bag_outlined),
  B2bMediaOption('Maya', Icons.science_outlined),
  B2bMediaOption('Yağ', Icons.water_drop_outlined),
  B2bMediaOption('Ambalaj', Icons.inventory_2_outlined),
  B2bMediaOption('Ekipman', Icons.precision_manufacturing_outlined),
  B2bMediaOption('Mağaza', Icons.storefront_outlined),
];

class B2bMediaPickerField extends StatelessWidget {
  const B2bMediaPickerField({
    super.key,
    required this.label,
    required this.selectedKey,
    required this.onSelect,
  });

  final String label;

  /// Seçili placeholder anahtarı; `null` → seçilmemiş.
  final String? selectedKey;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(color: AppColors.borderHairline, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                    color: AppColors.brandLemonPressed,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Görsel ekle',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (selectedKey != null)
                    GestureDetector(
                      onTap: () => onSelect(null),
                      child: const Text(
                        'Kaldır',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: kB2bMediaOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final o = kB2bMediaOptions[i];
                    final selected = o.key == selectedKey;
                    return _Tile(
                      option: o,
                      selected: selected,
                      onTap: () => onSelect(selected ? null : o.key),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Text(
                selectedKey == null
                    ? 'Örnek bir placeholder görsel seç (mock — dosya yüklenmez).'
                    : 'Seçilen placeholder: $selectedKey',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final B2bMediaOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 60,
        decoration: BoxDecoration(
          color: selected ? AppColors.brandLemonPale : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.s),
          border: Border.all(
            color: selected
                ? AppColors.brandLemonPressed
                : AppColors.borderHairline,
            width: selected ? 1.2 : 0.8,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                option.icon,
                size: 24,
                color: selected
                    ? AppColors.brandLemonPressed
                    : AppColors.textSecondary,
              ),
            ),
            if (selected)
              const Positioned(
                top: 3,
                right: 3,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: AppColors.brandLemonPressed,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
