import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/bakery_profile.dart';
import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final sb.SupabaseClient _client;
  static const String _table = 'profiles';

  AccountType _accountTypeFrom(String? raw) {
    switch (raw) {
      case 'commercial':
        return AccountType.commercial;
      case 'wholesaler':
        return AccountType.wholesaler;
      case 'individual':
      default:
        return AccountType.individual;
    }
  }

  // Owner-only fetch — RLS `id = auth.uid()` zaten başka satırı görmez.
  // firinnet_id buraya dahil; UPDATE patch'ine ASLA dahil değil (client
  // değiştiremez, server-side trigger atadı).
  static const String _selectColumns =
      'id, display_name, account_type, profession_badge, '
      'profession_badge_code, city, city_code, avatar_url, email, '
      'firinnet_id';

  BakeryProfile _fromRow(Map<String, dynamic> row) {
    return BakeryProfile(
      displayName: (row['display_name'] as String?) ?? '',
      accountType: _accountTypeFrom(row['account_type'] as String?),
      city: (row['city'] as String?) ?? '',
      roleBadge: (row['profession_badge'] as String?) ?? '',
      email: (row['email'] as String?) ?? '',
      avatarUrl: (row['avatar_url'] as String?),
      roleBadgeCode: (row['profession_badge_code'] as String?),
      cityCode: (row['city_code'] as String?),
      firinnetId: (row['firinnet_id'] as String?),
    );
  }

  @override
  Future<BakeryProfile?> fetchProfile(String userId) async {
    final row = await _client
        .from(_table)
        .select(_selectColumns)
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return _fromRow(row);
  }

  @override
  Future<BakeryProfile> updateProfile({
    required String userId,
    required BakeryProfile profile,
  }) async {
    // Email kasıtlı olarak yazılmıyor — auth.updateUser + trigger üzerinden.
    // M5 — profession dual-write: code (yeni) + label (backward compat).
    final patch = <String, dynamic>{
      'display_name': profile.displayName,
      'account_type': profile.accountType.name,
      'profession_badge': profile.roleBadge.isEmpty ? null : profile.roleBadge,
      'profession_badge_code':
          (profile.roleBadgeCode == null || profile.roleBadgeCode!.isEmpty)
          ? null
          : profile.roleBadgeCode,
      'city': profile.city.isEmpty ? null : profile.city,
      'city_code': (profile.cityCode == null || profile.cityCode!.isEmpty)
          ? null
          : profile.cityCode,
      'avatar_url': (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
          ? null
          : profile.avatarUrl,
    };
    final updated = await _client
        .from(_table)
        .update(patch)
        .eq('id', userId)
        .select(_selectColumns)
        .single();
    return _fromRow(updated);
  }
}
