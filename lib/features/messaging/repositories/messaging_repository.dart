// FırınNet Messaging M1 — Repository interface.
//
// Triadı: Local (in-memory) + Supabase (PostgREST + Realtime) + Guarded
// (auth guard wrapper). UI yalnız Guarded ile konuşur.

import '../models/conversation.dart';
import '../models/message.dart';

abstract class MessagingRepository {
  // ─── Conversations ──────────────────────────────────────────────

  /// `findOrCreateDirectConversation` RPC sarmalayıcısı. Self-DM,
  /// orphan target, context whitelist, market_listing owner doğrulaması
  /// DB tarafında zorlanır; hata fırlatılırsa istisna olarak yükselir.
  Future<String> findOrCreateDirectConversation({
    required String otherUserId,
    String contextType = 'profile_direct',
    String? contextId,
  });

  /// Kullanıcının dahil olduğu tüm direct conversations, en yeni en üstte.
  /// Sidecar: otherUserName + lastMessageContent + unreadCount doldurulur.
  Future<List<Conversation>> listConversations({int limit = 50});

  /// Tek conversation + sidecar (other user + last message + unread).
  Future<Conversation?> getConversation(String id);

  // ─── Messages ───────────────────────────────────────────────────

  /// Conversation içindeki mesajlar (deleted_at IS NULL), eski → yeni sıralı.
  Future<List<Message>> listMessages(
    String conversationId, {
    int limit = 100,
  });

  /// Text mesaj gönder. message_type='text' RLS WITH CHECK ile sabit.
  Future<Message> sendTextMessage({
    required String conversationId,
    required String content,
  });

  /// `mark_conversation_read` RPC — `last_read_at = now()`.
  Future<void> markAsRead(String conversationId);

  /// `conversation_unread_count` RPC.
  Future<int> unreadCount(String conversationId);

  /// Soft delete: sender kendi mesajını siler (deleted_at = now()).
  Future<void> softDeleteMessage(String messageId);

  // ─── Realtime ───────────────────────────────────────────────────

  /// Conversation INSERT stream'i — Supabase realtime channel
  /// `conv:<id>` postgres_changes filter conversation_id eq.
  /// Local'de noop stream (test). Stream subscribe/cancel kullanıcı sorumluluğunda.
  Stream<Message> watchMessages(String conversationId);

  /// Conversation list değişiklik tick'i (gel-git invalidation).
  Stream<void> watchConversationsTick();
}
