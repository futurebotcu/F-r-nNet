import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/app_notification.dart';
import 'notification_repository.dart';

/// V1 P1-D — `public.notifications` üzerinde RLS-gated okuma/update.
///
/// - INSERT yapmaz (DB tarafında policy yok; RPC üzerinden gelir).
/// - SELECT yalnız recipient_id = auth.uid() satırlarını döndürür (policy).
/// - UPDATE yalnız `read_at` alanını günceller; başka kolonlara dokunulmaz.
class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final sb.SupabaseClient _client;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  void _notify() => _changes.add(null);

  static const String _columns =
      'id, recipient_id, actor_id, type, title, body, '
      'entity_type, entity_id, route, metadata, read_at, created_at';

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<AppNotification>> list({int limit = 100}) async {
    final userId = _userId;
    if (userId == null) return const <AppNotification>[];
    final rows = await _client
        .from('notifications')
        .select(_columns)
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromRow)
        .toList(growable: false);
  }

  @override
  Future<int> unreadCount() async {
    final userId = _userId;
    if (userId == null) return 0;
    // count: 'exact' tek select_count; en hafif yöntem.
    final res = await _client
        .from('notifications')
        .select('id')
        .eq('recipient_id', userId)
        .filter('read_at', 'is', null)
        .count(sb.CountOption.exact);
    return res.count;
  }

  @override
  Future<void> markAsRead(String id) async {
    final userId = _userId;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update(<String, dynamic>{
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('recipient_id', userId)
        // Idempotent: zaten okunmuşu tekrar set etmemek için filter.
        .filter('read_at', 'is', null);
    _notify();
  }

  @override
  Future<void> markAllAsRead() async {
    final userId = _userId;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update(<String, dynamic>{
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('recipient_id', userId)
        .filter('read_at', 'is', null);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
