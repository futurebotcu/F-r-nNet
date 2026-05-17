import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../auth/services/auth_actions.dart';
import '../widgets/settings_tile.dart';

/// V1.4 — Sade ve gerçek Settings ekranı.
///
/// 4 section: Hesap, Güvenlik ve Veri, Yasal, Uygulama. Sahte/çalışmayan
/// (bildirim, tema, dil, destek, yardım merkezi, Apple ayarı) tile EKLENMEZ.
/// Destek/help URL ve hesap silme web URL kararı yokken Phase 2'ye ertelendi.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            // ───── Hesap
            const SectionLabel(title: AppStrings.settingsSectionAccount),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
              ),
              child: PremiumCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.edit_outlined,
                      title: AppStrings.settingsEditProfile,
                      subtitle: AppStrings.settingsEditProfileSubtitle,
                      onTap: () => context.push(AppRoutes.createProfile),
                    ),
                    const _TileDivider(),
                    SettingsTile(
                      icon: Icons.logout_rounded,
                      title: AppStrings.settingsSignOut,
                      subtitle: AppStrings.settingsSignOutSubtitle,
                      onTap: () => performSignOut(context, ref),
                    ),
                  ],
                ),
              ),
            ),

            // ───── Güvenlik ve Veri
            const SectionLabel(title: AppStrings.settingsSectionSecurity),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
              ),
              child: PremiumCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.delete_forever_outlined,
                      title: AppStrings.settingsDeleteAccount,
                      subtitle: AppStrings.settingsDeleteAccountSubtitle,
                      onTap: () => performDeleteAccount(context, ref),
                      danger: true,
                    ),
                    const _TileDivider(),
                    SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: AppStrings.settingsDataInfo,
                      subtitle: AppStrings.settingsDataInfoSubtitle,
                      onTap: () => context.push(AppRoutes.settingsDataInfo),
                    ),
                  ],
                ),
              ),
            ),

            // ───── Yasal
            const SectionLabel(title: AppStrings.settingsSectionLegal),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
              ),
              child: PremiumCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: AppStrings.settingsPrivacy,
                      onTap: () => context.push(AppRoutes.legalPrivacy),
                    ),
                    const _TileDivider(),
                    SettingsTile(
                      icon: Icons.description_outlined,
                      title: AppStrings.settingsTerms,
                      onTap: () => context.push(AppRoutes.legalTerms),
                    ),
                  ],
                ),
              ),
            ),

            // ───── Uygulama
            const SectionLabel(title: AppStrings.settingsSectionApp),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
              ),
              child: PremiumCard(
                padding: EdgeInsets.zero,
                child: SettingsTile(
                  icon: Icons.local_fire_department_outlined,
                  title: AppStrings.settingsAbout,
                  subtitle: AppStrings.settingsAboutSubtitle,
                  onTap: () => context.push(AppRoutes.settingsAbout),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
          ],
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 0,
        indent: 70, // icon + gap
        endIndent: AppSpacing.l,
        color: AppColors.borderHairline,
      );
}
