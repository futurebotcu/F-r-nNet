import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/partner_business.dart';

/// Arama + şehir/ilçe/kategori filtre barı.
///
/// Seçenekler sabit Türkiye dataseti DEĞİL — yüklü aktif kayıtlardan türetilir
/// (V1 kapsam kuralı). Şehir değişince seçili ilçe o şehirde yoksa sıfırlanır.
class PartnerFilterBar extends StatelessWidget {
  const PartnerFilterBar({
    super.key,
    required this.all,
    required this.filter,
    required this.onChanged,
  });

  final List<PartnerBusiness> all;
  final PartnerBusinessFilter filter;
  final ValueChanged<PartnerBusinessFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final cities = PartnerBusinessFilter.cityOptions(all);
    final districts = PartnerBusinessFilter.districtOptions(
      all,
      city: filter.city,
    );
    final categories = PartnerBusinessFilter.categoryOptions(all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('partner_search'),
          onChanged: (v) => onChanged(filter.copyWith(query: v)),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: AppStrings.partnersSearchHint,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
              borderSide: const BorderSide(
                color: AppColors.borderHairline,
                width: 0.8,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterDropdown(
                keyName: 'partner_filter_city',
                label: AppStrings.partnersFilterCity,
                value: filter.city,
                options: cities,
                onChanged: (v) => onChanged(
                  filter.copyWith(
                    city: () => v,
                    // Şehir değişti → ilçe o şehirde geçerli değilse sıfırla.
                    district: () {
                      if (filter.district == null) return null;
                      final valid = PartnerBusinessFilter.districtOptions(
                        all,
                        city: v,
                      );
                      return valid.contains(filter.district)
                          ? filter.district
                          : null;
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              _FilterDropdown(
                keyName: 'partner_filter_district',
                label: AppStrings.partnersFilterDistrict,
                value: filter.district,
                options: districts,
                onChanged: (v) => onChanged(filter.copyWith(district: () => v)),
              ),
              const SizedBox(width: AppSpacing.s),
              _FilterDropdown(
                keyName: 'partner_filter_category',
                label: AppStrings.partnersFilterCategory,
                value: filter.category,
                options: categories,
                onChanged: (v) => onChanged(filter.copyWith(category: () => v)),
              ),
              if (!filter.isEmpty) ...[
                const SizedBox(width: AppSpacing.s),
                TextButton.icon(
                  key: const ValueKey('partner_filter_clear'),
                  onPressed: () => onChanged(const PartnerBusinessFilter()),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: const Text(
                    AppStrings.partnersFilterClear,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.keyName,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String keyName;
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value != null;
    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.brandLemonPale : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          key: ValueKey(keyName),
          value: value,
          isDense: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          borderRadius: BorderRadius.circular(AppRadius.m),
          icon: const Icon(Icons.expand_more_rounded, size: 16),
          hint: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('$label: ${AppStrings.partnersFilterAll}'),
            ),
            for (final o in options)
              DropdownMenuItem<String?>(value: o, child: Text(o)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
