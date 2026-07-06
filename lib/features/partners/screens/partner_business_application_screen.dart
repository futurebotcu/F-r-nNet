import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../widgets/partner_application_form.dart';

/// "Anlaşmalı iş yeri olmak istiyorum" başvuru ekranı (destek girişi).
class PartnerBusinessApplicationScreen extends StatelessWidget {
  const PartnerBusinessApplicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.partnersApplyTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            const Text(
              AppStrings.partnersApplyEntrySub,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            PartnerApplicationForm(
              onSubmitted: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
