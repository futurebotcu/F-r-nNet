import '../models/academy_bot_profile.dart';

/// Kullanıcının Mizah botu etkileşim tercihleri (kendi satırı, RLS own).
class HumorPrefs {
  const HumorPrefs({
    this.allowComments = true,
    this.allowDm = false,
  });

  /// Kendiliğinden mizah yorumlarına izin (varsayılan açık, kapatılabilir).
  final bool allowComments;

  /// Botun kendiliğinden DM başlatmasına izin (varsayılan KAPALI).
  final bool allowDm;
}

/// FırınNet Akademi bot profillerine OKUMA erişimi.
///
/// Kaynak: `academy_bot_profiles` — RLS public SELECT yalnız görünür+aktif
/// botları döndürür. Bot postu YAZMA client'ta yoktur (service_role motoru).
abstract class AcademyRepository {
  /// Görünür + aktif botlar (display_order sıralı).
  Future<List<AcademyBotProfile>> visibleBots();

  /// [userId] görünür bir bot ise metadata; değilse null.
  Future<AcademyBotProfile?> botProfile(String userId);

  /// Çağıran kullanıcının mizah etkileşim tercihleri (satır yoksa default).
  Future<HumorPrefs> humorPrefs();

  /// Tercihi kalıcı yazar (kendi satırı; sunucu guard'ları gönderim anında
  /// yeniden kontrol eder — geri çekme bekleyen etkileşimi de durdurur).
  Future<void> setHumorPrefs(HumorPrefs prefs);
}

/// Supabase-off / hata default'u — hiç bot yok (UI bot yüzeyi göstermez).
class EmptyAcademyRepository implements AcademyRepository {
  const EmptyAcademyRepository();

  @override
  Future<List<AcademyBotProfile>> visibleBots() async =>
      const <AcademyBotProfile>[];

  @override
  Future<AcademyBotProfile?> botProfile(String userId) async => null;

  @override
  Future<HumorPrefs> humorPrefs() async => const HumorPrefs();

  @override
  Future<void> setHumorPrefs(HumorPrefs prefs) async {}
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

  HumorPrefs prefs = const HumorPrefs();
  int prefsWrites = 0;

  @override
  Future<HumorPrefs> humorPrefs() async => prefs;

  @override
  Future<void> setHumorPrefs(HumorPrefs p) async {
    prefs = p;
    prefsWrites++;
  }
}
