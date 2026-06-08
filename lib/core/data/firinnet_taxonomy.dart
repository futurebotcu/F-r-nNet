// FırınNet Data Foundation M5 — ortak controlled vocabulary.
//
// Hedef: filtrelenebilir/raporlanabilir alanlar tek dosyada code+label
// olarak tutulur. UI label gösterir; DB code yazar.
//
// V1 M5 kapsamı sadece `professions`. Sonraki sprintler (location, skills,
// payment methods, vb.) bu dosyaya eklenir.
//
// Backward compatibility: eski Türkçe label DB değerleri korunur. UI önce
// code'u (yeni kolon) çözer; yoksa eski label text'i fallback olarak
// gösterir. `labelToCode(label)` migration backfill ve runtime fallback
// için aynı haritayı paylaşır.

import '../../features/profile/models/bakery_profile.dart';

class FirinnetTaxonomy {
  const FirinnetTaxonomy._();

  // ───────────────────────────────────────────────────────────────
  // Professions (code → Türkçe label)
  // ───────────────────────────────────────────────────────────────

  static const Map<String, String> professions = <String, String>{
    'usta_firinci': 'Usta Fırıncı',
    'firin_sahibi': 'Fırın Sahibi',
    'isletmeci': 'İşletmeci',
    'mayaci': 'Mayacı',
    'hamurcu': 'Hamurcu',
    'simitci': 'Simitçi',
    'pogacaci': 'Poğaçacı',
    'pasta_ustasi': 'Pasta Ustası',
    'pideci': 'Pideci',
    'cirak': 'Çırak',
    'kalfa': 'Kalfa',
    'uncu': 'Uncu',
    'susamci': 'Susamcı',
    'toptanci': 'Toptancı',
    'ekipman_satici': 'Ekipman Satıcısı',
    'sofor': 'Şoför',
    'other': 'Diğer',
  };

  /// Allowed code listesi — DB CHECK constraint ile birebir eş.
  static List<String> get professionCodes =>
      professions.keys.toList(growable: false);

  /// UI iteration için entry listesi (insertion order korunur).
  static Iterable<MapEntry<String, String>> get professionEntries =>
      professions.entries;

  /// Code → Türkçe label; bilinmeyen code için null.
  static String? professionLabel(String? code) {
    if (code == null || code.isEmpty) return null;
    return professions[code];
  }

  /// Türkçe label → code; bilinmeyen label için null.
  /// Migration backfill ve runtime fallback için aynı haritayı paylaşır;
  /// case-insensitive + trim toleranslı.
  static String? professionCodeFromLabel(String? label) {
    if (label == null) return null;
    final norm = label.trim();
    if (norm.isEmpty) return null;
    for (final e in professions.entries) {
      if (e.value.toLowerCase() == norm.toLowerCase()) {
        return e.key;
      }
    }
    return null;
  }

  /// `true` ise CHECK constraint geçer. null geçerlidir (nullable kolon).
  static bool isValidProfessionCode(String? code) {
    if (code == null || code.isEmpty) return true;
    return professions.containsKey(code);
  }

  // ───────────────────────────────────────────────────────────────
  // Account-type subset (signup/profile create için role-bazlı filtre)
  //
  // Eski `RoleBadges.commercial/individual/wholesaler` listelerinin
  // taxonomy karşılığı. UI başlangıç chip seçimini bu subset'le sınırlar,
  // ama save'de code daima professions map'inden gelir.
  // ───────────────────────────────────────────────────────────────

  static const List<String> _commercialProfessionCodes = <String>[
    'usta_firinci',
    'firin_sahibi',
    'isletmeci',
    'pasta_ustasi',
    'other',
  ];

  static const List<String> _individualProfessionCodes = <String>[
    'usta_firinci',
    'mayaci',
    'hamurcu',
    'simitci',
    'pogacaci',
    'pasta_ustasi',
    'pideci',
    'cirak',
    'kalfa',
    'other',
  ];

  static const List<String> _wholesalerProfessionCodes = <String>[
    'toptanci',
    'uncu',
    'susamci',
    'ekipman_satici',
    'sofor',
    'other',
  ];

  /// Hesap tipine göre allowed profession code'ları (signup chip filtresi).
  static List<String> professionCodesForAccountType(AccountType type) {
    switch (type) {
      case AccountType.commercial:
        return _commercialProfessionCodes;
      case AccountType.individual:
        return _individualProfessionCodes;
      case AccountType.wholesaler:
        return _wholesalerProfessionCodes;
    }
  }

  // ───────────────────────────────────────────────────────────────
  // Worker skills (M7) — multi-select chip taxonomy
  // ───────────────────────────────────────────────────────────────

  static const Map<String, String> workerSkills = <String, String>{
    'ekmek': 'Ekmek',
    'simit': 'Simit',
    'pogaca': 'Poğaça',
    'borek': 'Börek',
    'baklava': 'Baklava',
    'pasta': 'Pasta',
    'eksi_maya': 'Ekşi maya',
    'tas_firin': 'Taş fırın',
    'gece_uretimi': 'Gece üretimi',
    'hamur_yogurma': 'Hamur yoğurma',
    'mayalama': 'Mayalama',
    'pide': 'Pide',
    'kurabiye': 'Kurabiye',
    'other': 'Diğer',
  };

  /// Allowed skill code listesi (DB CHECK constraint ile uyumlu).
  static List<String> get workerSkillCodes =>
      workerSkills.keys.toList(growable: false);

  /// UI iteration için entry listesi (insertion order korunur).
  static Iterable<MapEntry<String, String>> get workerSkillEntries =>
      workerSkills.entries;

  /// Code → Türkçe label; bilinmeyen code için null.
  static String? workerSkillLabel(String? code) {
    if (code == null || code.isEmpty) return null;
    return workerSkills[code];
  }

  /// Türkçe label → code; case-insensitive + trim toleranslı. Migration
  /// backfill ve runtime fallback için aynı haritayı paylaşır.
  static String? workerSkillCodeFromLabel(String? label) {
    if (label == null) return null;
    final norm = label.trim();
    if (norm.isEmpty) return null;
    for (final e in workerSkills.entries) {
      if (e.value.toLowerCase() == norm.toLowerCase()) {
        return e.key;
      }
    }
    return null;
  }

  /// `true` ise CHECK / app-side guard geçer. null geçerlidir.
  static bool isValidWorkerSkillCode(String? code) {
    if (code == null || code.isEmpty) return true;
    return workerSkills.containsKey(code);
  }

  // ───────────────────────────────────────────────────────────────
  // Shifts (M8) — single-select chip taxonomy
  // worker_profiles.shift_preference + job_offer_posts.shift_code
  // ───────────────────────────────────────────────────────────────

  static const Map<String, String> shifts = <String, String>{
    'gunduz': 'Gündüz',
    'gece': 'Gece',
    'vardiyali': 'Vardiyalı',
    'esnek': 'Esnek',
  };

  static List<String> get shiftCodes => shifts.keys.toList(growable: false);
  static Iterable<MapEntry<String, String>> get shiftEntries => shifts.entries;

  static String? shiftLabel(String? code) {
    if (code == null || code.isEmpty) return null;
    return shifts[code];
  }

  static bool isValidShiftCode(String? code) {
    if (code == null || code.isEmpty) return true;
    return shifts.containsKey(code);
  }

  // ───────────────────────────────────────────────────────────────
  // Experience brackets (M8) — job_offer_posts.experience_code
  // ───────────────────────────────────────────────────────────────

  static const Map<String, String> experienceBrackets = <String, String>{
    'none': 'Şart değil',
    '0_2': '0-2 yıl',
    '3_5': '3-5 yıl',
    '5_plus': '5+ yıl',
  };

  static List<String> get experienceCodes =>
      experienceBrackets.keys.toList(growable: false);
  static Iterable<MapEntry<String, String>> get experienceEntries =>
      experienceBrackets.entries;

  static String? experienceLabel(String? code) {
    if (code == null || code.isEmpty) return null;
    return experienceBrackets[code];
  }

  static bool isValidExperienceCode(String? code) {
    if (code == null || code.isEmpty) return true;
    return experienceBrackets.containsKey(code);
  }
}
