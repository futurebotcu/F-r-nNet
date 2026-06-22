// FırınNet — Uygulama-dışı push (FCM) servisi (PR-1: token kaydı).
//
// Bu sprint kapsamı: cihaz FCM token'ını alıp Supabase'e (register_push_token
// RPC) kaydetmek + refresh dinlemek + logout'ta pasifleştirmek. Gerçek push
// GÖNDERİMİ (edge function + FCM service account) PR-2'de.
//
// Tüm Firebase çağrıları guard'lı: config eksik/başarısızsa app CRASH ETMEZ,
// push sessizce devre dışı kalır (mevcut in-app notification merkezi bozulmaz).

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router/app_router.dart';
import '../notification_routing.dart';

/// Terminated/background mesaj handler'ı (FCM zorunlu kılar). PR-1'de no-op:
/// "notification" tipli FCM mesajları sistem tepsisinde otomatik gösterilir.
/// PR-2'de data-message + route handling burada genişler.
@pragma('vm:entry-point')
Future<void> firinnetFirebaseBackgroundHandler(RemoteMessage message) async {
  // no-op (PR-1)
}

class PushNotificationService {
  PushNotificationService._();

  static bool _firebaseReady = false;
  static StreamSubscription<String>? _refreshSub;

  static String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Uygulama açılışında bir kez: Firebase'i başlat (Android google-services
  /// native config). Başarısızsa push devre dışı (app etkilenmez).
  static Future<void> initFirebase() async {
    if (_firebaseReady) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firinnetFirebaseBackgroundHandler);
      _firebaseReady = true;
      _setupInteractionHandlers();
      debugPrint('[FirinNet][Push] Firebase initialized');
    } catch (e) {
      debugPrint('[FirinNet][Push] Firebase init skipped: $e');
    }
  }

  /// Bildirime tıklama → ilgili route'a git. Terminated (getInitialMessage) +
  /// background (onMessageOpenedApp). Foreground'da sistem bildirimi BASILMAZ
  /// (Android default) → mevcut in-app davranış korunur.
  static void _setupInteractionHandlers() {
    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg != null) _navigateFromMessage(msg);
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);
  }

  static void _navigateFromMessage(RemoteMessage message) {
    final route = message.data['route'];
    if (route == null || route.isEmpty) return;
    final router = appRouter;
    if (router == null) return;
    try {
      // UI-NAV-002: shell kökü `go`, derin route `push` → bildirimden açılan
      // derin ekrandan Android geri tuşu app'ten çıkmaz (önceki ekrana döner).
      navigateToNotificationRoute(router, route);
      debugPrint('[FirinNet][Push] tap → route=$route');
    } catch (e) {
      // Geçersiz route → güvenli fallback (no-op; app yine açılır).
      debugPrint('[FirinNet][Push] route nav failed ($route): $e');
    }
  }

  /// Login sonrası: bildirim izni iste + FCM token al + Supabase'e kaydet +
  /// token refresh dinle. Guard'lı; oturum yoksa RPC RLS/SECURITY DEFINER ile
  /// zaten reddedilir.
  static Future<void> registerForUser() async {
    if (!_firebaseReady) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      debugPrint(
        '[FirinNet][Push] permission=${settings.authorizationStatus}',
      );
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FirinNet][Push] token null/empty');
        return;
      }
      await _saveToken(token);
      await _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen(_saveToken);
    } catch (e) {
      debugPrint('[FirinNet][Push] register failed: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    try {
      await Supabase.instance.client.rpc(
        'register_push_token',
        params: <String, dynamic>{
          'p_token': token,
          'p_platform': _platform,
          'p_device_id': null,
        },
      );
      debugPrint('[FirinNet][Push] token registered (len=${token.length})');
    } catch (e) {
      debugPrint('[FirinNet][Push] token save failed: $e');
    }
  }

  /// Logout ÖNCESİ (oturum hâlâ geçerliyken) çağrılır: token'ı pasifleştir +
  /// refresh dinleyiciyi durdur. Böylece bu cihaza artık push gitmez.
  static Future<void> unregister() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (!_firebaseReady) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await Supabase.instance.client.rpc(
          'deactivate_push_token',
          params: <String, dynamic>{'p_token': token},
        );
        debugPrint('[FirinNet][Push] token deactivated');
      }
    } catch (e) {
      debugPrint('[FirinNet][Push] unregister failed: $e');
    }
  }
}
