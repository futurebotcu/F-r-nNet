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
