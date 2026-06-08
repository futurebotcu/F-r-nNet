// Profile About Section — referans profildeki "Hakkımda" bölümü.
//
// Bio header'dan ayrıldı; istatistik/aksiyonlardan sonra, kategori tablarından
// önce sade bir bölüm olarak gösterilir. Şehir/meslek header'da kalır — burada
// TEKRARLANMAZ. Provider'sız, stateless → doğrudan widget-test edilebilir.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_strings.dart';

class ProfileAboutSection extends StatelessWidget {
  const ProfileAboutSection({
    super.key,
    required this.bio,
    required this.isSelf,
    this.onAddBio,
  });

  /// Kısa tanıtım (worker_profiles.bio). Boş/null olabilir.
  final String? bio;
  final bool isSelf;

  /// Self + boş bio → /profile/cv'ye giden hafif CTA.
  final VoidCallback? onAddBio;

  @override
  Widget build(BuildContext context) {
    final text = (bio ?? '').trim();
    final hasBio = text.isNotEmpty;

    // Başkası bakıyor + bio yok → Hakkımda bölümü hiç görünmesin.
    if (!hasBio && !isSelf) return const SizedBox.shrink();

    // Self'te "Hakkımda", başkasında "Hakkında".
    final title = isSelf
        ? AppStrings.profileAboutTitleSelf
        : AppStrings.profileSectionAbout;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.m,
        AppSpacing.pageH,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.sectionTitle),
          const SizedBox(height: 6),
          if (hasBio)
            Text(
              text,
              style: AppTypography.body.copyWith(height: 1.45),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            )
          else
            // Self + boş bio → hafif CTA (baskın buton değil).
            InkWell(
              onTap: onAddBio,
              borderRadius: BorderRadius.circular(AppRadius.s),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      size: 15,
                      color: AppColors.softGold,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        AppStrings.profileAboutAddCta,
                        style: const TextStyle(
                          color: AppColors.softGold,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
