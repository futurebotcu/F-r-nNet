import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/auth_user.dart';
import '../providers/auth_providers.dart';
import '../providers/guest_mode_provider.dart';
import '../widgets/legal_footer.dart';
import '../widgets/social_auth_buttons.dart';

/// Boot landing — Google-only auth.
///
/// 1. "Google ile devam et" (SocialAuthButtons) — primary, secure sign-in.
/// 2. "Misafir olarak keşfet" — guest flag + `/feed`.
///
/// E-posta/şifre giriş-kayıt akışı UI'dan kaldırıldı (Google + misafir).
/// Backend Supabase kapalıyken Google pasifleşir, misafir aktif kalır.
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
                  const SizedBox(height: AppSpacing.s),
                  const Center(child: _BrandMark()),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    AppStrings.authEntryHeroTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    AppStrings.authEntryHeroSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  // Birincil: Google ile güvenli giriş. compact=true →
                  // tek buton altında sahipsiz "veya" ayracı gösterilmez.
                  const SocialAuthButtons(compact: true),
                  const SizedBox(height: AppSpacing.s),
                  // İkincil: misafir olarak keşfet.
                  SizedBox(
                    height: 54,
                    child: TextButton(
                      onPressed: () async {
                        await ref
                            .read(guestModeProvider.notifier)
                            .setGuest(true);
                        ref.read(profileControllerProvider.notifier).useGuest();
                        if (!context.mounted) return;
                        context.go(AppRoutes.feed);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text(
                        AppStrings.authEntryGuestExplore,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
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

/// FırınNet marka ikonu — premium yuvarlatılmış kart, pale-lemon halo.
/// Asset yüklenemezse (test/eksik) sade lemon flame ikona düşer.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Image.asset(
          'assets/branding/firinnet_app_icon.png',
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            color: AppColors.brandLemonPale,
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.brandLemonPressed,
              size: 46,
            ),
          ),
        ),
      ),
    );
  }
}
