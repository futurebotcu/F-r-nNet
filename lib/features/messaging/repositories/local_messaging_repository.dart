// FırınNet Messaging M1 — Local (in-memory) repository.
//
// Test ve Supabase-off fallback için davranış parite. Find-or-create
// dedupe, unread count, soft delete, sender-only enforcement.

import 'dart:async';
import 'dart:math';

import '../models/conversation.dart';
import '../models/conversation_participant.dart';
import '../models/message.dart';
import 'messaging_repository.dart';

class LocalMessagingRepository implements MessagingRepository {
  LocalMessagingRepository({String? meId})
      : _meId = meId ?? 'local-user-me';

  final String _meId;
  final List<Conversation> _conversations = [];
  final List<ConversationParticipant> _participants = [];
  final List<Message> _messages = [];

  final StreamController<void> _tick = StreamController<void>.broadcast();
  final Map<String, StreamController<Message>> _watchers = {};

  void _notify() {
    if (!_tick.isClosed) _tick.add(null);
  }

  String _genId(String prefix) {
    final r = Random();
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-${r.nextInt(0xFFFF)}';
  }

  @override
  Future<String> findOrCreateDirectConversation({
    required String otherUserId,
    String contextType = 'profile_direct',
    String? contextId,
  }) async {
    if (otherUserId == _meId) {
      throw StateError('cannot direct-message self');
    }
    const allowed = {'market_listing', 'profile_direct', 'job_offer', 'job_seek'};
    if (!allowed.contains(contextType)) {
      throw ArgumentError('invalid context_type: $contextType');
    }
    if (contextType == 'profile_direct' && contextId != null) {
      throw ArgumentError('profile_direct must not have context_id');
    }
    if (contextType != 'profile_direct' && contextId == null) {
      throw ArgumentError('context_id required for $contextType');
    }

    // Existing?
    final existing = _conversations.where((c) {
      if (c.type != 'direct') return false;
      if (c.contextType != contextType) return false;
      if (c.contextId != contextId) return false;
      final parts = _participants
          .where((p) => p.conversationId == c.id)
          .map((p) => p.userId)
          .toSet();
      return parts.contains(_meId) && parts.contains(otherUserId);
    }).toList();
    if (existing.isNotEmpty) return existing.first.id;

    // New
    final id = _genId('conv');
    final now = DateTime.now();
    _conversations.add(Conversation(
      id: id,
      type: 'direct',
      contextType: contextType,
      contextId: contextId,
      createdBy: _meId,
      createdAt: now,
      updatedAt: now,
    ));
    _participants.add(ConversationParticipant(
      conversationId: id,
      userId: _meId,
      role: 'owner',
      joinedAt: now,
    ));
    _participants.add(ConversationParticipant(
      conversationId: id,
      userId: otherUserId,
      role: 'member',
      joinedAt: now,
    ));
    _notify();
    return id;
  }

  @override
  Future<List<Conversation>> listConversations({int limit = 50}) async {
    final mine = _conversations.where((c) {
      return _participants.any(
        (p) => p.conversationId == c.id && p.userId == _meId,
      );
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final out = <Conversation>[];
    for (final c in mine.take(limit)) {
      final other = _participants
          .where((p) => p.conversationId == c.id && p.userId != _meId)
          .map((p) => p.userId)
          .firstOrNull;
      final selfP = _participants
          .where((p) => p.conversationId == c.id && p.userId == _meId)
          .firstOrNull;
      final convMsgs = _messages
          .where((m) => m.conversationId == c.id && m.deletedAt == null)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final last = convMsgs.firstOrNull;
      final unread = convMsgs
          .where((m) =>
              m.senderId != _meId &&
              (selfP?.lastReadAt == null ||
                  m.createdAt.isAfter(selfP!.lastReadAt!)))
          .length;
      out.add(c.copyWith(
        otherUserId: other,
        lastMessageContent: last?.content,
        lastMessageSenderId: last?.senderId,
        lastMessageCreatedAt: last?.createdAt,
        lastReadAt: selfP?.lastReadAt,
        unreadCount: unread,
      ));
    }
    return List.unmodifiable(out);
  }

  @override
  Future<Conversation?> getConversation(String id) async {
    final list = await listConversations(limit: 1000);
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<List<Message>> listMessages(
    String conversationId, {
    int limit = 100,
  }) async {
    final src = _messages
        .where(
            (m) => m.conversationId == conversationId && m.deletedAt == null)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(
      src.length > limit ? src.sublist(src.length - limit) : src,
    );
  }

  @override
  Future<Message> sendTextMessage({
    required String conversationId,
    required String content,
  }) async {
    final inConv = _participants.any(
      (p) => p.conversationId == conversationId && p.userId == _meId,
    );
    if (!inConv) {
      throw StateError('not a participant');
    }
    if (content.isEmpty || content.length > 4000) {
      throw ArgumentError('content length must be 1..4000');
    }
    final msg = Message(
      id: _genId('msg'),
      conversationId: conversationId,
      senderId: _meId,
      content: content,
      messageType: 'text',
      createdAt: DateTime.now(),
    );
    _messages.add(msg);

    // updated_at bump
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx >= 0) {
      _conversations[idx] =
          _conversations[idx].copyWith(updatedAt: msg.createdAt);
    }

    // realtime
    final ch = _watchers[conversationId];
    if (ch != null && !ch.isClosed) ch.add(msg);
    _notify();
    return msg;
  }

  @override
  Future<Message> sendImageMessage({
    required String conversationId,
    required Map<String, dynamic> attachments,
    String? caption,
  }) async {
    final inConv = _participants.any(
      (p) => p.conversationId == conversationId && p.userId == _meId,
    );
    if (!inConv) {
      throw StateError('not a participant');
    }
    // Local'de signed URL yok; render için url = storage_path fallback.
    final enriched = Map<String, dynamic>.from(attachments);
    enriched['url'] ??= attachments['storage_path'];
    final msg = Message(
      id: _genId('msg'),
      conversationId: conversationId,
      senderId: _meId,
      content: (caption != null && caption.trim().isNotEmpty)
          ? caption.trim()
          : '📷 Fotoğraf',
      messageType: 'text',
      attachments: enriched,
      createdAt: DateTime.now(),
    );
    _messages.add(msg);
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx >= 0) {
      _conversations[idx] =
          _conversations[idx].copyWith(updatedAt: msg.createdAt);
    }
    final ch = _watchers[conversationId];
    if (ch != null && !ch.isClosed) ch.add(msg);
    _notify();
    return msg;
  }

  @override
  Future<void> markAsRead(String conversationId) async {
    final idx = _participants.indexWhere(
      (p) => p.conversationId == conversationId && p.userId == _meId,
    );
    if (idx < 0) return;
    _participants[idx] = ConversationParticipant(
      conversationId: _participants[idx].conversationId,
      userId: _participants[idx].userId,
      role: _participants[idx].role,
      joinedAt: _participants[idx].joinedAt,
      lastReadAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Future<int> unreadCount(String conversationId) async {
    final selfP = _participants
        .where(
            (p) => p.conversationId == conversationId && p.userId == _meId)
        .firstOrNull;
    if (selfP == null) return 0;
    return _messages
        .where((m) =>
            m.conversationId == conversationId &&
            m.deletedAt == null &&
            m.senderId != _meId &&
            (selfP.lastReadAt == null ||
                m.createdAt.isAfter(selfP.lastReadAt!)))
        .length;
  }

  @override
  Future<void> softDeleteMessage(String messageId) async {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) throw StateError('message not found');
    if (_messages[idx].senderId != _meId) {
      throw StateError('only sender can delete');
    }
    _messages[idx] = _messages[idx].copyWith(deletedAt: DateTime.now());
    _notify();
  }

  @override
  Stream<Message> watchMessages(String conversationId) {
    final ch = _watchers.putIfAbsent(
      conversationId,
      () => StreamController<Message>.broadcast(),
    );
    return ch.stream;
  }

  @override
  Stream<void> watchConversationsTick() => _tick.stream;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
