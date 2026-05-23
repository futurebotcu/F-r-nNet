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

  BakeryProfile _fromRow(Map<String, dynamic> row) {
    return BakeryProfile(
      displayName: (row['display_name'] as String?) ?? '',
      accountType: _accountTypeFrom(row['account_type'] as String?),
      city: (row['city'] as String?) ?? '',
      roleBadge: (row['profession_badge'] as String?) ?? '',
      email: (row['email'] as String?) ?? '',
      avatarUrl: (row['avatar_url'] as String?),
    );
  }

  @override
  Future<BakeryProfile?> fetchProfile(String userId) async {
    final row = await _client
        .from(_table)
        .select(
            'id, display_name, account_type, profession_badge, city, avatar_url, email')
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
    final patch = <String, dynamic>{
      'display_name': profile.displayName,
      'account_type': profile.accountType.name,
      'profession_badge':
          profile.roleBadge.isEmpty ? null : profile.roleBadge,
      'city': profile.city.isEmpty ? null : profile.city,
      'avatar_url':
          (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
              ? null
              : profile.avatarUrl,
    };
    final updated = await _client
        .from(_table)
        .update(patch)
        .eq('id', userId)
        .select(
            'id, display_name, account_type, profession_badge, city, avatar_url, email')
        .single();
    return _fromRow(updated);
  }
}
