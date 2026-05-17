import 'dart:async';

import '../models/app_notification.dart';
import 'notification_repository.dart';

/// V1 P1-D — Guest / Supabase-off için in-memory bildirim repository.
///
/// `seed=false` ile boş başlar — test ve guest gezme için temiz zemin.
class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository({this.seed = false}) {
    if (seed) _seed();
  }

  final bool seed;
  final List<AppNotification> _items = <AppNotification>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _notify() => _changes.add(null);

  /// Test ve UI smoke için harici inject.
  void add(AppNotification n) {
    _items.add(n);
    _notify();
  }

  @override
  Future<List<AppNotification>> list({int limit = 100}) async {
    final src = List<AppNotification>.from(_items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (src.length > limit) {
      return List.unmodifiable(src.take(limit));
    }
    return List.unmodifiable(src);
  }

  @override
  Future<int> unreadCount() async {
    return _items.where((n) => n.isUnread).length;
  }

  @override
  Future<void> markAsRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i == -1) return;
    if (_items[i].isRead) return;
    _items[i] = _items[i].copyWith(readAt: DateTime.now());
    _notify();
  }

  @override
  Future<void> markAllAsRead() async {
    final now = DateTime.now();
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].isUnread) {
        _items[i] = _items[i].copyWith(readAt: now);
        changed = true;
      }
    }
    if (changed) _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;

  // ────────── Seed (guest demo) ──────────

  void _seed() {
    final now = DateTime.now();
    _items.addAll([
      AppNotification(
        id: 'n_seed_1',
        recipientId: 'me_misafir',
        type: 'group_join_request',
        title: 'Yeni katılım isteği',
        body: 'Hasan Kara "Ekşi Maya Atölyesi" grubuna katılmak istiyor.',
        route: '/groups/g_eksi_maya',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ]);
  }
}
