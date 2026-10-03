import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';

/// FırınNet işlem geri bildirimi tonu.
enum AppFeedbackKind { success, error, warning, info }

/// FırınNet ortak işlem geri bildirimi (snackbar).
///
/// Tek görsel dil: koyu mürekkep zemin + beyaz metin + küçük durum ikonu,
/// alttan yüzen, kısa süreli. Önceki mesajı kapatır (art arda işlemde yığılma
/// olmaz). Metin kullanıcı dilinde ve kısa olmalı — ham istisna ASLA verilmez.
///
/// ```dart
/// AppFeedback.success(context, 'İlan yayınlandı');
/// AppFeedback.error(context, 'Kaydedilemedi. Tekrar dene.');
/// ```
///
/// Tema (`snackBarTheme`) aynı zemini kullandığından doğrudan
/// `showSnackBar` çağıran eski yerler de aynı aileden görünür.
class AppFeedback {
  const AppFeedback._();

  static void success(BuildContext context, String message) =>
      show(context, message, kind: AppFeedbackKind.success);

  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message,
    kind: AppFeedbackKind.error,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void warning(BuildContext context, String message) =>
      show(context, message, kind: AppFeedbackKind.warning);

  static void info(BuildContext context, String message) =>
      show(context, message, kind: AppFeedbackKind.info);

  static void show(
    BuildContext context,
    String message, {
    AppFeedbackKind kind = AppFeedbackKind.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        build(
          message,
          kind: kind,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      );
  }

  /// Test/özel kullanım için snackbar nesnesi.
  static SnackBar build(
    String message, {
    AppFeedbackKind kind = AppFeedbackKind.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final (icon, color) = switch (kind) {
      AppFeedbackKind.success => (
        Icons.check_circle_rounded,
        const Color(0xFF4ADE80),
      ),
      AppFeedbackKind.error => (Icons.error_rounded, const Color(0xFFF87171)),
      AppFeedbackKind.warning => (
        Icons.warning_amber_rounded,
        AppColors.brandLemon,
      ),
      AppFeedbackKind.info => (Icons.info_rounded, const Color(0xFFCBD5E1)),
    };
    return SnackBar(
      key: ValueKey('app_feedback_${kind.name}'),
      duration: kind == AppFeedbackKind.error
          ? const Duration(seconds: 4)
          : const Duration(milliseconds: 2600),
      content: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.m),
          Expanded(child: Text(message)),
        ],
      ),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    );
  }
}
