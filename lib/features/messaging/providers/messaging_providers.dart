// FırınNet Messaging M1 — Riverpod providers.
//
// messagingRepositoryProvider: Supabase enabled + user varsa Supabase,
//   yoksa Local. Guarded ile sarılır.
// conversationsListProvider: kullanıcının conversation listesi.
// conversationByIdProvider(id): tek conversation + sidecar.
// messagesListProvider(conversationId): tarihsel mesaj listesi.
// messagesStreamProvider(conversationId): realtime INSERT stream.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../repositories/guarded_messaging_repository.dart';
import '../repositories/local_messaging_repository.dart';
import '../repositories/messaging_repository.dart';
import '../repositories/supabase_messaging_repository.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  final MessagingRepository inner;
  if (AppConfig.supabaseEnabled && user != null) {
    inner = SupabaseMessagingRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalMessagingRepository(meId: user?.id);
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedMessagingRepository(inner: inner, canWriteCheck: canWrite);
});

/// Mesajlaşma katmanı invalidation tick'i (yeni mesaj/conversation
/// gönderildiğinde liste/detail provider'larını re-fetch eder).
final messagingChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(messagingRepositoryProvider);
  return repo.watchConversationsTick();
});

final conversationsListProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
  ref.watch(messagingChangesProvider);
  return ref.watch(messagingRepositoryProvider).listConversations();
});

final conversationByIdProvider = FutureProvider.family
    .autoDispose<Conversation?, String>((ref, id) async {
  ref.watch(messagingChangesProvider);
  return ref.watch(messagingRepositoryProvider).getConversation(id);
});

final messagesListProvider = FutureProvider.family
    .autoDispose<List<Message>, String>((ref, conversationId) async {
  ref.watch(messagingChangesProvider);
  return ref
      .watch(messagingRepositoryProvider)
      .listMessages(conversationId);
});

/// Realtime INSERT stream — UI ChatScreen subscribe edip yeni mesajları
/// listenin kuyruğuna ekler. Cancel olunca channel unsubscribe edilir
/// (SupabaseMessagingRepository.onCancel removeChannel).
final messagesStreamProvider =
    StreamProvider.family.autoDispose<Message, String>(
  (ref, conversationId) =>
      ref.watch(messagingRepositoryProvider).watchMessages(conversationId),
);

final conversationUnreadProvider = FutureProvider.family
    .autoDispose<int, String>((ref, conversationId) async {
  ref.watch(messagingChangesProvider);
  return ref.watch(messagingRepositoryProvider).unreadCount(conversationId);
});

/// M-10 — Toplam okunmamış mesaj sayısı.
///
/// `conversationsListProvider`'daki her conversation'ın `unreadCount`
/// alanının toplamıdır. **Gerçek veriden türetilir** (ek Supabase sorgusu
/// yok); liste henüz yüklenmemiş/hatalıysa 0 döner — sahte/demo sayı
/// üretilmez. Panel "Mesajlar" kartı badge'i bunu kullanır.
final totalUnreadMessagesProvider = Provider.autoDispose<int>((ref) {
  final async = ref.watch(conversationsListProvider);
  return async.maybeWhen(
    data: (list) =>
        list.fold<int>(0, (sum, c) => sum + (c.unreadCount > 0 ? c.unreadCount : 0)),
    orElse: () => 0,
  );
});
