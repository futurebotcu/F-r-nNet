import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_strings.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/auth_user.dart';
import '../providers/auth_providers.dart';
import '../providers/guest_mode_provider.dart';

/// V1.3.1 — Guest kullanıcı yazma aksiyonu yapmak istediğinde araya giren
/// merkezi auth gate. "Kayıtsız Devam Et"'i koruyarak kullanıcıyı doğal
/// onboarding'e yönlendirir.
///
/// Kullanım (ekran içinde):
/// ```dart
/// await AuthRequiredGuard.runOrPrompt(
///   context,
///   ref,
///   action: () async => repo.save(...),
/// );
/// ```
class AuthRequiredGuard {
  const AuthRequiredGuard._();

  /// Pure logic — test edilebilir.
  ///
  /// `true` döner (yazma izni) iken:
  /// - Supabase enabled + signed-in user
  /// - Supabase disabled + non-guest local profile (legacy local mode)
  ///
  /// `false` döner (engelle, sheet aç) iken:
  /// - guestMode = true (kullanıcı "Kayıtsız Devam Et" seçti)
  /// - Supabase enabled + currentUser = null
  /// - Supabase disabled + profile null veya guest
  static bool canWrite({
    required bool isGuest,
    required bool supabaseEnabled,
    required AuthUser? currentUser,
    required BakeryProfile? profile,
  }) {
    if (isGuest) return false;
    if (supabaseEnabled) return currentUser != null;
    // Supabase off — legacy local mode'da gerçek local profile yazabilir.
    if (profile == null) return false;
    if (identical(profile, BakeryProfile.guest)) return false;
    return true;
  }

  /// WidgetRef üzerinden hızlı kontrol — ekranların kullandığı sürüm.
  static bool canWriteWithRef(WidgetRef ref) {
    return canWrite(
      isGuest: ref.read(guestModeProvider),
      supabaseEnabled: AppConfig.supabaseEnabled,
      currentUser: ref.read(currentAuthUserProvider),
      profile: ref.read(profileControllerProvider),
    );
  }

  /// Yazma izni varsa [action]'ı çalıştır; yoksa bottom sheet aç.
  ///
  /// Döner:
  /// - `true` → action çalıştırıldı.
  /// - `false` → engellendi, kullanıcıya sheet gösterildi.
  static Future<bool> runOrPrompt(
    BuildContext context,
    WidgetRef ref, {
    required Future<void> Function() action,
  }) async {
    if (canWriteWithRef(ref)) {
      await action();
      return true;
    }
    if (context.mounted) {
      await showAuthRequiredSheet(context, ref);
    }
    return false;
  }
}

/// Repository katmanından fırlatılan kontrollü exception.
///
/// V1.3.3 mimarisi: yazma yetkisi olmayan kullanıcı (guest/unauthenticated)
/// `Guarded<X>Repository.write*` metodunu çağırdığında bu exception atılır.
/// UI tarafı [runGuardedMutation] helper'ı ile yakalayıp [AuthRequiredSheet]
/// açar.
///
/// Bu pattern UI-level pre-check'lere ek olarak (defense-in-depth) çalışır;
/// UI'da unutulan bir guard olsa bile repo katmanı write işlemini engeller.
class GuestActionRequiredException implements Exception {
  const GuestActionRequiredException({this.action});

  /// İsteğe bağlı bağlam — örn. 'gruba katılmak', 'reçete kaydetmek'.
  /// AuthRequired sheet metni şu an statik; bu alan ileride dinamikleştirme
  /// için kullanılabilir.
  final String? action;

  @override
  String toString() => action == null
      ? 'Guest action blocked.'
      : 'Guest action blocked: $action';
}

/// Repository wrapper'larının write metodlarının başında çağıracağı
/// guard fonksiyonu. Auth yetkisi yoksa [GuestActionRequiredException] atar.
///
/// Kullanım (örnek wrapper):
/// ```dart
/// class GuardedFooRepository implements FooRepository {
///   GuardedFooRepository({required this.inner, required this.canWriteCheck});
///   final FooRepository inner;
///   final bool Function() canWriteCheck;
///
///   void _requireWrite(String action) {
///     if (!canWriteCheck()) {
///       throw GuestActionRequiredException(action: action);
///     }
///   }
///
///   @override
///   Future<void> save(...) {
///     _requireWrite('foo kaydetmek');
///     return inner.save(...);
///   }
/// }
/// ```

/// UI-side mutation runner.
///
/// [action]'ı çalıştırır. Eğer içeride `GuestActionRequiredException`
/// fırlarsa [AuthRequiredSheet] açılır ve sessizce yutulur. Başarılıysa
/// `true`, engellenirse `false` döner.
///
/// Bu helper, UI'da `canWriteWithRef` pre-check'i unutulsa bile repo
/// katmanının attığı exception'ı yakalayıp kullanıcıyı doğru yere yönlendirir.
Future<bool> runGuardedMutation(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function() action,
}) async {
  try {
    await action();
    return true;
  } on GuestActionRequiredException {
    if (context.mounted) {
      await showAuthRequiredSheet(context, ref);
    }
    return false;
  }
}

/// AuthRequired bottom sheet — guest kullanıcıya hesap teklif eder.
Future<void> showAuthRequiredSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.elevatedCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetCtx) {
      return _AuthRequiredSheet(parentRef: ref);
    },
  );
}

class _AuthRequiredSheet extends StatelessWidget {
  const _AuthRequiredSheet({required this.parentRef});
  final WidgetRef parentRef;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppColors.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.copper, AppColors.copperMuted],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.surface,
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Text(
                    AppStrings.authRequiredTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      fontSize: 18,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              AppStrings.authRequiredBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => _goRoleSelect(context),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text(AppStrings.authRequiredCreate),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.copper,
                  foregroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _goLogin(context),
                icon: const Icon(Icons.login_rounded),
                label: const Text(AppStrings.authRequiredSignIn),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.softGold,
                  side: BorderSide(
                    color: AppColors.copper.withValues(alpha: 0.55),
                    width: 0.8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                ),
                child: const Text(
                  AppStrings.authRequiredKeepBrowsing,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goRoleSelect(BuildContext context) async {
    // Hesap oluştur seçilirse guest flag temizlenir.
    await parentRef.read(guestModeProvider.notifier).setGuest(false);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    context.push(AppRoutes.roleSelect);
  }

  Future<void> _goLogin(BuildContext context) async {
    await parentRef.read(guestModeProvider.notifier).setGuest(false);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    context.push(AppRoutes.login);
  }
}
