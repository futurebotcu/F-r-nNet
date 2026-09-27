import '../models/academy_bot_profile.dart';

/// FırınNet Akademi bot profillerine OKUMA erişimi.
///
/// Kaynak: `academy_bot_profiles` — RLS public SELECT yalnız görünür+aktif
/// botları döndürür. Bot postu YAZMA client'ta yoktur (service_role motoru).
abstract class AcademyRepository {
  /// Görünür + aktif botlar (display_order sıralı).
  Future<List<AcademyBotProfile>> visibleBots();

  /// [userId] görünür bir bot ise metadata; değilse null.
  Future<AcademyBotProfile?> botProfile(String userId);
}

/// Supabase-off / hata default'u — hiç bot yok (UI bot yüzeyi göstermez).
class EmptyAcademyRepository implements AcademyRepository {
  const EmptyAcademyRepository();

  @override
  Future<List<AcademyBotProfile>> visibleBots() async =>
      const <AcademyBotProfile>[];

  @override
  Future<AcademyBotProfile?> botProfile(String userId) async => null;
}

/// Test/local repo — verilen bot listesiyle çalışır.
class LocalAcademyRepository implements AcademyRepository {
  LocalAcademyRepository({List<AcademyBotProfile>? bots})
      : bots = bots ?? const <AcademyBotProfile>[];

  final List<AcademyBotProfile> bots;

  @override
  Future<List<AcademyBotProfile>> visibleBots() async =>
      bots.where((b) => b.isVisible && b.isActive).toList(growable: false)
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  @override
  Future<AcademyBotProfile?> botProfile(String userId) async {
    for (final b in bots) {
      if (b.profileId == userId && b.isVisible && b.isActive) return b;
    }
    return null;
  }
}
