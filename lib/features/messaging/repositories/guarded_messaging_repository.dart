// FırınNet Messaging M1 — Guarded wrapper.
//
// Write metodlarında auth check (canWriteCheck) yoksa
// [GuestActionRequiredException] fırlatır. Read metodları guard'sız delege.
// UI tarafı `runGuardedMutation` ile yakalayıp AuthRequiredSheet açar.

import '../../auth/services/auth_required_guard.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'messaging_repository.dart';

class GuardedMessagingRepository implements MessagingRepository {
  GuardedMessagingRepository({
    required this.inner,
    required this.canWriteCheck,
  });

  final MessagingRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  // ── Writes (auth guarded) ───────────────────────────────────────

  @override
  Future<String> findOrCreateDirectConversation({
    required String otherUserId,
    String contextType = 'profile_direct',
    String? contextId,
  }) {
    _requireWrite('mesaj başlatmak');
    return inner.findOrCreateDirectConversation(
      otherUserId: otherUserId,
      contextType: contextType,
      contextId: contextId,
    );
  }

  @override
  Future<Message> sendTextMessage({
    required String conversationId,
    required String content,
  }) {
    _requireWrite('mesaj göndermek');
    return inner.sendTextMessage(
      conversationId: conversationId,
      content: content,
    );
  }

  @override
  Future<Message> sendImageMessage({
    required String conversationId,
    required Map<String, dynamic> attachments,
    String? caption,
  }) {
    _requireWrite('fotoğraf göndermek');
    return inner.sendImageMessage(
      conversationId: conversationId,
      attachments: attachments,
      caption: caption,
    );
  }

  @override
  Future<void> markAsRead(String conversationId) {
    _requireWrite('mesajı okundu işaretlemek');
    return inner.markAsRead(conversationId);
  }

  @override
  Future<void> softDeleteMessage(String messageId) {
    _requireWrite('mesaj silmek');
    return inner.softDeleteMessage(messageId);
  }

  // ── Reads (guard'sız delege) ────────────────────────────────────

  @override
  Future<List<Conversation>> listConversations({int limit = 50}) =>
      inner.listConversations(limit: limit);

  @override
  Future<Conversation?> getConversation(String id) =>
      inner.getConversation(id);

  @override
  Future<List<Message>> listMessages(
    String conversationId, {
    int limit = 100,
  }) =>
      inner.listMessages(conversationId, limit: limit);

  @override
  Future<int> unreadCount(String conversationId) =>
      inner.unreadCount(conversationId);

  @override
  Stream<Message> watchMessages(String conversationId) =>
      inner.watchMessages(conversationId);

  @override
  Stream<void> watchConversationsTick() => inner.watchConversationsTick();
}
