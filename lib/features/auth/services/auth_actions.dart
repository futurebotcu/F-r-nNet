import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_strings.dart';
import '../../messaging/services/chat_media_signed_url_cache.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/auth_providers.dart';
import '../providers/guest_mode_provider.dart';

/// V1.4 — Çıkış yap akışı.
///
/// Hem Profile ekranı hem Settings ekranı bu fonksiyonu çağırır:
/// Supabase signOut (best-effort) → guest flag temizle → profile state
/// temizle → /auth route.
///
/// Daha önce `profile_screen.dart` içinde inline yazılmıştı; davranış
/// birebir korundu, sadece çağrı yeri ortaklaştırıldı.
Future<void> performSignOut(BuildContext context, WidgetRef ref) async {
  final auth = ref.read(authRepositoryProvider);
  if (auth != null) {
    try {
      await auth.signOut();
    } catch (_) {
      // Ağ kopuksa bile local state'i temizle.
    }
  }
  // Perf/güvenlik: bayat signed URL'ler sonraki kullanıcıya taşınmasın.
  ChatMediaSignedUrlCache.instance.clear();
  await ref.read(guestModeProvider.notifier).setGuest(false);
  if (!context.mounted) return;
  ref.read(profileControllerProvider.notifier).clear();
  context.go(AppRoutes.authEntry);
}

/// V1.4 — Hesap silme akışı (KVKK / Play uyumu).
///
/// 2-aşamalı: önce "HESABIMI SİL" yazma keyword'lü onay dialog'u, sonra
/// loading dialog. Başarılıysa `delete-account` Edge Function çağrısı
/// üzerinden server-side cascade silme + signOut + /auth.
///
/// Daha önce `profile_screen.dart` içinde `_onDeleteAccountPressed`
/// olarak vardı; aynı kontrat ile bu shared service'e taşındı.
Future<void> performDeleteAccount(BuildContext context, WidgetRef ref) async {
  if (!AppConfig.supabaseEnabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.accountDeleteUnsupportedOffline)),
    );
    return;
  }
  final auth = ref.read(authRepositoryProvider);
  final user = ref.read(currentAuthUserProvider);
  if (auth == null || user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.accountDeleteRequireAuth)),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const DeleteAccountConfirmDialog(),
  );
  if (confirmed != true || !context.mounted) return;

  // Loading dialog (dismissable değil).
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const DeleteAccountLoading(),
  );

  try {
    await auth.deleteAccount();

    // V1.4 P1.3 — Net cleanup sıralaması:
    //   1) Loading dialog'u kapat (mounted gate'li; unmounted ise dialog
    //      zaten yok).
    //   2) Guest flag temizle (await edilir — SharedPreferences yazımı).
    //   3) Profile state temizle (sync; ref.read üzerinden Riverpod
    //      notifier'a erişir, widget unmount edilse bile çalışır).
    //   4) mounted guard.
    //   5) Success snackbar + auth entry route.
    // Önceki sürüm `clear()` çağrısını mounted check sonrasına koyduğu
    // için yavaş cihazda widget unmount olursa profile state orphan
    // kalabiliyordu. Şimdi cleanup her durumda tamamlanır.
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await ref.read(guestModeProvider.notifier).setGuest(false);
    ref.read(profileControllerProvider.notifier).clear();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.accountDeleteSuccessSnack)),
    );
    context.go(AppRoutes.authEntry);
  } catch (_) {
    // Hata yolu: loading dialog kapanır, ham exception sızmaz, kullanıcı
    // generic Türkçe mesajı görür. Local state'e dokunulmaz (silme
    // başarısız oldu, kullanıcının session'ı hâlâ geçerli olabilir).
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.accountDeleteErrorGeneric)),
    );
  }
}

/// 2-step keyword confirm dialog — "HESABIMI SİL" yazılana kadar
/// sil butonu disabled.
///
/// Public sınıf: Profile ve Settings ekranları aynı diyaloğu kullanır.
class DeleteAccountConfirmDialog extends StatefulWidget {
  const DeleteAccountConfirmDialog({super.key});

  @override
  State<DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends State<DeleteAccountConfirmDialog> {
  final _ctrl = TextEditingController();
  bool _enabled = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final ok =
        value.trim().toUpperCase() == AppStrings.accountDeleteConfirmKeyword;
    if (ok != _enabled) {
      setState(() => _enabled = ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.elevatedCard,
      title: const Text(AppStrings.accountDeleteConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.accountDeleteConfirmBody,
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            AppStrings.accountDeleteConfirmFieldLabel,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              hintText: AppStrings.accountDeleteConfirmFieldHint,
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.accountDeleteCancel),
        ),
        FilledButton(
          onPressed: _enabled ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.surface,
          ),
          child: const Text(AppStrings.accountDeleteConfirmButton),
        ),
      ],
    );
  }
}

/// Edge function isteği sırasında gösterilen non-dismissable loading.
class DeleteAccountLoading extends StatelessWidget {
  const DeleteAccountLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.elevatedCard,
      content: Row(
        children: const [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.m),
          Expanded(child: Text(AppStrings.accountDeleteLoading)),
        ],
      ),
    );
  }
}
