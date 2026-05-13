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
final currentAuthUserProvider = Provider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo?.currentUser;
});
