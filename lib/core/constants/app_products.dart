// FırınNet — Hazır ürün isimleri + meslek rozeti adapter'ı.
//
// M5 Data Foundation — `RoleBadges` artık `FirinnetTaxonomy.professions`
// üzerinden beslenir. UI label gösterir; save sırasında çağıran taraf
// `FirinnetTaxonomy.professionCodeFromLabel(label)` ile code'a çevirir.
// Eski Türkçe label-as-code arayüzü backward compat için korunur.

import '../data/firinnet_taxonomy.dart';
import '../../features/profile/models/bakery_profile.dart';

/// Hazır ürün isimleri — chip seçimi için.
///
/// Final Functional Sprint — rol/bağlam bazlı preset:
/// * Fırın (bireysel/ticari) satışı/üretimi: ekmek, simit, pide…
/// * Toptancı: fırın tedarik ürünleri (un, maya, yağ, ambalaj…).
/// Her iki listede de [ProductChoiceChips] sonuna otomatik "Diğer" eklenir;
/// kullanıcı preset dışı ürünü manuel yazabilir (ürün adı serbest text;
/// şema/CHECK kısıtı yok, mevcut manuel akış zaten bunu kanıtlıyor).
class AppProducts {
  const AppProducts._();

  /// Fırın ürünleri (bireysel/ticari satış + üretim/fire).
  static const List<String> defaults = <String>[
    'Ekmek',
    'Simit',
    'Pide',
    'Poğaça',
    'Açma',
    'Börek',
  ];

  /// Toptancı tedarik ürünleri (fırına satılan hammadde/sarf).
  static const List<String> supplier = <String>[
    'Un',
    'Ekmeklik un',
    'Pastalık un',
    'Yaş maya',
    'Kuru maya',
    'Tuz',
    'Şeker',
    'Sıvı yağ',
    'Margarin',
    'Susam',
    'Çörek otu',
    'Tahin',
    'Pekmez',
    'Ambalaj',
    'Poşet',
    'Kutu',
    'Katkı maddesi',
  ];

  /// Hesap tipine göre uygun preset listesi. Toptancı → tedarik ürünleri;
  /// diğer (ticari/bireysel/null) → fırın ürünleri. ("Diğer" chip'i
  /// [ProductChoiceChips] tarafından her durumda eklenir.)
  static List<String> forAccountType(AccountType? type) =>
      type == AccountType.wholesaler ? supplier : defaults;
}

/// Meslek rozeti seçenekleri.
///
/// M5: tek doğruluk kaynağı `FirinnetTaxonomy.professions`. Bu sınıf
/// arayüzü Türkçe label listesi olarak korur (backward compat) ama
/// listeler taxonomy'den derivasyonla üretilir.
class RoleBadges {
  const RoleBadges._();

  /// Tüm meslek label'ları (insertion order).
  static List<String> get all =>
      FirinnetTaxonomy.professions.values.toList(growable: false);

  /// Ticari rolü için meslek label'ları.
  static List<String> get commercial => _labelsFor(AccountType.commercial);

  /// Bireysel rolü için meslek label'ları.
  static List<String> get individual => _labelsFor(AccountType.individual);

  /// Toptancı rolü için meslek label'ları.
  static List<String> get wholesaler => _labelsFor(AccountType.wholesaler);

  static List<String> _labelsFor(AccountType type) {
    final codes = FirinnetTaxonomy.professionCodesForAccountType(type);
    return <String>[
      for (final c in codes) FirinnetTaxonomy.professions[c] ?? c,
    ];
  }
}
