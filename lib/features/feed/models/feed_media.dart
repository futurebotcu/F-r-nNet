/// V1 Social S3 — Feed media (image V1; video V1.2).
///
/// Supabase şeması:
/// feed_media(
///   id uuid pk,
///   post_id uuid → feed_posts(id) on delete cascade,
///   owner_id uuid → profiles(id) on delete cascade,
///   media_type text check ('image','video') default 'image',
///   storage_path text not null,
///   width int, height int, size_bytes bigint,
///   is_deleted bool default false,
///   created_at timestamptz default now()
/// )
class FeedMedia {
  const FeedMedia({
    required this.id,
    required this.postId,
    required this.ownerId,
    required this.mediaType,
    required this.storagePath,
    required this.publicUrl,
    this.width,
    this.height,
    this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String ownerId;

  /// `'image' | 'video'`. V1'de yalnız `'image'` üretilir.
  final String mediaType;

  /// `feed-media` bucket'ı içinde göreceli yol. Format:
  /// `{owner_id}/{post_id}/{media_id}.{ext}`.
  final String storagePath;

  /// Supabase Storage `getPublicUrl(storagePath)` ile elde edilen URL.
  /// `cached_network_image` doğrudan bu URL'i kullanır.
  final String publicUrl;

  final int? width;
  final int? height;
  final int? sizeBytes;
  final DateTime createdAt;

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';

  factory FeedMedia.fromRow(
    Map<String, dynamic> row, {
    required String publicUrl,
  }) {
    return FeedMedia(
      id: row['id'] as String,
      postId: row['post_id'] as String,
      ownerId: row['owner_id'] as String,
      mediaType: (row['media_type'] as String?) ?? 'image',
      storagePath: row['storage_path'] as String,
      publicUrl: publicUrl,
      width: (row['width'] as num?)?.toInt(),
      height: (row['height'] as num?)?.toInt(),
      sizeBytes: (row['size_bytes'] as num?)?.toInt(),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
