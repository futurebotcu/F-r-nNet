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
  static List<String> get professionCodes => professions.keys.toList(
        growable: false,
      );

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
}
