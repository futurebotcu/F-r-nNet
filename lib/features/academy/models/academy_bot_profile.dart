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
    }
  }

  static AcademyTopic fromKey(String? key) {
    for (final t in AcademyTopic.values) {
      if (t.persistKey == key) return t;
    }
    return AcademyTopic.akademi;
  }
}
