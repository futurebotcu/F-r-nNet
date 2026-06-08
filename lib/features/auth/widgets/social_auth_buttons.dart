import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../providers/auth_providers.dart';

/// V1.4 — Apple "Yakında" modu.
///
/// `true` iken Apple butonu (sadece iOS'ta) görünür ama tıklayınca OAuth
/// tetiklenmez; bilinçli roadmap snackbar mesajı gösterilir. Apple Developer
/// (Service ID, Key ID, .p8) + iOS Xcode capability + macOS smoke ortamı
/// hazır olduğunda `false` çevrilir.
const bool kAppleSignInComingSoon = true;

/// App Store Prep Sprint 1 — iOS'ta sosyal login gizleme.
///
/// `true` iken iOS'ta TÜM sosyal login (Google + Apple) gizlenir; yalnız
/// email/şifre + "Kayıtsız devam et" görünür kalır. Gerekçe (App Store
/// Review Guideline 4.8 + 2.1/4.2):
///   * Üçüncü-taraf social login (Google) sunup Apple Sign-In sunmamak 4.8
///     reddine yol açar.
///   * `kAppleSignInComingSoon` ile gösterilen işlevsiz "Yakında" Apple
///     butonu, incomplete-feature (2.1/4.2) reddi riski taşır.
/// Apple Developer Service ID + Sign in with Apple capability (Mac/Xcode)
/// hazır olup `kAppleSignInComingSoon=false` çevrildiğinde bu flag de `false`
/// yapılır ve iOS'ta Google + Apple yeniden gösterilir. Android etkilenmez.
const bool kHideSocialLoginOnIos = true;

/// V1.4 — Google + Apple ile devam et grubu.
///
/// AuthEntryScreen ve LoginScreen'in üst kısmında ortak kullanılır.
/// - Google: tüm platformlarda görünür. Aktif.
/// - Apple: yalnız iOS'ta görünür (Android'de gizlenir). `kAppleSignInComingSoon`
///   true iken broken feature yerine "Yakında" badge + snackbar.
/// - Supabase aktif değilse (mock/local mode) tüm butonlar disabled.
/// - Google tıklanır → `signInWithGoogle` → SDK browser açar. Auth state change
///   ekranı dinleyen widget tarafından yakalanır.
class SocialAuthButtons extends ConsumerStatefulWidget {
  const SocialAuthButtons({super.key, this.compact = false});

  /// `true` ise butonların altında "veya" ayraç metni gösterilmez.
  /// LoginScreen'de form direkt altta olduğundan ayraç gösterilir;
  /// AuthEntryScreen'de email butonları zaten görünür durumda olduğu için
  /// caller'a göre değiştirilebilir.
  final bool compact;

  @override
  ConsumerState<SocialAuthButtons> createState() => _SocialAuthButtonsState();
}

class _SocialAuthButtonsState extends ConsumerState<SocialAuthButtons> {
  bool _busy = false;

  bool _isIos(BuildContext context) {
    // Test override için Theme.of platform; production'da
    // defaultTargetPlatform iOS host'unda iOS döner.
    return Theme.of(context).platform == TargetPlatform.iOS;
  }

  Future<void> _runProvider(
    Future<void> Function() action, {
    required String fallbackError,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      PremiumTopBannerController.show(
        context,
        message: message.isEmpty ? fallbackError : message,
        tone: PremiumTopBannerTone.danger,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Apple "Yakında" davranışı — OAuth çağrılmaz, sadece bilgi snackbar'ı.
  void _showAppleComingSoon() {
    PremiumTopBannerController.show(
      context,
      message: AppStrings.authAppleComingSoonSnack,
      tone: PremiumTopBannerTone.info,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    // App Store Prep Sprint 1 — iOS'ta sosyal login tümüyle gizli (4.8 +
    // incomplete-feature riski). Email/şifre + guest mode caller ekranda
    // ayrıca render edilir; bu widget iOS'ta hiçbir şey çizmez.
    if (_isIos(context) && kHideSocialLoginOnIos) {
      return const SizedBox.shrink();
    }

    final repo = ref.watch(authRepositoryProvider);
    final enabled = repo != null && !_busy;
    final showApple = _isIos(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Google ile devam et — beyaz zemin + Google G ikon yer tutucu.
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            key: const ValueKey('social_btn_google'),
            onPressed: enabled
                ? () => _runProvider(
                    () => repo.signInWithGoogle(),
                    fallbackError: AppStrings.authOAuthFailed,
                  )
                : null,
            icon: const Icon(
              // SVG/asset eklenmediği için Material kapı simgesi —
              // marka netliği için Sprint sonrası asset ile değiştirilir.
              Icons.account_circle_rounded,
              color: AppColors.textPrimary,
            ),
            label: const Text(AppStrings.authContinueWithGoogle),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              disabledBackgroundColor: AppColors.surface.withValues(
                alpha: 0.70,
              ),
              disabledForegroundColor: AppColors.textSecondary,
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
                side: BorderSide(color: AppColors.borderHairline, width: 0.6),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.15,
              ),
            ),
          ),
        ),
        if (showApple) ...[
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              key: const ValueKey('social_btn_apple'),
              // V1.4 — "Yakında" modunda buton enabled (kullanıcı tıklayıp
              // bilgi alabilsin) ama OAuth çağrısı yapılmaz; sadece
              // `_showAppleComingSoon` snackbar gösterilir.
              onPressed: !enabled
                  ? null
                  : (kAppleSignInComingSoon
                        ? _showAppleComingSoon
                        : () => _runProvider(
                            () => repo.signInWithApple(),
                            fallbackError: AppStrings.authOAuthFailed,
                          )),
              icon: const Icon(
                Icons.apple_rounded,
                color: AppColors.textPrimary,
              ),
              label: const Text(AppStrings.authContinueWithApple),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                disabledBackgroundColor: AppColors.surface.withValues(
                  alpha: 0.70,
                ),
                disabledForegroundColor: AppColors.textSecondary,
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  side: BorderSide(color: AppColors.borderHairline, width: 0.6),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ),
          if (kAppleSignInComingSoon) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                AppStrings.authAppleComingSoonBadge,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ],
        if (!widget.compact) ...[
          const SizedBox(height: AppSpacing.l),
          Row(
            children: [
              const Expanded(
                child: Divider(color: AppColors.borderHairline, thickness: 0.6),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                child: Text(
                  AppStrings.authSocialDivider,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Expanded(
                child: Divider(color: AppColors.borderHairline, thickness: 0.6),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// kIsWeb / platform helpers korunur — testlerde `Theme.platform` override ile.
// ignore: unused_element
bool _isIosByDefault() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
