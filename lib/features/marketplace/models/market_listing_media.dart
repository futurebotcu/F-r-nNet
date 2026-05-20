// FırınNet Market V1 — listing media row model.
//
// Donor pattern: Bagisto `product_image_carousel.dart` PageView+image url.
// FırınNet impl: Supabase `market_listing_media` row + `market-media`
// bucket public URL. Path konvansiyonu: {owner_id}/{listing_id}/{media_id}.{ext}.

class MarketListingMedia {
  const MarketListingMedia({
    required this.id,
    required this.listingId,
    required this.ownerId,
    required this.storagePath,
    required this.publicUrl,
    required this.sortOrder,
    required this.isDeleted,
    required this.createdAt,
  });

  final String id;
  final String listingId;
  final String ownerId;
  final String storagePath;
  final String publicUrl;
  final int sortOrder;
  final bool isDeleted;
  final DateTime createdAt;

  static MarketListingMedia fromRow(
    Map<String, dynamic> row, {
    required String publicUrl,
  }) {
    return MarketListingMedia(
      id: row['id'] as String,
      listingId: row['listing_id'] as String,
      ownerId: row['owner_id'] as String,
      storagePath: row['storage_path'] as String,
      publicUrl: publicUrl,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      isDeleted: (row['is_deleted'] as bool?) ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
