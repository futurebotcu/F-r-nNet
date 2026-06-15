import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/services/auth_required_guard.dart';
import '../providers/follow_providers.dart';

/// V1 Social S2 — "Takip et / Takipten çık" toggle butonu.
///
/// Davranış:
///   * Kendi profilinde gösterilmez — caller (`PublicProfileScreen`)
///     `isSelf` durumunda widget'ı render etmez.
///   * Loading sırasında küçük spinner içerikte.
///   * Guest user → `runGuardedMutation` üzerinden AuthRequiredSheet açar.
///   * Hata → kullanıcı dostu snackbar; ham exception sızmaz.
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _busy = false;

  Future<void> _onPressed(bool currentlyFollowing) async {
    setState(() => _busy = true);
    await runGuardedMutation(
      context,
      ref,
      action: () async {
        final repo = ref.read(followRepositoryProvider);
        try {
          await repo.toggleFollow(widget.userId);
          HapticFeedback.lightImpact();
          // followChangesProvider tick'i isFollowingProvider'ı invalidate
          // eder; ek bir invalidate gereksiz ama defansif olarak çağırılır.
          ref.invalidate(isFollowingProvider(widget.userId));
          ref.invalidate(followCountsProvider(widget.userId));
        } on GuestActionRequiredException {
          rethrow;
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text(AppStrings.followError)));
        }
      },
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(isFollowingProvider(widget.userId));
    return SizedBox(
      // Profil aksiyon satırında _ProfileMessageCta (44) ile eşit yükseklik.
      height: 44,
      child: async.when(
        loading: () => const _FollowButtonShell(
          label: AppStrings.followCtaFollow,
          isFollowing: false,
          busy: true,
          onPressed: null,
        ),
        error: (_, __) => _FollowButtonShell(
          label: AppStrings.followCtaFollow,
          isFollowing: false,
          busy: false,
          onPressed: _busy ? null : () => _onPressed(false),
        ),
        data: (following) => _FollowButtonShell(
          label: following
              ? AppStrings.followCtaUnfollow
              : AppStrings.followCtaFollow,
          isFollowing: following,
          busy: _busy,
          onPressed: _busy ? null : () => _onPressed(following),
        ),
      ),
    );
  }
}

class _FollowButtonShell extends StatelessWidget {
  const _FollowButtonShell({
    required this.label,
    required this.isFollowing,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool isFollowing;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Following durumunda outlined; non-following durumunda filled (copper).
    if (isFollowing) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: busy
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              )
            : const Icon(Icons.person_remove_outlined, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderHairline, width: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation(AppColors.brandInk),
              ),
            )
          : const Icon(Icons.person_add_alt_1_rounded, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.copper,
        foregroundColor: AppColors.brandInk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}
