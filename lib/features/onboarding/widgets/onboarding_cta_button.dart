// Onboarding birincil CTA — tasarım sistemindeki [AppPrimaryButton]'ı sarar.
//
// Etiket değiştiğinde (İleri → FırınNet'e Başla) yumuşak bir AnimatedSwitcher
// geçişi uygular. İçeride AppPrimaryButton kalır (lemon zemin + ink, press
// scale). Böylece tek tip buton dili korunur, sadece mikro-geçiş eklenir.

import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/app_primary_button.dart';

class OnboardingCtaButton extends StatelessWidget {
  const OnboardingCtaButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDuration.normal,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.18),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: AppPrimaryButton(
        // Etiket değişince AnimatedSwitcher yeni butonu geçişle getirir.
        key: ValueKey<String>(label),
        label: label,
        icon: icon,
        onPressed: onPressed,
      ),
    );
  }
}
