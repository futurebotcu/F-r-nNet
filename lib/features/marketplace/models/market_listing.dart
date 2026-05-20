// FırınNet Market V1 — `market_listings` modeli (genişletilmiş).
//
// Donor referansı: Bagisto opensource-ecommerce-mobile-app, product model
// pattern (title/price/description/attributes/condition). FırınNet'te
// classified marketplace + iki listing_type (`equipment_sale` /
// `bakery_transfer`) + soft-delete + status enum.

import 'market_listing_media.dart';

class MarketListing {
  const MarketListing({
    this.id,
    this.ownerId,
    required this.title,
    required this.category,
    this.listingType = 'equipment_sale',
    this.condition,
    this.description,
    this.city,
    this.district,
    this.price,
    this.unit,
    this.contactPreference = 'in_app',
    // V1 Market eski alan (V2 cleanup'ta drop). Yeni kod status kullanır.
    this.isActive = true,
    this.authorName,
    this.authorRole,
    this.createdAt,
    this.updatedAt,
    // V2 Market expansion (commit M1):
    this.status = 'active',
    this.isDeleted = false,
    this.equipmentCategory,
    this.currency = 'TRY',
    this.negotiable = false,
    this.brand,
    this.model,
    this.year,
    this.rentPrice,
    this.transferPrice,
    this.equipmentIncluded,
    this.hasLicense,
    this.areaM2,
    this.contactPhone,
    this.contactWhatsapp,
    this.viewCount = 0,
    this.mediaList = const <MarketListingMedia>[],
    this.isSavedByMe = false,
  });

  final String? id;
  final String? ownerId;
  final String title;

  /// V1 mevcut classified kategorisi (`'hammadde','ekipman','devren_firin',
  /// 'ikinci_el','ambalaj','hizmet','diger'`). listing_type ile birlikte
  /// kullanılır; V2 cleanup'ta detaylandırılır.
  final String category;

  /// V1 ana sınıflandırma: `'equipment_sale'` veya `'bakery_transfer'`.
  final String listingType;

  /// `'new' | 'used' | 'refurbished'`.
  final String? condition;
  final String? description;
  final String? city;
  final String? district;

  /// Birincil satış fiyatı. bakery_transfer için `transferPrice` + `rentPrice`
  /// ayrı; bu alan genelde equipment_sale için doludur.
  final double? price;
  final String? unit;

  /// `'in_app' | 'phone' | 'whatsapp'`.
  final String contactPreference;

  /// Eski alan — V2 cleanup'ta drop edilecek. Yeni kod `status` kullanır.
  final bool isActive;

  final String? authorName;
  final String? authorRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// V2 expansion: `'active' | 'sold' | 'paused'`.
  final String status;

  /// V2 expansion: soft-delete (RLS owner self görür).
  final bool isDeleted;

  /// equipment_sale için alt kategori (oven/mixer/refrigerator/...).
  final String? equipmentCategory;

  final String currency;
  final bool negotiable;
  final String? brand;
  final String? model;
  final int? year;

  /// bakery_transfer için aylık kira.
  final double? rentPrice;

  /// bakery_transfer için devir bedeli.
  final double? transferPrice;

  final bool? equipmentIncluded;
  final bool? hasLicense;
  final int? areaM2;
  final String? contactPhone;
  final String? contactWhatsapp;
  final int viewCount;

  /// Detail/card için yan-yüklenen media (repository tarafında doldurur).
  final List<MarketListingMedia> mediaList;

  /// Detail/card için saves cross-check sonucu (provider doldurur).
  final bool isSavedByMe;

  bool get isEquipmentSale => listingType == 'equipment_sale';
  bool get isBakeryTransfer => listingType == 'bakery_transfer';
  bool get hasMedia => mediaList.isNotEmpty;
  MarketListingMedia? get firstMedia =>
      mediaList.isEmpty ? null : mediaList.first;

  MarketListing copyWith({
    String? title,
    String? category,
    String? listingType,
    String? condition,
    String? description,
    String? city,
    String? district,
    double? price,
    String? unit,
    String? contactPreference,
    bool? isActive,
    String? status,
    bool? isDeleted,
    String? equipmentCategory,
    String? currency,
    bool? negotiable,
    String? brand,
    String? model,
    int? year,
    double? rentPrice,
    double? transferPrice,
    bool? equipmentIncluded,
    bool? hasLicense,
    int? areaM2,
    String? contactPhone,
    String? contactWhatsapp,
    int? viewCount,
    List<MarketListingMedia>? mediaList,
    bool? isSavedByMe,
  }) {
    return MarketListing(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      category: category ?? this.category,
      listingType: listingType ?? this.listingType,
      condition: condition ?? this.condition,
      description: description ?? this.description,
      city: city ?? this.city,
      district: district ?? this.district,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      contactPreference: contactPreference ?? this.contactPreference,
      isActive: isActive ?? this.isActive,
      authorName: authorName,
      authorRole: authorRole,
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      equipmentCategory: equipmentCategory ?? this.equipmentCategory,
      currency: currency ?? this.currency,
      negotiable: negotiable ?? this.negotiable,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      rentPrice: rentPrice ?? this.rentPrice,
      transferPrice: transferPrice ?? this.transferPrice,
      equipmentIncluded: equipmentIncluded ?? this.equipmentIncluded,
      hasLicense: hasLicense ?? this.hasLicense,
      areaM2: areaM2 ?? this.areaM2,
      contactPhone: contactPhone ?? this.contactPhone,
      contactWhatsapp: contactWhatsapp ?? this.contactWhatsapp,
      viewCount: viewCount ?? this.viewCount,
      mediaList: mediaList ?? this.mediaList,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
    );
  }

  /// Supabase INSERT için map. Sadece dolu alanlar gönderilir
  /// (default'lar DB tarafında uygulanır).
  Map<String, dynamic> toInsertRow(String ownerId) {
    final row = <String, dynamic>{
      'owner_id': ownerId,
      'title': title,
      'category': category,
      'listing_type': listingType,
      'contact_preference': contactPreference,
      'currency': currency,
      'negotiable': negotiable,
    };
    if (condition != null) row['condition'] = condition;
    if (description != null && description!.trim().isNotEmpty) {
      row['description'] = description;
    }
    if (city != null && city!.trim().isNotEmpty) row['city'] = city;
    if (district != null && district!.trim().isNotEmpty) {
      row['district'] = district;
    }
    if (price != null) row['price'] = price;
    if (unit != null && unit!.trim().isNotEmpty) row['unit'] = unit;
    if (equipmentCategory != null) {
      row['equipment_category'] = equipmentCategory;
    }
    if (brand != null) row['brand'] = brand;
    if (model != null) row['model'] = model;
    if (year != null) row['year'] = year;
    if (rentPrice != null) row['rent_price'] = rentPrice;
    if (transferPrice != null) row['transfer_price'] = transferPrice;
    if (equipmentIncluded != null) {
      row['equipment_included'] = equipmentIncluded;
    }
    if (hasLicense != null) row['has_license'] = hasLicense;
    if (areaM2 != null) row['area_m2'] = areaM2;
    if (contactPhone != null) row['contact_phone'] = contactPhone;
    if (contactWhatsapp != null) row['contact_whatsapp'] = contactWhatsapp;
    return row;
  }

  /// updatePost benzeri update map; status + is_deleted dahil owner mutation.
  Map<String, dynamic> toUpdateRow() {
    final row = toInsertRow(ownerId ?? '');
    row.remove('owner_id'); // immutable
    row['status'] = status;
    row['is_deleted'] = isDeleted;
    return row;
  }

  static MarketListing fromRow(
    Map<String, dynamic> row, {
    List<MarketListingMedia> mediaList = const <MarketListingMedia>[],
    bool isSavedByMe = false,
  }) {
    DateTime? parse(String? s) => s == null ? null : DateTime.tryParse(s);
    return MarketListing(
      id: row['id'] as String?,
      ownerId: row['owner_id'] as String?,
      title: (row['title'] as String?) ?? '',
      category: (row['category'] as String?) ?? 'diger',
      listingType: (row['listing_type'] as String?) ?? 'equipment_sale',
      condition: row['condition'] as String?,
      description: row['description'] as String?,
      city: row['city'] as String?,
      district: row['district'] as String?,
      price: (row['price'] as num?)?.toDouble(),
      unit: row['unit'] as String?,
      contactPreference:
          (row['contact_preference'] as String?) ?? 'in_app',
      isActive: (row['is_active'] as bool?) ?? true,
      authorName: row['author_name'] as String?,
      authorRole: row['author_role'] as String?,
      createdAt: parse(row['created_at'] as String?),
      updatedAt: parse(row['updated_at'] as String?),
      status: (row['status'] as String?) ?? 'active',
      isDeleted: (row['is_deleted'] as bool?) ?? false,
      equipmentCategory: row['equipment_category'] as String?,
      currency: (row['currency'] as String?) ?? 'TRY',
      negotiable: (row['negotiable'] as bool?) ?? false,
      brand: row['brand'] as String?,
      model: row['model'] as String?,
      year: (row['year'] as num?)?.toInt(),
      rentPrice: (row['rent_price'] as num?)?.toDouble(),
      transferPrice: (row['transfer_price'] as num?)?.toDouble(),
      equipmentIncluded: row['equipment_included'] as bool?,
      hasLicense: row['has_license'] as bool?,
      areaM2: (row['area_m2'] as num?)?.toInt(),
      contactPhone: row['contact_phone'] as String?,
      contactWhatsapp: row['contact_whatsapp'] as String?,
      viewCount: (row['view_count'] as num?)?.toInt() ?? 0,
      mediaList: mediaList,
      isSavedByMe: isSavedByMe,
    );
  }
}
