// Onboarding sayfa göstergesi — aktif nokta genişleyen pill, pasifler hairline.
// Yumuşak (easeOutCubic) genişleme animasyonu.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    super.key,
    required this.count,
    required this.index,
  });

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppDuration.normal,
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index
                  ? AppColors.brandLemonPressed
                  : AppColors.borderHairline,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}
