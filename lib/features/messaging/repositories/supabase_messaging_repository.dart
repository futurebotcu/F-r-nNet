// FırınNet Messaging M1 — Supabase repository.
//
// Migration: 20260520160000_messaging_m1_generic.sql
// RPC: find_or_create_direct_conversation, conversation_unread_count,
// mark_conversation_read.
// Realtime: channel('conv:<id>').on('postgres_changes', filter conv_id eq).
//
// Hardening pattern'leri (önceki sprintlerden):
//   * .select('id') + StateError on empty (silent fail guard)
//   * findOrCreate idempotent — DB advisory lock + RPC tarafında race-free
//   * mesaj content length sanity (RLS de zorlar, defansif)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import 'messaging_repository.dart';

class SupabaseMessagingRepository implements MessagingRepository {
  SupabaseMessagingRepository(this._client);

  final SupabaseClient _client;

  final StreamController<void> _tick = StreamController<void>.broadcast();

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('unauthenticated');
    return id;
  }

  void _notify() {
    if (!_tick.isClosed) _tick.add(null);
  }

  // ─── Conversations ──────────────────────────────────────────────

  @override
  Future<String> findOrCreateDirectConversation({
    required String otherUserId,
    String contextType = 'profile_direct',
    String? contextId,
  }) async {
    _requireUserId();
    final raw = await _client.rpc<dynamic>(
      'find_or_create_direct_conversation',
      params: <String, dynamic>{
        'p_other_user': otherUserId,
        'p_context_type': contextType,
        'p_context_id': contextId,
      },
    );
    if (raw == null) {
      throw StateError(
        'find_or_create_direct_conversation returned null',
      );
    }
    _notify();
    return raw.toString();
  }

  @override
  Future<List<Conversation>> listConversations({int limit = 50}) async {
    final meId = _requireUserId();

    // 1) Kendi participant satırlarımı + bağlı conversation row'ları (RLS
    //    aynı conv'a katılımcıları görmemi sağlıyor).
    final mineRows = await _client
        .from('conversation_participants')
        .select('conversation_id, last_read_at')
        .eq('user_id', meId)
        .limit(limit);
    final myConvIds = (mineRows as List)
        .map((r) => (r as Map<String, dynamic>)['conversation_id'] as String)
        .toList();
    if (myConvIds.isEmpty) return const <Conversation>[];

    // 2) Conversation rows (UPDATE atomic değil, updated_at desc).
    final convRows = await _client
        .from('conversations')
        .select(
          'id, type, context_type, context_id, title, created_by, created_at, updated_at',
        )
        .inFilter('id', myConvIds)
        .order('updated_at', ascending: false)
        .limit(limit);
    final convList = (convRows as List).cast<Map<String, dynamic>>();

    // 3) Other participant user_id'leri batch (direct sadece 2 katılımcı).
    final otherRows = await _client
        .from('conversation_participants')
        .select('conversation_id, user_id')
        .inFilter('conversation_id', myConvIds)
        .neq('user_id', meId);
    final otherByConv = <String, String>{
      for (final r in (otherRows as List).cast<Map<String, dynamic>>())
        r['conversation_id'] as String: r['user_id'] as String,
    };

    // M1.2: profiles.display_name join sidecar — ChatScreen AppBar
    // ve MessagesListScreen kartında karşı kullanıcı adı için.
    final otherUserIds = otherByConv.values.toSet().toList();
    final nameById = <String, String>{};
    if (otherUserIds.isNotEmpty) {
      final profileRows = await _client
          .from('profiles')
          .select('id, display_name')
          .inFilter('id', otherUserIds);
      for (final r in (profileRows as List).cast<Map<String, dynamic>>()) {
        nameById[r['id'] as String] =
            (r['display_name'] as String?) ?? '';
      }
    }

    // 4) Last message snapshot — V1 için her conv için son 1 mesaj.
    //    (N+1 ama V1'de küçük; V1.1 view ile optimize.)
    final lastMsgByConv = <String, Map<String, dynamic>>{};
    for (final cid in myConvIds) {
      final rows = await _client
          .from('messages')
          .select('content, sender_id, created_at')
          .eq('conversation_id', cid)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(1);
      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isNotEmpty) lastMsgByConv[cid] = list.first;
    }

    // 5) lastReadAt mine batch.
    final lastReadByConv = <String, DateTime?>{
      for (final r in (mineRows as List).cast<Map<String, dynamic>>())
        r['conversation_id'] as String: (r['last_read_at'] as String?) != null
            ? DateTime.tryParse(r['last_read_at'] as String)
            : null,
    };

    // 6) Compose
    final out = <Conversation>[];
    for (final c in convList) {
      final id = c['id'] as String;
      final lastMsg = lastMsgByConv[id];
      final lastReadAt = lastReadByConv[id];
      DateTime? lastMsgCreated;
      if (lastMsg != null) {
        lastMsgCreated = DateTime.tryParse(
            (lastMsg['created_at'] as String?) ?? '');
      }
      var unread = 0;
      if (lastMsg != null &&
          (lastMsg['sender_id'] as String?) != meId &&
          lastMsgCreated != null &&
          (lastReadAt == null || lastMsgCreated.isAfter(lastReadAt))) {
        // Rough unread; tam sayı RPC'den çekmek isteniyorsa unreadCount() çağrısı.
        unread = 1;
      }
      final otherUid = otherByConv[id];
      out.add(Conversation.fromRow(
        c,
        otherUserId: otherUid,
        otherUserName: otherUid != null ? nameById[otherUid] : null,
        lastMessageContent: lastMsg?['content'] as String?,
        lastMessageSenderId: lastMsg?['sender_id'] as String?,
        lastMessageCreatedAt: lastMsgCreated,
        lastReadAt: lastReadAt,
        unreadCount: unread,
      ));
    }
    return List.unmodifiable(out);
  }

  @override
  Future<Conversation?> getConversation(String id) async {
    final meId = _requireUserId();
    final row = await _client
        .from('conversations')
        .select(
          'id, type, context_type, context_id, title, created_by, created_at, updated_at',
        )
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;

    final otherRow = await _client
        .from('conversation_participants')
        .select('user_id')
        .eq('conversation_id', id)
        .neq('user_id', meId)
        .limit(1)
        .maybeSingle();

    final selfRow = await _client
        .from('conversation_participants')
        .select('last_read_at')
        .eq('conversation_id', id)
        .eq('user_id', meId)
        .maybeSingle();

    final lastMsgs = await _client
        .from('messages')
        .select('content, sender_id, created_at')
        .eq('conversation_id', id)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(1);
    final lastMsgList = (lastMsgs as List).cast<Map<String, dynamic>>();
    final lastMsg = lastMsgList.isEmpty ? null : lastMsgList.first;

    final lastReadAt = (selfRow?['last_read_at'] as String?) != null
        ? DateTime.tryParse(selfRow!['last_read_at'] as String)
        : null;
    DateTime? lastMsgCreated;
    if (lastMsg != null) {
      lastMsgCreated =
          DateTime.tryParse((lastMsg['created_at'] as String?) ?? '');
    }

    final unread = await unreadCount(id);

    // M1.2 sidecar: otherUserName join
    final otherUid = otherRow?['user_id'] as String?;
    String? otherName;
    if (otherUid != null) {
      final p = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', otherUid)
          .maybeSingle();
      otherName = (p?['display_name'] as String?);
    }

    return Conversation.fromRow(
      row,
      otherUserId: otherUid,
      otherUserName: otherName,
      lastMessageContent: lastMsg?['content'] as String?,
      lastMessageSenderId: lastMsg?['sender_id'] as String?,
      lastMessageCreatedAt: lastMsgCreated,
      lastReadAt: lastReadAt,
      unreadCount: unread,
    );
  }

  // ─── Messages ───────────────────────────────────────────────────

  @override
  Future<List<Message>> listMessages(
    String conversationId, {
    int limit = 100,
  }) async {
    _requireUserId();
    final rows = await _client
        .from('messages')
        .select(
          'id, conversation_id, sender_id, content, message_type, attachments, created_at, edited_at, deleted_at',
        )
        .eq('conversation_id', conversationId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Message.fromRow)
        .toList(growable: false);
  }

  @override
  Future<Message> sendTextMessage({
    required String conversationId,
    required String content,
  }) async {
    final meId = _requireUserId();
    if (content.isEmpty || content.length > 4000) {
      throw ArgumentError('content length must be 1..4000');
    }
    final inserted = await _client
        .from('messages')
        .insert(<String, dynamic>{
          'conversation_id': conversationId,
          'sender_id': meId,
          'content': content,
          'message_type': 'text',
        })
        .select(
          'id, conversation_id, sender_id, content, message_type, attachments, created_at, edited_at, deleted_at',
        );
    final list = (inserted as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) {
      // Silent-fail guard (sosyal sprint dersi).
      throw StateError('message insert returned no row');
    }
    _notify();
    return Message.fromRow(list.first);
  }

  @override
  Future<void> markAsRead(String conversationId) async {
    _requireUserId();
    await _client.rpc<dynamic>(
      'mark_conversation_read',
      params: <String, dynamic>{'p_conversation_id': conversationId},
    );
    _notify();
  }

  @override
  Future<int> unreadCount(String conversationId) async {
    _requireUserId();
    final raw = await _client.rpc<dynamic>(
      'conversation_unread_count',
      params: <String, dynamic>{'p_conversation_id': conversationId},
    );
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  @override
  Future<void> softDeleteMessage(String messageId) async {
    final meId = _requireUserId();
    final rows = await _client
        .from('messages')
        .update(<String, dynamic>{
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', messageId)
        .eq('sender_id', meId)
        .select('id');
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) {
      // Silent-fail guard: ya mesaj bulunamadı ya sender değilim.
      throw StateError(
        'soft delete failed: message not found or not sender',
      );
    }
    _notify();
  }

  // ─── Realtime ───────────────────────────────────────────────────

  @override
  Stream<Message> watchMessages(String conversationId) {
    final ctrl = StreamController<Message>.broadcast();
    RealtimeChannel? channel;
    channel = _client
        .channel('conv:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            try {
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;
              final msg = Message.fromRow(newRow);
              if (!ctrl.isClosed) ctrl.add(msg);
            } catch (e) {
              debugPrint('[FirinNet][Messaging] realtime parse error: $e');
            }
          },
        )
        .subscribe();
    ctrl.onCancel = () async {
      try {
        await _client.removeChannel(channel!);
      } catch (_) {}
    };
    return ctrl.stream;
  }

  @override
  Stream<void> watchConversationsTick() => _tick.stream;
}
