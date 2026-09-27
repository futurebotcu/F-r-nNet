/// FırınNet Akademi bot metadata (`academy_bot_profiles`).
///
/// Path B (sistem-profil): botun görünen adı/avatarı `profiles` tarafındadır
/// (tekrar edilmez). Bu model yalnız akademi metadata'sını taşır. UI (A2/A5)
/// bunu `profiles` ile birleştirerek gösterecek. A1'de yalnız model + parse.
class AcademyBotProfile {
  const AcademyBotProfile({
    required this.profileId,
    required this.botKey,
    required this.topic,
    this.bio = '',
    this.isActive = true,
    this.isVisible = true,
    this.postingEnabled = true,
    this.dailyPostLimit = 1,
    this.subtopics = const <String>[],
    this.isHumor = false,
    this.allowDm = false,
    this.displayOrder = 100,
  });

  /// `profiles.id` (aynı zamanda `feed_posts.owner_id` bot postları için).
  final String profileId;

  /// Kararlı benzersiz anahtar (ör. 'akademi', 'haber', 'makine').
  final String botKey;

  /// İçerik konusu.
  final AcademyTopic topic;
  final String bio;
  final bool isActive;
  final bool isVisible;
  final bool postingEnabled;
  final int dailyPostLimit;

  /// V1 içerik motoru alanları (eski backend'de yoklar → güvenli default).
  final List<String> subtopics;
  final bool isHumor;
  final bool allowDm;
  final int displayOrder;

  bool get unlimitedDaily => dailyPostLimit <= 0;

  factory AcademyBotProfile.fromRow(Map<String, dynamic> row) {
    return AcademyBotProfile(
      profileId: (row['profile_id'] as String?) ?? '',
      botKey: (row['bot_key'] as String?) ?? '',
      topic: AcademyTopicMeta.fromKey(row['topic'] as String?),
      bio: (row['bio'] as String?) ?? '',
      isActive: (row['is_active'] as bool?) ?? true,
      isVisible: (row['is_visible'] as bool?) ?? true,
      postingEnabled: (row['posting_enabled'] as bool?) ?? true,
      dailyPostLimit: (row['daily_post_limit'] as num?)?.toInt() ?? 1,
      subtopics: (row['subtopics'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
      isHumor: (row['is_humor'] as bool?) ?? false,
      allowDm: (row['allow_dm'] as bool?) ?? false,
      displayOrder: (row['display_order'] as num?)?.toInt() ?? 100,
    );
  }
}

/// FırınNet Akademi içerik konuları — DB `academy_topic_chk` ile birebir.
enum AcademyTopic {
  akademi,
  haber,
  makine,
  un,
  hammadde,
  usta,
  tarif,
  maliyet,
  trend,
  hijyen,
  fuarSektor,
  // V1 kanonik konular (içerik motoru taksonomisi).
  ekmekFermantasyon,
  unTahil,
  turkUrunleri,
  pastacilik,
  firinTeknoloji,
  hijyenKalite,
  isletme,
  sektorGundemi,
  bilimArge,
  ustalikDunya,
  mizah,
}

extension AcademyTopicMeta on AcademyTopic {
  /// DB persist anahtarı (`academy_bot_profiles.topic`).
  String get persistKey {
    switch (this) {
      case AcademyTopic.fuarSektor:
        return 'fuar_sektor';
      case AcademyTopic.akademi:
        return 'akademi';
      case AcademyTopic.haber:
        return 'haber';
      case AcademyTopic.makine:
        return 'makine';
      case AcademyTopic.un:
        return 'un';
      case AcademyTopic.hammadde:
        return 'hammadde';
      case AcademyTopic.usta:
        return 'usta';
      case AcademyTopic.tarif:
        return 'tarif';
      case AcademyTopic.maliyet:
        return 'maliyet';
      case AcademyTopic.trend:
        return 'trend';
      case AcademyTopic.hijyen:
        return 'hijyen';
      case AcademyTopic.ekmekFermantasyon:
        return 'ekmek_fermantasyon';
      case AcademyTopic.unTahil:
        return 'un_tahil';
      case AcademyTopic.turkUrunleri:
        return 'turk_urunleri';
      case AcademyTopic.pastacilik:
        return 'pastacilik';
      case AcademyTopic.firinTeknoloji:
        return 'firin_teknoloji';
      case AcademyTopic.hijyenKalite:
        return 'hijyen_kalite';
      case AcademyTopic.isletme:
        return 'isletme';
      case AcademyTopic.sektorGundemi:
        return 'sektor_gundemi';
      case AcademyTopic.bilimArge:
        return 'bilim_arge';
      case AcademyTopic.ustalikDunya:
        return 'ustalik_dunya';
      case AcademyTopic.mizah:
        return 'mizah';
    }
  }

  String get label {
    switch (this) {
      case AcademyTopic.akademi:
        return 'Akademi';
      case AcademyTopic.haber:
        return 'Haber';
      case AcademyTopic.makine:
        return 'Makine';
      case AcademyTopic.un:
        return 'Un';
      case AcademyTopic.hammadde:
        return 'Hammadde';
      case AcademyTopic.usta:
        return 'Usta';
      case AcademyTopic.tarif:
        return 'Tarif';
      case AcademyTopic.maliyet:
        return 'Maliyet';
      case AcademyTopic.trend:
        return 'Trend';
      case AcademyTopic.hijyen:
        return 'Hijyen';
      case AcademyTopic.fuarSektor:
        return 'Fuar & Sektör';
      case AcademyTopic.ekmekFermantasyon:
        return 'Ekmek ve Fermantasyon';
      case AcademyTopic.unTahil:
        return 'Un ve Tahıl';
      case AcademyTopic.turkUrunleri:
        return "Türkiye'nin Unlu Mamulleri";
      case AcademyTopic.pastacilik:
        return 'Pastacılık ve Yeni Ürünler';
      case AcademyTopic.firinTeknoloji:
        return 'Fırın ve Üretim Teknolojisi';
      case AcademyTopic.hijyenKalite:
        return 'Hijyen ve Kalite';
      case AcademyTopic.isletme:
        return 'Fırın İşletmeciliği';
      case AcademyTopic.sektorGundemi:
        return 'Sektör Gündemi';
      case AcademyTopic.bilimArge:
        return 'Bilim ve Ar-Ge';
      case AcademyTopic.ustalikDunya:
        return 'Ustalık ve Dünya Ekmekleri';
      case AcademyTopic.mizah:
        return 'Mizah';
    }
  }

  static AcademyTopic fromKey(String? key) {
    for (final t in AcademyTopic.values) {
      if (t.persistKey == key) return t;
    }
    return AcademyTopic.akademi;
  }
}
