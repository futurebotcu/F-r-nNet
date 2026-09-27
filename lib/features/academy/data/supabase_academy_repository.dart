import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/academy_bot_profile.dart';
import 'academy_repository.dart';

/// `academy_bot_profiles` üzerinden okuma. RLS yalnız görünür+aktif satırları
/// döndürür → ekstra filtre gerekmez. Yazma yok (bot içeriği service_role).
class SupabaseAcademyRepository implements AcademyRepository {
  SupabaseAcademyRepository(this._client);

  final sb.SupabaseClient _client;

  static const String _cols = 'profile_id, bot_key, topic, bio, is_active, '
      'is_visible, posting_enabled, daily_post_limit, subtopics, is_humor, '
      'allow_dm, display_order';

  @override
  Future<List<AcademyBotProfile>> visibleBots() async {
    final rows = await _client
        .from('academy_bot_profiles')
        .select(_cols)
        .order('display_order', ascending: true);
    return [
      for (final r in (rows as List))
        AcademyBotProfile.fromRow((r as Map).cast<String, dynamic>()),
    ];
  }

  @override
  Future<AcademyBotProfile?> botProfile(String userId) async {
    final row = await _client
        .from('academy_bot_profiles')
        .select(_cols)
        .eq('profile_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return AcademyBotProfile.fromRow(row);
  }
}
