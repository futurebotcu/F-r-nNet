import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/app_notification.dart';
import '../repositories/local_notification_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/supabase_notification_repository.dart';

/// V1 P1-D — Bildirim repository sağlayıcısı.
///
/// Authenticated user varsa Supabase; aksi halde Local (guest demo seed).
final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  if (AppConfig.supabaseEnabled && user != null) {
    return SupabaseNotificationRepository(sb.Supabase.instance.client);
  }
  return LocalNotificationRepository(seed: true);
});

/// Repository içeriği değişince tetiklenen tick.
final notificationChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.watch();
});

/// Tüm bildirimler (created_at desc).
final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  ref.watch(notificationChangesProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.list();
});

/// Okunmamış sayısı.
final unreadNotificationsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  ref.watch(notificationChangesProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.unreadCount();
});
