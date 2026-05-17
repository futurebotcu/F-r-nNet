/// V1 P1-D — Uygulama içi bildirim modeli.
///
/// Supabase tablosu (`public.notifications`):
///   id, recipient_id, actor_id, type, title, body, entity_type, entity_id,
///   route, metadata jsonb, read_at, created_at
///
/// RLS: recipient_id = auth.uid() okuyabilir + read_at güncelleyebilir.
/// INSERT yalnız SECURITY DEFINER RPC üzerinden (request_group_join /
/// decide_group_join_request).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    this.actorId,
    required this.type,
    required this.title,
    required this.body,
    this.entityType,
    this.entityId,
    this.route,
    this.metadata = const <String, dynamic>{},
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String recipientId;
  final String? actorId;
  final String type;
  final String title;
  final String body;
  final String? entityType;
  final String? entityId;
  final String? route;
  final Map<String, dynamic> metadata;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;
  bool get isUnread => readAt == null;

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      recipientId: recipientId,
      actorId: actorId,
      type: type,
      title: title,
      body: body,
      entityType: entityType,
      entityId: entityId,
      route: route,
      metadata: metadata,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    final raw = row['metadata'];
    final meta = raw is Map<String, dynamic>
        ? raw
        : (raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{});
    return AppNotification(
      id: row['id'] as String,
      recipientId: row['recipient_id'] as String,
      actorId: row['actor_id'] as String?,
      type: (row['type'] as String?) ?? 'generic',
      title: (row['title'] as String?) ?? '',
      body: (row['body'] as String?) ?? '',
      entityType: row['entity_type'] as String?,
      entityId: row['entity_id'] as String?,
      route: row['route'] as String?,
      metadata: meta,
      readAt: row['read_at'] == null
          ? null
          : DateTime.parse(row['read_at'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
