import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/academy_bot_profile.dart';
import '../models/academy_recipe.dart';
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

  @override
  Future<HumorPrefs> humorPrefs() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const HumorPrefs();
    final row = await _client
        .from('academy_engagement_prefs')
        .select('allow_humor_comments, allow_humor_dm')
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return const HumorPrefs();
    return HumorPrefs(
      allowComments: (row['allow_humor_comments'] as bool?) ?? true,
      allowDm: (row['allow_humor_dm'] as bool?) ?? false,
    );
  }

  @override
  Future<void> setHumorPrefs(HumorPrefs prefs) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('academy_engagement_prefs').upsert({
      'user_id': uid,
      'allow_humor_comments': prefs.allowComments,
      'allow_humor_dm': prefs.allowDm,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  @override
  Future<List<AcademyRecipe>> listPublishedRecipes() async {
    final rows = await _client
        .from('academy_recipes')
        .select('id, title, author_name, source_kind, source_url, '
            'ingredients, oven_c, minutes, steps, notes')
        .eq('status', 'published')
        .order('created_at', ascending: true);
    return [
      for (final r in (rows as List))
        AcademyRecipe.fromRow((r as Map).cast<String, dynamic>()),
    ];
  }
}
