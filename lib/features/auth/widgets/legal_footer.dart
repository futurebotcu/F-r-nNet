import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';

/// V1.3.5 — Auth ekranlarında (AuthEntry, Login) kullanılan ortak yasal
/// footer. Kullanım Şartları + Gizlilik Politikası link'leri.
class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            height: 1.5,
          ),
          children: [
            const TextSpan(text: 'Devam ederek '),
            TextSpan(
              text: AppStrings.legalTermsTitle,
              style: const TextStyle(
                color: AppColors.softGold,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
              recognizer: _tap(context, AppRoutes.legalTerms),
            ),
            const TextSpan(text: ' ve '),
            TextSpan(
              text: AppStrings.legalPrivacyTitle,
              style: const TextStyle(
                color: AppColors.softGold,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
              recognizer: _tap(context, AppRoutes.legalPrivacy),
            ),
            const TextSpan(text: '\'nı kabul etmiş olursun.'),
          ],
        ),
      ),
    );
  }

  TapGestureRecognizer _tap(BuildContext ctx, String route) {
    return TapGestureRecognizer()..onTap = () => ctx.push(route);
  }
}
