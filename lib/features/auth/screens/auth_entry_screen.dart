import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/auth_user.dart';
import '../providers/auth_providers.dart';
import '../providers/guest_mode_provider.dart';
import '../widgets/legal_footer.dart';
import '../widgets/social_auth_buttons.dart';

/// V1.3 boot landing — kullanıcıya net 3 seçenek.
///
/// 1. Giriş Yap → `/auth/login`
/// 2. Hesabım yok, üye ol → `/auth/role-select`
/// 3. Kayıtsız devam et → guest flag set + `/feed`
///
/// Supabase off modunda (1) ve (2) disabled görünür, uyarı banner'ı çıkar;
/// "Kayıtsız devam et" daima aktif.
class AuthEntryScreen extends ConsumerWidget {
  const AuthEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseOn = ref.watch(authRepositoryProvider) != null;
    final theme = Theme.of(context);

    // V1.4 — Social login geri callback'i ile session geldiğinde Splash'a
    // yönlendir. ref.listen build içinde güvenli (rebuild sırasında yalnız
    // bir subscription kalır).
    ref.listen<AuthUser?>(currentAuthUserProvider, (prev, next) {
      if (prev == null && next != null && context.mounted) {
        context.go(AppRoutes.splash);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.l),
                    border: Border.all(
                      color: AppColors.borderHairline,
                      width: 0.6,
                    ),
                    boxShadow: AppShadow.card,
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.primary,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppStrings.authEntryTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                AppStrings.authEntrySubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
              const Spacer(flex: 2),
              if (!supabaseOn) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFB45309),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.authEntryBackendOff,
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
              ],
              // V1.4 — Sosyal giriş: Google + (iOS) Apple. Supabase off ise
              // SocialAuthButtons içinde butonlar disabled görünür.
              const SocialAuthButtons(),
              const SizedBox(height: AppSpacing.s),
              AppPrimaryButton(
                label: AppStrings.authEntrySignIn,
                icon: Icons.login_rounded,
                onPressed: supabaseOn
                    ? () => context.push(AppRoutes.login)
                    : null,
              ),
              const SizedBox(height: AppSpacing.s),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: supabaseOn
                      ? () => context.push(AppRoutes.roleSelect)
                      : null,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text(AppStrings.authEntrySignUp),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              SizedBox(
                height: 56,
                child: TextButton(
                  onPressed: () async {
                    await ref.read(guestModeProvider.notifier).setGuest(true);
                    ref.read(profileControllerProvider.notifier).useGuest();
                    if (!context.mounted) return;
                    context.go(AppRoutes.feed);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text(
                    AppStrings.authEntryGuest,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              // V1.3.5 — Yasal footer.
              const LegalFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
