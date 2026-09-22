import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/academy_bot_profile.dart';
import 'academy_repository.dart';

/// `academy_bot_profiles` üzerinden okuma. RLS yalnız görünür+aktif satırları
/// döndürür → ekstra filtre gerekmez. Yazma yok (bot postu service_role).
class SupabaseAcademyRepository implements AcademyRepository {
  SupabaseAcademyRepository(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<Set<String>> visibleBotIds() async {
    final rows = await _client
        .from('academy_bot_profiles')
        .select('profile_id');
    return {for (final r in (rows as List)) (r as Map)['profile_id'] as String};
  }

  @override
  Future<AcademyBotProfile?> botProfile(String userId) async {
    final row = await _client
        .from('academy_bot_profiles')
        .select()
        .eq('profile_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return AcademyBotProfile.fromRow(row);
  }
}
