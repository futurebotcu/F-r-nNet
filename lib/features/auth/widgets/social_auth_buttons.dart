import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../providers/auth_providers.dart';

/// V1.4 — Google + Apple ile devam et grubu.
///
/// AuthEntryScreen ve LoginScreen'in üst kısmında ortak kullanılır.
/// - Google: tüm platformlarda görünür.
/// - Apple: yalnız iOS'ta görünür (Android'de gizlenir).
/// - Supabase aktif değilse (mock/local mode) tüm butonlar disabled.
/// - Buton tıklanır → ilgili `signInWithGoogle/Apple` çağrısı → SDK browser
///   açar. Auth state change ekranı dinleyen widget tarafından yakalanır.
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
                side: BorderSide(
                  color: AppColors.borderHairline,
                  width: 0.6,
                ),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
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
              onPressed: enabled
                  ? () => _runProvider(
                        () => repo.signInWithApple(),
                        fallbackError: AppStrings.authOAuthFailed,
                      )
                  : null,
              icon: const Icon(Icons.apple_rounded, color: Colors.white),
              label: const Text(AppStrings.authContinueWithApple),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    Colors.black.withValues(alpha: 0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        if (!widget.compact) ...[
          const SizedBox(height: AppSpacing.l),
          Row(
            children: [
              const Expanded(
                child: Divider(
                  color: AppColors.borderHairline,
                  thickness: 0.6,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                child: Text(
                  AppStrings.authSocialDivider,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Expanded(
                child: Divider(
                  color: AppColors.borderHairline,
                  thickness: 0.6,
                ),
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
