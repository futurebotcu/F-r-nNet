import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

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

/// "Değişiklikleri sil?" onay dialogu. `true` → kullanıcı çıkışı onayladı.
Future<bool> showDiscardChangesDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Değişiklikleri sil?'),
      content: const Text(
        'Kaydedilmemiş değişiklikleriniz var. Çıkarsanız bu değişiklikler '
        'kaybolur.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Değişiklikleri sil'),
        ),
      ],
    ),
  );
  return result ?? false;
}
