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
/// Her çağrıda Riverpod state'inden taze değer okur; oturum değişikliklerinde
/// otomatik güncel kalır.
final canWriteCheckProvider = Provider<bool Function()>((ref) {
  return () => AuthRequiredGuard.canWrite(
        isGuest: ref.read(guestModeProvider),
        supabaseEnabled: AppConfig.supabaseEnabled,
        currentUser: ref.read(currentAuthUserProvider),
        profile: ref.read(profileControllerProvider),
      );
});
