import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/guest_mode_storage.dart';

/// Persistent guest mode flag — Riverpod katmanı.
///
/// Splash + AuthEntry karar verirken `read()` çağrısıyla başlangıç değerini
/// alır. Kullanıcı "Kayıtsız Devam Et" seçince [setGuest] (true) çağrılır;
/// logout/giriş başarısı [setGuest] (false) ile temizler.
class GuestModeNotifier extends StateNotifier<bool> {
  GuestModeNotifier() : super(false) {
    _load();
  }

  final GuestModeStorage _storage = GuestModeStorage.instance;

  /// P0 — setGuest çağrıldıysa _load'un geç tamamlanan storage snapshot'ı
  /// bilinçli kararı ezemez. Notifier'a İLK erişim setGuest ise (login
  /// başarısı, splash defensive guard, "Kayıtsız Devam Et") sıralama
  /// deterministik bozuluyordu: _load stale değeri setGuest'ten SONRA
  /// state'e yazıyor, oturum açık kullanıcı tüm session boyunca guest
  /// sayılıp text send dahil her yazımda AuthRequiredSheet görüyordu.
  bool _explicitlySet = false;

  Future<void> _load() async {
    final stored = await _storage.read();
    if (!_explicitlySet && mounted) state = stored;
  }

  Future<void> setGuest(bool value) async {
    _explicitlySet = true;
    state = value;
    await _storage.write(value);
  }
}

final guestModeProvider = StateNotifierProvider<GuestModeNotifier, bool>(
  (ref) => GuestModeNotifier(),
);

/// Splash'tan boot kararı verirken çağrılır — storage'ı senkron olmadığı için
/// [Future] döner; provider state'i restore olur olmaz tetiklenir.
final guestModeBootProvider = FutureProvider<bool>((ref) async {
  return GuestModeStorage.instance.read();
});
