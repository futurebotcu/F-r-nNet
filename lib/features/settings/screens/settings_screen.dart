import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../auth/services/auth_actions.dart';
import '../../profile/providers/profile_provider.dart';
import '../widgets/settings_tile.dart';

/// Sade ve gerçek Settings ekranı.
///
/// 4 section: Hesap, Güvenlik ve Veri, Yasal, Uygulama. Yasal bölümünde
/// Gizlilik / Kullanım Şartları / Topluluk Kuralları / Hesap & Veri Silme;
/// Uygulama bölümünde gerçek (mailto) Destek ve Yardım + Hakkında. Sahte/
/// çalışmayan tile (bildirim/tema/dil) eklenmez.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FırınNet ID — yalnız sahibine gösterilir; profile null veya
    // firinnetId boş ise tile gizlenir.
    final profile = ref.watch(profileControllerProvider);
    final firinnetId = profile?.firinnetId;
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: PremiumCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (firinnetId != null && firinnetId.isNotEmpty) ...[
                      SettingsTile(
                        icon: Icons.badge_outlined,
                        title: AppStrings.settingsFirinnetIdTitle,
                        subtitle: firinnetId,
                        trailing: const Icon(
                          Icons.copy_rounded,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: firinnetId),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  AppStrings.settingsFirinnetIdCopied,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const _TileDivider(),
                    ],
                    SettingsTile(
                      icon: Icons.edit_outlined,
                      title: AppStrings.settingsEditProfile,
                      subtitle: AppStrings.settingsEditProfileSubtitle,
                      onTap: () => context.push(AppRoutes.createProfile),
                    ),
                    const _TileDivider(),
                    // V1 P1-D — Bildirimler tile'ı.
                    SettingsTile(
                      icon: Icons.notifications_outlined,
                      title: AppStrings.notificationsTileTitle,
                      subtitle: AppStrings.notificationsTileSubtitle,
                      onTap: () => context.push(AppRoutes.notifications),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
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
                    const _TileDivider(),
                    // UGC Safety V1 — engellenenler listesi: içerikleri her
                    // yerde gizlendiği için engeli kaldırmanın tek garantili
                    // yüzeyi burası.
                    SettingsTile(
                      icon: Icons.block_rounded,
                      title: AppStrings.blockedUsersTitle,
                      subtitle: AppStrings.blockedUsersTileSubtitle,
                      onTap: () => context.push(AppRoutes.settingsBlocked),
                    ),
                  ],
                ),
              ),
            ),

            // ───── Yasal
            const SectionLabel(title: AppStrings.settingsSectionLegal),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: PremiumCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: AppStrings.settingsPrivacy,
                      onTap: () => _openExternalOrFallback(
                        context,
                        AppConfig.privacyPolicyUrl,
                        AppRoutes.legalPrivacy,
                      ),
                    ),
                    const _TileDivider(),
                    SettingsTile(
                      icon: Icons.description_outlined,
                      title: AppStrings.settingsTerms,
                      onTap: () => context.push(AppRoutes.legalTerms),
                    ),
                    const _TileDivider(),
                    SettingsTile(
                      icon: Icons.groups_2_outlined,
                      title: AppStrings.settingsCommunity,
                      subtitle: AppStrings.settingsCommunitySubtitle,
                      onTap: () => context.push(AppRoutes.legalCommunity),
                    ),
                    const _TileDivider(),
                    SettingsTile(
                      icon: Icons.auto_delete_outlined,
                      title: AppStrings.settingsAccountDeletion,
                      subtitle: AppStrings.settingsAccountDeletionSubtitle,
                      onTap: () => _openExternalOrFallback(
                        context,
                        AppConfig.accountDeletionUrl,
                        AppRoutes.legalAccountDeletion,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ───── Uygulama
            const SectionLabel(title: AppStrings.settingsSectionApp),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: PremiumCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.help_outline_rounded,
                      title: AppStrings.settingsSupport,
                      subtitle: AppStrings.settingsSupportSubtitle,
                      onTap: () => context.push(AppRoutes.settingsSupport),
                    ),
                    const _TileDivider(),
                    SettingsTile(
                      icon: Icons.local_fire_department_outlined,
                      title: AppStrings.settingsAbout,
                      subtitle: AppStrings.settingsAboutSubtitle,
                      onTap: () => context.push(AppRoutes.settingsAbout),
                    ),
                  ],
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

Future<void> _openExternalOrFallback(
  BuildContext context,
  String url,
  String fallbackRoute,
) async {
  try {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (ok) return;
  } catch (_) {
    // Fall through to the in-app legal screen.
  }
  if (context.mounted) context.push(fallbackRoute);
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
