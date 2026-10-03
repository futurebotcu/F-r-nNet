import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';

/// FırınNet ortak onay dialogu.
///
/// Her onay aynı mantığı izler: net başlık → kısa açıklama → "Vazgeç"
/// (solda, metin buton) → eylemi adlandıran CTA (sağda). Geri alınamaz
/// işlemlerde ([destructive]) CTA kırmızı zemin + beyaz metin. "Tamam /
/// Tamam" gibi belirsiz buton yok: [confirmLabel] eylemin kendisidir
/// ("Sil", "Engelle", "Çıkış yap").
///
/// Dönüş: yalnız CTA'ya basılırsa `true`; Vazgeç / dışarı dokunma / geri
/// tuşu → `false`.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Vazgeç',
  bool destructive = false,
  IconData? icon,
  bool barrierDismissible = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AppConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
    ),
  );
  return result ?? false;
}

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Vazgeç',
    this.destructive = false,
    this.icon,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AppColors.danger : AppColors.brandInk;
    return AlertDialog(
      key: const ValueKey('app_confirm_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      icon: icon == null
          ? null
          : Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
      title: Text(title),
      content: message == null
          ? null
          : SingleChildScrollView(child: Text(message!)),
      actions: [
        TextButton(
          key: const ValueKey('app_confirm_cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: Text(cancelLabel),
        ),
        FilledButton(
          key: const ValueKey('app_confirm_ok'),
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? AppButtonStyles.destructive
              : FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
