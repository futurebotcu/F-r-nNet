import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// PR-PERM-1 — runtime izin yardımcıları.
///
/// Kamera izni YALNIZ fotoğraf/video **çekim** aksiyonundan önce istenir;
/// galeri seçim akışları bu helper'ı ÇAĞIRMAZ (gereksiz izin sorulmaz).
class AppPermissionService {
  const AppPermissionService._();

  static const String _cameraDeniedMessage =
      'Kamera izni verilmedi. Fotoğraf çekmek için Ayarlar\'dan kamera izni '
      'vermen gerekiyor.';

  /// Kamera çekim aksiyonu öncesi izin ister.
  /// - verilirse `true`,
  /// - reddedilirse temiz açıklama (kalıcı red → Ayarlar dialog'u; geçici red →
  ///   snackbar) + `false`.
  static Future<bool> requestCameraForCapture(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) return true;
    if (!context.mounted) return false;
    if (status.isPermanentlyDenied) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kamera izni gerekli'),
          content: const Text(_cameraDeniedMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
              child: const Text('Ayarları Aç'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_cameraDeniedMessage)),
      );
    }
    return false;
  }

  /// Bildirim izni (Android 13+ POST_NOTIFICATIONS) wrapper'ı.
  ///
  /// NOT: Uygulamanın ANA bildirim izni akışı login sonrası
  /// `PushNotificationService.registerForUser` içinde
  /// `FirebaseMessaging.requestPermission()` ile çalışır (bozulmadı). Bu metod
  /// o akışı tamamlayıcı / gelecekteki kullanımlar için durumu sorgular-ister;
  /// reddedilse bile push/in-app akışını crash ettirmez (yalnız bool döner).
  static Future<bool> requestNotificationsIfNeeded() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
