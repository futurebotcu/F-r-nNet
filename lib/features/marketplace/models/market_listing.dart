/// FırınNet — `market_listings` (ürün/hizmet/ekipman ilanı) modeli.
///
/// Supabase tablosu: `market_listings` (V1, migration 20260516092830).
/// RLS: authenticated select active veya owner; owner CRUD.
class MarketListing {
  const MarketListing({
    this.id,
    this.ownerId,
    required this.title,
    required this.category,
    this.listingType = 'product',
    this.condition,
    this.description,
    this.city,
    this.district,
    this.price,
    this.unit,
    this.contactPreference = 'in_app',
    this.isActive = true,
    this.authorName,
    this.authorRole,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? ownerId;
  final String title;
  final String category;
  final String listingType;
  final String? condition;
  final String? description;
  final String? city;
  final String? district;
  final double? price;
  final String? unit;
  final String contactPreference;
  final bool isActive;
  final String? authorName;
  final String? authorRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    );
  }

  Map<String, dynamic> toInsertRow(String ownerId) {
    return <String, dynamic>{
      'owner_id': ownerId,
      'title': title,
      'category': category,
      'listing_type': listingType,
      if (condition != null && condition!.trim().isNotEmpty)
        'condition': condition,
      if (description != null && description!.trim().isNotEmpty)
        'description': description,
      if (city != null && city!.trim().isNotEmpty) 'city': city,
      if (district != null && district!.trim().isNotEmpty) 'district': district,
      if (price != null) 'price': price,
      if (unit != null && unit!.trim().isNotEmpty) 'unit': unit,
      'contact_preference': contactPreference,
      'is_active': isActive,
    };
  }

  factory MarketListing.fromRow(Map<String, dynamic> row) {
    DateTime? parse(String? s) => s == null ? null : DateTime.tryParse(s);
    return MarketListing(
      id: row['id'] as String?,
      ownerId: row['owner_id'] as String?,
      title: (row['title'] as String?) ?? '',
      category: (row['category'] as String?) ?? 'diger',
      listingType: (row['listing_type'] as String?) ?? 'product',
      condition: row['condition'] as String?,
      description: row['description'] as String?,
      city: row['city'] as String?,
      district: row['district'] as String?,
      price: (row['price'] as num?)?.toDouble(),
      unit: row['unit'] as String?,
      contactPreference: (row['contact_preference'] as String?) ?? 'in_app',
      isActive: (row['is_active'] as bool?) ?? true,
      authorName: row['author_name'] as String?,
      authorRole: row['author_role'] as String?,
      createdAt: parse(row['created_at'] as String?),
      updatedAt: parse(row['updated_at'] as String?),
    );
  }
}
