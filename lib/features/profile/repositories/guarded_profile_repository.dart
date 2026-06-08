import '../../auth/services/auth_required_guard.dart';
import '../models/bakery_profile.dart';
import 'profile_repository.dart';

/// V1.3.3 — guest write korumalı [ProfileRepository] dekoratörü.
class GuardedProfileRepository implements ProfileRepository {
  GuardedProfileRepository({required this.inner, required this.canWriteCheck});

  final ProfileRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  // ── Read ────────────────────────────────────────────

  @override
  Future<BakeryProfile?> fetchProfile(String userId) =>
      inner.fetchProfile(userId);

  // ── Write (guarded) ────────────────────────────────

  @override
  Future<BakeryProfile> updateProfile({
    required String userId,
    required BakeryProfile profile,
  }) {
    _requireWrite('profili güncellemek');
    return inner.updateProfile(userId: userId, profile: profile);
  }
}
