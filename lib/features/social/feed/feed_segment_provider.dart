import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Social UI Polish Sprint 2A — feed üst segment'i (Genel Akış /
/// Takip Edilenler).
///
/// `0` = Genel Akış (default), `1` = Takip Edilenler.
///
/// app restart sonrası 0'a düşer (mantıklı default; "her seferinde genel
/// akıştan başla" davranışı). Takip Edilenler tab'ı kalıcı tercih
/// gerektiriyorsa V2'de SharedPreferences ile genişletilebilir.
final feedSegmentProvider = StateProvider<int>((_) => 0);
