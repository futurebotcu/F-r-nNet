import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/models/auth_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/bakery_profile.dart';
import '../repositories/profile_repository.dart';
import '../repositories/supabase_profile_repository.dart';

/// ProfileRepository — Supabase yoksa null (local-only / guest-only flow).
final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  if (!AppConfig.supabaseEnabled) return null;
  return SupabaseProfileRepository(sb.Supabase.instance.client);
});

/// `BakeryProfile?` durumunu yönetir.
///
/// - Supabase varsa: auth state değiştikçe `profiles` satırını çeker.
/// - Guest mode: [useGuest] ile yerel sahte profile geçer.
/// - [save] signed-in ise Supabase'e UPDATE'i gönderir, değilse yalnız
///   yerel state'i günceller (eski mock davranış korunur).
class ProfileController extends StateNotifier<BakeryProfile?> {
  ProfileController(this._ref) : super(null) {
    final repo = _ref.read(authRepositoryProvider);
    if (repo != null) {
      // İlk çekim
      final initial = repo.currentUser;
      if (initial != null) {
        _loadFor(initial.id);
      }
      _authSub = repo.authStateChanges().listen(_onAuthChanged);
    }
  }

  final Ref _ref;
  StreamSubscription<AuthUser?>? _authSub;

  void _onAuthChanged(AuthUser? user) {
    if (user == null) {
      state = null;
    } else {
      _loadFor(user.id);
    }
  }

  Future<void> _loadFor(String userId) async {
    final repo = _ref.read(profileRepositoryProvider);
    if (repo == null) return;
    try {
      final profile = await repo.fetchProfile(userId);
      state = profile;
    } catch (_) {
      // Geçici ağ hatası — UI dümeni boş profile düşürmesin, mevcut
      // state korunsun. Login akışı snackbar'da hatayı zaten gösteriyor.
    }
  }

  void useGuest() => state = BakeryProfile.guest;

  Future<void> save(BakeryProfile profile) async {
    final auth = _ref.read(authRepositoryProvider);
    final repo = _ref.read(profileRepositoryProvider);
    final user = auth?.currentUser;
    if (auth != null && repo != null && user != null) {
      final updated = await repo.updateProfile(
        userId: user.id,
        profile: profile,
      );
      state = updated;
    } else {
      state = profile;
    }
  }

  void clear() => state = null;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, BakeryProfile?>((ref) {
  return ProfileController(ref);
});
