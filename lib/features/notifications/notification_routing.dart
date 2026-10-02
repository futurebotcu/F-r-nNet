import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';

/// Bildirim (in-app + push) navigasyon yardımcıları.
///
/// Alt-nav shell kök route'ları zaten alt navigasyonda mounted'tır; `push` ile
/// ikinci kez açılınca aynı GlobalKey widget tree'ye tekrar girer ve
/// `navigator.dart` assertion'ı kırılır (kırmızı ekran). Bu yüzden:
///   * shell kökü route → `go` (zaten mounted),
///   * derin route (ör. /pazar/tekliflerim/:id) → `push` (back-stack korunur →
///     Android geri tuşu app'ten çıkmaz, önceki ekrana/shell'e döner).
///
/// UI-NAV-003: literal drift'i önlemek için route'lar `AppRoutes` sabitlerinden
/// türetilir (önceki `/mesajlar` yanlış literal'i `/messages` ile değiştirildi).
const Set<String> kShellTabRoots = <String>{
  AppRoutes.community,
  AppRoutes.pazar,
  AppRoutes.listings,
  AppRoutes.messages,
  AppRoutes.panel,
};

/// [route] (query string yok sayılır) bir alt-nav shell kökü mü?
bool isShellTabRoot(String route) =>
    kShellTabRoots.contains(route.split('?').first);

/// Bildirim route'una git: shell kökü `go`, derin route `push`.
///
/// UI-NAV-002: push notification tap'ı da bu mantığı kullanır (eskiden koşulsuz
/// `go` idi → derin route'ta back-stack sıfırlanıp Android geri = app çıkışı).
void navigateToNotificationRoute(GoRouter router, String route) {
  if (route.isEmpty) return;
  if (isShellTabRoot(route)) {
    router.go(route);
  } else {
    router.push(route);
  }
}

/// Cold-start push routing.
///
/// Terminated durumda bildirime dokunulunca `getInitialMessage()` route'u,
/// appRouter hazır olmadan ve Splash'in 700ms'lik açılış kararından ÖNCE
/// gelebilir; doğrudan navigasyon ya no-op olur ya da Splash'in `go(feed)`'i
/// hedefi ezer. Bu yüzden boot tamamlanana kadar route burada BEKLETİLİR;
/// Splash oturum kararından sonra [takeOnBoot] ile alır ve [goHomeThenPending]
/// ile gider. Boot sonrası gelen tap'ler (background → onMessageOpenedApp)
/// doğrudan işlenir.
class PendingNotificationRoute {
  PendingNotificationRoute._();

  static String? _pending;
  static bool _bootRouted = false;

  /// Bildirim tap'i. Boot bitmediyse ya da router yoksa bekletilir.
  static void handleTap(String? route, GoRouter? router) {
    if (route == null || route.isEmpty) return;
    if (router != null && (_bootRouted || _pastSplash(router))) {
      navigateToNotificationRoute(router, route);
      return;
    }
    _pending = route;
  }

  /// Splash'tan geçmeyen açılışlarda (ör. OAuth deep link) boot bayrağı hiç
  /// set edilmez; router splash dışında bir ekrandaysa tap doğrudan işlenir
  /// (aksi hâlde oturum boyunca tüm tap'ler kuyrukta kalırdı).
  static bool _pastSplash(GoRouter router) {
    final cfg = router.routerDelegate.currentConfiguration;
    if (cfg.isEmpty) return false;
    final path = cfg.uri.path;
    return path.isNotEmpty && path != AppRoutes.splash;
  }

  /// Splash: oturumlu ana akışa geçerken bekleyen route'u al (tek seferlik).
  static String? takeOnBoot() {
    _bootRouted = true;
    final route = _pending;
    _pending = null;
    return route;
  }

  /// Splash: oturumsuz/eksik profil yollarında bekleyen route düşürülür
  /// (giriş ekranının üstüne korumalı derin route açılmaz).
  static void discardOnBoot() {
    _bootRouted = true;
    _pending = null;
  }

  static String? get debugPending => _pending;

  static void debugReset() {
    _pending = null;
    _bootRouted = false;
  }
}

/// Splash'in oturumlu son adımı: önce ana akış ([home]), bekleyen bildirim
/// route'u varsa bir sonraki frame'de onun üstüne → geri tuşu ana akışa döner.
void goHomeThenPending(GoRouter router, String home) {
  final pending = PendingNotificationRoute.takeOnBoot();
  router.go(home);
  if (pending == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      navigateToNotificationRoute(router, pending);
    } catch (e) {
      debugPrint('[FirinNet][Push] pending route nav failed ($pending): $e');
    }
  });
}
