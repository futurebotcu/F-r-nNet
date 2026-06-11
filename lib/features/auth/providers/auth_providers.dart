import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../models/auth_user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/supabase_auth_repository.dart';

/// AuthRepository — Supabase yapılandırılmadıysa `null`. UI bu durumda
/// auth akışını gizler veya doğrudan local/guest moda düşer.
final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  if (!AppConfig.supabaseEnabled) return null;
  return SupabaseAuthRepository(sb.Supabase.instance.client);
});

/// Anlık auth user'ı stream eder. Supabase yoksa daima null.
final authUserStreamProvider = StreamProvider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  if (repo == null) return const Stream<AuthUser?>.empty();
  return repo.authStateChanges();
});

/// Senkron currentUser snapshot'ı — Stream beklemeden hızlı erişim.
///
/// V1.3.4 — Auth state'e **reactive**: [authUserStreamProvider] watch'lanır,
/// böylece signIn / signOut / token refresh sonrası bu provider invalidate
/// olur ve `repo.currentUser`'dan taze değeri döner.
///
/// **Bug'ı önler:** Eski sürümde `Provider<AuthUser?>` body'si bir kez
/// çalıştığında snapshot cache'leniyordu; signIn başarılı olsa bile Splash
/// `ref.read(currentAuthUserProvider)` çağrısı eski null değeri görüyor,
/// kullanıcı `/auth` ekranına atılıyordu. Bu fix tüm auth-bağımlı
/// provider'ları (`bakeryRepositoryProvider`, `dealerRepositoryProvider`,
/// `recipeRepositoryProvider`, `workerRepositoryProvider`,
/// `canWriteCheckProvider`) signIn sonrası taze auth state'e döndürür.
final currentAuthUserProvider = Provider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  if (repo == null) return null;
  // Auth stream'i watch et → emit (signIn/signOut/token refresh) sonrası
  // bu provider rebuild olur. Watch edilen değer kullanılmıyor; yalnız
  // dependency oluşturmak için gerekli.
  ref.watch(authUserStreamProvider);
  final user = repo.currentUser;
  // P0 teşhis — her emisyonda uid loglanır: transient null blip'leri ve
  // rebuild fırtınalarını görünür kılar (davranış değişikliği yok).
  if (kDebugMode) {
    debugPrint('[FirinNet][Auth] currentAuthUser rebuild uid=${user?.id}');
  }
  return user;
});
