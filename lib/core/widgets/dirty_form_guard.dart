import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import 'app_confirm_dialog.dart';

/// PR-UI-2 — Form ekranlarında kaydedilmemiş değişiklik koruması.
///
/// Kullanım:
///  * Form kökünü [DirtyFormGuard] ile sar (`isDirty: _dirty`). Bu, **sistem
///    geri tuşunu** ve **default AppBar geri** (Navigator.maybePop) butonunu
///    yakalar; dirty ise "Değişiklikleri sil?" onayı sorar.
///  * Custom geri butonları (context.pop / Navigator.pop) PopScope'u BYPASS
///    eder → onların onPressed'inde [maybePopWithDirtyGuard] çağır.
class DirtyFormGuard extends StatelessWidget {
  const DirtyFormGuard({
    super.key,
    required this.isDirty,
    required this.child,
  });

  /// Kaydedilmemiş değişiklik var mı?
  final bool isDirty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await showDiscardChangesDialog(context);
        if (shouldDiscard && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: child,
    );
  }
}

/// Custom geri butonları için yardımcı: dirty ise onay sor; değilse veya
/// onaylanırsa [onConfirmed] (genelde `context.pop()`) çağrılır.
Future<void> maybePopWithDirtyGuard(
  BuildContext context, {
  required bool isDirty,
  required VoidCallback onConfirmed,
}) async {
  if (!isDirty) {
    onConfirmed();
    return;
  }
  final shouldDiscard = await showDiscardChangesDialog(context);
  if (shouldDiscard && context.mounted) {
    onConfirmed();
  }
}

/// "Değişiklikler silinsin mi?" onay dialogu (ortak [showAppConfirmDialog]).
/// `true` → kullanıcı çıkışı onayladı.
Future<bool> showDiscardChangesDialog(BuildContext context) {
  return showAppConfirmDialog(
    context,
    title: AppStrings.polishDiscardTitle,
    message: AppStrings.polishDiscardBody,
    confirmLabel: AppStrings.polishDiscardCta,
    cancelLabel: AppStrings.polishCancel,
    destructive: true,
  );
}
