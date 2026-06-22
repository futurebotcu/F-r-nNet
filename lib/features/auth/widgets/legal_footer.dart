import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';

/// V1.3.5 — Auth ekranlarında (AuthEntry, Login) kullanılan ortak yasal
/// footer. Kullanım Şartları + Gizlilik Politikası link'leri.
///
/// FN-AUDIT-010 — `TapGestureRecognizer` build içinde değil, State field'ı
/// olarak tutulur ve dispose edilir (her rebuild'de gesture arena sızıntısı
/// olmasın). Bu ekranlar uygulamanın ilk açtığı yüzeylerdir.
class LegalFooter extends StatefulWidget {
  const LegalFooter({super.key});

  @override
  State<LegalFooter> createState() => _LegalFooterState();
}

class _LegalFooterState extends State<LegalFooter> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => context.push(AppRoutes.legalTerms);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => context.push(AppRoutes.legalPrivacy);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

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
              recognizer: _termsTap,
            ),
            const TextSpan(text: ' ve '),
            TextSpan(
              text: AppStrings.legalPrivacyTitle,
              style: const TextStyle(
                color: AppColors.softGold,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
              recognizer: _privacyTap,
            ),
            const TextSpan(text: '\'nı kabul etmiş olursun.'),
          ],
        ),
      ),
    );
  }
}
