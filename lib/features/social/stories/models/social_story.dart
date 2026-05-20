// FırınNet Social V2 Commit 2 — Story model.
// Donor `Story` benzeri ama FırınNet alanları: owner_id, is_deleted,
// expires_at, content_type ('image'/'video'), content_url, duration_ms.

class SocialStory {
  const SocialStory({
    required this.id,
    required this.ownerId,
    required this.contentType,
    required this.contentUrl,
    required this.isDeleted,
    required this.createdAt,
    required this.expiresAt,
    this.durationMs,
  });

  final String id;
  final String ownerId;
  final String contentType; // 'image' veya 'video'
  final String contentUrl;
  final int? durationMs;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isImage => contentType == 'image';
  bool get isVideo => contentType == 'video';

  /// Defansif client-side filtresi: server-side RLS zaten expired'ları
  /// gizler ama tick race olursa burada da kontrol var.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Donor benzeri "is fresh" kontrolü (24 saatten az).
  bool get isFresh => !isDeleted && !isExpired;

  static SocialStory fromRow(Map<String, dynamic> row) {
    return SocialStory(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      contentType: row['content_type'] as String,
      contentUrl: row['content_url'] as String,
      durationMs: row['duration_ms'] as int?,
      isDeleted: (row['is_deleted'] as bool?) ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
  }
}
