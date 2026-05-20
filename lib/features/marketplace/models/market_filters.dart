// FırınNet Market V1 — filter parametre nesnesi.
//
// Donor pattern: Bagisto `filter_bottom_sheet.dart` + `filter_chip_row.dart`.
// FırınNet'te listing_type V1'de iki sabit ('equipment_sale',
// 'bakery_transfer'); city/price/condition/equipment_category filtreleri
// classified marketplace UX için yeterli. V2'de category alt-filter +
// negotiable/rent range/transfer range eklenebilir.

class MarketFilters {
  const MarketFilters({
    this.listingType,
    this.equipmentCategory,
    this.city,
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
      (city == null || city!.isEmpty) &&
      (district == null || district!.isEmpty) &&
      minPrice == null &&
      maxPrice == null &&
      condition == null &&
      !negotiableOnly;

  /// Aktif filter chip sayısı — UI'da rozet için.
  int get activeCount {
    var n = 0;
    if (listingType != null) n++;
    if (equipmentCategory != null) n++;
    if (city != null && city!.isNotEmpty) n++;
    if (district != null && district!.isNotEmpty) n++;
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
    String? city,
    bool clearCity = false,
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
      city: clearCity ? null : (city ?? this.city),
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
          other.city == city &&
          other.district == district &&
          other.minPrice == minPrice &&
          other.maxPrice == maxPrice &&
          other.condition == condition &&
          other.negotiableOnly == negotiableOnly;

  @override
  int get hashCode => Object.hash(
        listingType,
        equipmentCategory,
        city,
        district,
        minPrice,
        maxPrice,
        condition,
        negotiableOnly,
      );
}
