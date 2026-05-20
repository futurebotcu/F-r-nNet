// FırınNet Market V1 — filter parametre nesnesi.
//
// Donor pattern: Bagisto `filter_bottom_sheet.dart` + `filter_chip_row.dart`.
// FırınNet'te listing_type V1'de iki sabit ('equipment_sale',
// 'bakery_transfer'); city/price/condition/equipment_category filtreleri
// classified marketplace UX için yeterli.
//
// V1 Market M2 controlled-data fix: city/district artık serbest text değil
// — picker'dan gelen cityCode/districtCode canonical kodlarla filtrelenir.
// city/district display label olarak yan yana taşınır.

class MarketFilters {
  const MarketFilters({
    this.listingType,
    this.equipmentCategory,
    this.countryCode,
    this.cityCode,
    this.city,
    this.districtCode,
    this.district,
    this.minPrice,
    this.maxPrice,
    this.condition,
    this.negotiableOnly = false,
  });

  /// 'equipment_sale' veya 'bakery_transfer'. null = tümü.
  final String? listingType;

  /// Ekipman alt kategorisi (örn. oven/mixer/refrigerator). null = tümü.
  /// Sadece listing_type='equipment_sale' için anlamlı.
  final String? equipmentCategory;

  /// V1 Market M2 — controlled data canonical kodları.
  final String? countryCode;
  final String? cityCode;
  final String? districtCode;

  /// Display label'lar (UI active chip rozetinde gösterilir; filter
  /// kullanımı code üzerinden).
  final String? city;
  final String? district;

  /// Birincil fiyat (equipment_sale için satış; bakery_transfer için
  /// transfer_price + rent_price ayrı sütunlardadır, V1'de bu range
  /// transfer_price ile eşleştirilir).
  final double? minPrice;
  final double? maxPrice;

  /// 'new' | 'used' | 'refurbished'.
  final String? condition;

  /// True ise sadece negotiable=true ilanları.
  final bool negotiableOnly;

  bool get isEmpty =>
      listingType == null &&
      equipmentCategory == null &&
      (cityCode == null || cityCode!.isEmpty) &&
      (districtCode == null || districtCode!.isEmpty) &&
      minPrice == null &&
      maxPrice == null &&
      condition == null &&
      !negotiableOnly;

  /// Aktif filter chip sayısı — UI'da rozet için.
  int get activeCount {
    var n = 0;
    if (listingType != null) n++;
    if (equipmentCategory != null) n++;
    if (cityCode != null && cityCode!.isNotEmpty) n++;
    if (districtCode != null && districtCode!.isNotEmpty) n++;
    if (minPrice != null || maxPrice != null) n++;
    if (condition != null) n++;
    if (negotiableOnly) n++;
    return n;
  }

  MarketFilters copyWith({
    String? listingType,
    bool clearListingType = false,
    String? equipmentCategory,
    bool clearEquipmentCategory = false,
    String? countryCode,
    bool clearCountryCode = false,
    String? cityCode,
    String? city,
    bool clearCity = false,
    String? districtCode,
    String? district,
    bool clearDistrict = false,
    double? minPrice,
    bool clearMinPrice = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    String? condition,
    bool clearCondition = false,
    bool? negotiableOnly,
  }) {
    return MarketFilters(
      listingType:
          clearListingType ? null : (listingType ?? this.listingType),
      equipmentCategory: clearEquipmentCategory
          ? null
          : (equipmentCategory ?? this.equipmentCategory),
      countryCode:
          clearCountryCode ? null : (countryCode ?? this.countryCode),
      cityCode: clearCity ? null : (cityCode ?? this.cityCode),
      city: clearCity ? null : (city ?? this.city),
      districtCode:
          clearDistrict ? null : (districtCode ?? this.districtCode),
      district: clearDistrict ? null : (district ?? this.district),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      condition: clearCondition ? null : (condition ?? this.condition),
      negotiableOnly: negotiableOnly ?? this.negotiableOnly,
    );
  }

  /// Provider family için stable cache key.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketFilters &&
          other.listingType == listingType &&
          other.equipmentCategory == equipmentCategory &&
          other.countryCode == countryCode &&
          other.cityCode == cityCode &&
          other.districtCode == districtCode &&
          other.minPrice == minPrice &&
          other.maxPrice == maxPrice &&
          other.condition == condition &&
          other.negotiableOnly == negotiableOnly;

  @override
  int get hashCode => Object.hash(
        listingType,
        equipmentCategory,
        countryCode,
        cityCode,
        districtCode,
        minPrice,
        maxPrice,
        condition,
        negotiableOnly,
      );
}
