import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/branch_models.dart';
import 'branch_process_sheet.dart';

/// V2 — "Şablondan Süreç Oluştur" yatay şablon kartları.
///
/// [allowedTypes] çağıran yüzey belirler: patron/sorumlu tüm tipler, personel
/// yalnız izinli tipleri (UX filtresi — asıl izin denetimi RPC'de; izinsiz tip
/// burada HİÇ render edilmez). Karta dokununca süreç sheet'i tip + başlık ön
/// dolu açılır; kullanıcı düzenleyebilir.
class BranchTemplateRow extends ConsumerWidget {
  const BranchTemplateRow({
    super.key,
    required this.branchId,
    required this.allowedTypes,
  });

  final String branchId;
  final List<BranchProcessType> allowedTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (allowedTypes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: AppSpacing.s),
          child: Text(
            AppStrings.branchTemplatesSection,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: allowedTypes.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
            itemBuilder: (context, i) => _TemplateCard(
              type: allowedTypes[i],
              onCreate: () => showBranchProcessSheet(
                context,
                ref,
                branchId: branchId,
                allowedTypes: allowedTypes,
                initialType: allowedTypes[i],
                initialTitle: allowedTypes[i].label,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.type, required this.onCreate});

  final BranchProcessType type;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: InkWell(
          key: ValueKey('branch_template_${type.persistKey}'),
          borderRadius: BorderRadius.circular(AppRadius.m),
          onTap: onCreate,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppColors.borderHairline, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(type.icon, size: 17, color: AppColors.brandInk),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        type.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    type.templateDescription,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 14,
                      color: AppColors.brandInk,
                    ),
                    SizedBox(width: 4),
                    Text(
                      AppStrings.branchTemplateCreate,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandInk,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
