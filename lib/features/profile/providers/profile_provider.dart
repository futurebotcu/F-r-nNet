import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/models/auth_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/bakery_profile.dart';
import '../repositories/guarded_profile_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/supabase_profile_repository.dart';

/// V1.3.3 — Supabase varsa GuardedProfileRepository; yoksa null
/// (local-only / guest-only flow korunur).
final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  if (!AppConfig.supabaseEnabled) return null;
  final ProfileRepository inner = SupabaseProfileRepository(
    sb.Supabase.instance.client,
  );
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedProfileRepository(inner: inner, canWriteCheck: canWrite);
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

// ═══════════════════════════════════════════════════════════════════════
// V1 Social S1 — Public profile by id
// ═══════════════════════════════════════════════════════════════════════

/// V1 Social S1 — Bir kullanıcının public profil snapshot'ı.
///
/// `profiles` RLS owner-only olduğu için doğrudan SELECT yapılamaz.
/// `public_profile_snapshot(uuid[])` RPC SECURITY DEFINER + yalnız üç
/// güvenli kolonu (id, display_name, profession_badge, city) döner.
/// Bu model UI tarafında public profile sayfası için yeterli.
class PublicProfile {
  const PublicProfile({
    required this.id,
    this.displayName,
    this.professionBadge,
    this.city,
  });

  final String id;
  final String? displayName;
  final String? professionBadge;
  final String? city;

  /// UI fallback metni — `displayName` null/boş ise.
  static const String fallbackName = 'FırınNet Kullanıcısı';

  String get displayNameOrFallback =>
      (displayName == null || displayName!.trim().isEmpty)
      ? fallbackName
      : displayName!;
}

/// V1 Social S1 — Public profile by user id.
///
/// Supabase aktif değilse veya RPC boş dönerse `null` döner; UI fallback
/// state'i gösterir.
final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfile?, String>((ref, userId) async {
      if (!AppConfig.supabaseEnabled) return null;
      final client = sb.Supabase.instance.client;
      try {
        final rows = await client.rpc(
          'public_profile_snapshot',
          params: <String, dynamic>{
            'p_user_ids': <String>[userId],
          },
        );
        if (rows is! List || rows.isEmpty) return null;
        final row = (rows.first as Map).cast<String, dynamic>();
        return PublicProfile(
          id: row['id'] as String,
          displayName: row['display_name'] as String?,
          professionBadge: row['profession_badge'] as String?,
          city: row['city'] as String?,
        );
      } catch (_) {
        return null;
      }
    });
