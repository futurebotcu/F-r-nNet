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

  Future<void> _load() async {
    state = await _storage.read();
  }

  Future<void> setGuest(bool value) async {
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
