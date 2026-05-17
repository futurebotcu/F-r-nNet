import '../models/app_notification.dart';

/// V1 P1-D — Uygulama içi bildirim erişimi soyut yüzeyi.
///
/// SupabaseNotificationRepository RLS-gated `public.notifications` üzerinde
/// çalışır; LocalNotificationRepository in-memory test/guest fallback'idir.
abstract class NotificationRepository {
  /// Recipient'in tüm bildirimleri — created_at desc, en yeni önce.
  Future<List<AppNotification>> list({int limit = 100});

  /// Okunmamış bildirim sayısı.
  Future<int> unreadCount();

  /// Tek bir bildirimi okundu işaretler. Zaten read ise no-op.
  Future<void> markAsRead(String id);

  /// Tüm okunmamış bildirimleri okundu işaretler.
  Future<void> markAllAsRead();

  /// İçerik değiştiğinde tetiklenir (provider invalidation için).
  Stream<void> watch();
}
