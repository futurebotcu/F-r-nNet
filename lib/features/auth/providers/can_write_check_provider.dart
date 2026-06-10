import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../profile/providers/profile_provider.dart';
import '../services/auth_required_guard.dart';
import 'auth_providers.dart';
import 'guest_mode_provider.dart';

/// V1.3.3 — Guarded repository wrapper'larının kullanacağı kapanış.
///
/// Wrapper write metodunda `canWriteCheck()` çağırır → guest/unauthenticated
/// durumda `false` döner → wrapper [GuestActionRequiredException] atar.
///
/// Her çağrıda **canlı** Supabase session'ı (persist edilmiş) okur.
///
/// P0 fix (media auth regression): Eskiden `currentAuthUserProvider`
/// (onAuthStateChange stream'ine bağlı, emitler arası cache'li) okunuyordu.
/// Native image picker app'i arka plana atıp resume'da geçici bir null-session
/// emit ettiğinde, bu cache stale `null` kalıp logged-in kullanıcıyı guest
/// gibi gösteriyordu. `authRepository.currentUser` getter'ı her çağrıda
/// `client.auth.currentUser` (persist session) okur → geçici stream
/// durumlarına dayanıklı.
final canWriteCheckProvider = Provider<bool Function()>((ref) {
  return () => AuthRequiredGuard.canWrite(
        isGuest: ref.read(guestModeProvider),
        supabaseEnabled: AppConfig.supabaseEnabled,
        currentUser: ref.read(authRepositoryProvider)?.currentUser,
        profile: ref.read(profileControllerProvider),
      );
});
