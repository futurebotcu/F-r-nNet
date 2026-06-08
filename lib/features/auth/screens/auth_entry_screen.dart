import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/auth_user.dart';
import '../providers/auth_providers.dart';
import '../providers/guest_mode_provider.dart';
import '../widgets/legal_footer.dart';
import '../widgets/social_auth_buttons.dart';

/// V1.3 boot landing - gives the user three clear choices.
///
/// 1. Giriş Yap -> `/auth/login`
/// 2. Hesabım yok, üye ol -> `/auth/role-select`
/// 3. Kayıtsız devam et -> guest flag set + `/feed`
///
/// When Supabase is off, (1) and (2) appear disabled with a warning banner;
/// "Kayıtsız devam et" remains active.
class AuthEntryScreen extends ConsumerStatefulWidget {
  const AuthEntryScreen({super.key});

  @override
  ConsumerState<AuthEntryScreen> createState() => _AuthEntryScreenState();
}

class _AuthEntryScreenState extends ConsumerState<AuthEntryScreen> {
  bool _backendBannerQueued = false;

  void _queueBackendBanner(bool supabaseOn) {
    if (supabaseOn || _backendBannerQueued) return;
    _backendBannerQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PremiumTopBannerController.show(
        context,
        message:
            'Sunucu bağlantısı kapalı. Yine de kayıtsız keşfe devam edebilirsin.',
        tone: PremiumTopBannerTone.warning,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final supabaseOn = ref.watch(authRepositoryProvider) != null;
    final theme = Theme.of(context);

    _queueBackendBanner(supabaseOn);

    ref.listen<AuthUser?>(currentAuthUserProvider, (prev, next) {
      if (prev == null && next != null && context.mounted) {
        context.go(AppRoutes.splash);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: AppDuration.normal,
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 10),
                    child: child,
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xs),
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
                    'FırınNet\'e hoş geldin',
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
                    'Fırıncılar, ustalar ve tedarikçiler için akış, grup, ilan ve bayi takibi.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  const SocialAuthButtons(),
                  const SizedBox(height: AppSpacing.s),
                  AppPrimaryButton(
                    label: 'Giriş Yap',
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
                      label: const Text('Hesap oluştur'),
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
                        'Kayıtsız devam et',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  const LegalFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
