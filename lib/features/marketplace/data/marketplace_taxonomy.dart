// FırınNet Market V1 M2 — controlled vocabulary (sabit seçenekler).
//
// V1 Market M2 controlled-data fix: filtrelenebilir / raporlanabilir
// her alan tek bir taxonomy dosyasından beslenir; UI tarafında dropdown
// veya chip seçimi yapılır, serbest text yoktur. Form ve filter sheet
// aynı kaynağı tüketir, böylece veri kalitesi tek elden kontrol edilir.
//
// AppStrings da bu sabitlerden delegasyonla beslenir (geriye dönük uyum
// için AppStrings.marketListingTypeLabels vb. korunur; ama tek doğruluk
// kaynağı bu dosyadır).

class MarketplaceTaxonomy {
  const MarketplaceTaxonomy._();

  // ─── Listing types ───────────────────────────────────────────────
  // V1 narrowing — yalnız iki tip; "product/service/equipment" gibi
  // jenerik isimler yok. Migration CHECK ile DB seviyesinde zorlanır.
  static const String listingTypeEquipmentSale = 'equipment_sale';
  static const String listingTypeBakeryTransfer = 'bakery_transfer';

  static const Map<String, String> listingTypes = <String, String>{
    listingTypeEquipmentSale: 'Ekipman satışı',
    listingTypeBakeryTransfer: 'Fırın devri',
  };

  // ─── Equipment categories ────────────────────────────────────────
  // equipment_sale alt sınıflandırması.
  static const Map<String, String> equipmentCategories = <String, String>{
    'oven': 'Fırın',
    'mixer': 'Mikser / yoğurma',
    'dough_divider': 'Hamur bölücü',
    'proofing': 'Mayalama dolabı',
    'refrigerator': 'Dolap / soğutucu',
    'display_counter': 'Tezgâh / vitrin',
    'vehicle': 'Servis aracı',
    'other': 'Diğer',
  };

  // ─── Conditions ──────────────────────────────────────────────────
  static const Map<String, String> conditions = <String, String>{
    'new': 'Sıfır',
    'used': 'İkinci el',
    'refurbished': 'Yenilenmiş',
  };

  // ─── Contact preferences ─────────────────────────────────────────
  static const String contactPreferenceInApp = 'in_app';
  static const String contactPreferencePhone = 'phone';
  static const String contactPreferenceWhatsapp = 'whatsapp';

  static const Map<String, String> contactPreferences = <String, String>{
    contactPreferenceInApp: 'Uygulama içi',
    contactPreferencePhone: 'Telefon',
    contactPreferenceWhatsapp: 'WhatsApp',
  };

  // ─── Currencies ──────────────────────────────────────────────────
  static const String currencyTry = 'TRY';
  static const String currencyEur = 'EUR';
  static const String currencyUsd = 'USD';

  static const Map<String, String> currencies = <String, String>{
    currencyTry: '₺ TRY',
    currencyEur: '€ EUR',
    currencyUsd: '\$ USD',
  };

  static const String defaultCurrency = currencyTry;
  static const String defaultListingType = listingTypeEquipmentSale;
  static const String defaultContactPreference = contactPreferenceInApp;
  static const String defaultCountryCode = 'TR';

  // ─── Validators ──────────────────────────────────────────────────

  static bool isValidListingType(String? v) =>
      v != null && listingTypes.containsKey(v);

  static bool isValidEquipmentCategory(String? v) =>
      v == null || equipmentCategories.containsKey(v);

  static bool isValidCondition(String? v) =>
      v == null || conditions.containsKey(v);

  static bool isValidContactPreference(String? v) =>
      v != null && contactPreferences.containsKey(v);

  static bool isValidCurrency(String? v) =>
      v != null && currencies.containsKey(v);

  // ─── Display helpers ─────────────────────────────────────────────

  static String listingTypeLabel(String? code) =>
      listingTypes[code] ?? '';
  static String equipmentCategoryLabel(String? code) =>
      equipmentCategories[code] ?? '';
  static String conditionLabel(String? code) => conditions[code] ?? '';
  static String contactPreferenceLabel(String? code) =>
      contactPreferences[code] ?? '';
  static String currencyLabel(String? code) => currencies[code] ?? '';
}
