import '../models/academy_bot_profile.dart';

/// FırınNet Akademi bot profillerine okuma erişimi.
///
/// Kaynak: `academy_bot_profiles` (A1) — public SELECT yalnız görünür+aktif
/// botları döndürür (RLS). profiles owner-only olduğu için bot tespiti bu
/// tablodan yapılır (profiles join / RPC değişikliği GEREKMEZ).
abstract class AcademyRepository {
  /// Görünür + aktif bot profillerinin id (= profiles.id = feed owner_id) seti.
  Future<Set<String>> visibleBotIds();

  /// [userId] görünür bir Akademi botu ise metadata; değilse null.
  Future<AcademyBotProfile?> botProfile(String userId);
}

/// Supabase-off / test default — hiç bot yok.
class EmptyAcademyRepository implements AcademyRepository {
  const EmptyAcademyRepository();

  @override
  Future<Set<String>> visibleBotIds() async => const <String>{};

  @override
  Future<AcademyBotProfile?> botProfile(String userId) async => null;
}
