import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../jobs/models/job_offer_post.dart';
import '../../worker/models/job_seek_post.dart';
import '../models/job_conversation.dart';
import '../models/job_message.dart';
import 'job_messaging_repository.dart';

class SupabaseJobMessagingRepository implements JobMessagingRepository {
  SupabaseJobMessagingRepository(this._client);

  final sb.SupabaseClient _client;
  final StreamController<void> _changes =
      StreamController<void>.broadcast();
  void _notify() => _changes.add(null);

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    return id;
  }

  static const String _convoColumns =
      'id, related_type, job_offer_id, job_seek_post_id, '
      'initiator_id, recipient_id, status, last_message_at, '
      'created_at, updated_at';
  static const String _msgColumns =
      'id, conversation_id, sender_id, body, is_deleted, created_at';

  @override
  Future<List<JobConversation>> listMyConversations() async {
    final me = _requireUserId();
    final rows = await _client
        .from('job_conversations')
        .select(_convoColumns)
        .or('initiator_id.eq.$me,recipient_id.eq.$me')
        .order('last_message_at', ascending: false, nullsFirst: false);
    final list = (rows as List)
        .cast<Map<String, dynamic>>()
        .map(JobConversation.fromRow)
        .toList(growable: false);
    if (list.isEmpty) return list;
    // İlan başlıklarını ayrı sorgularla doldur (join API'si yerine ufak ek
    // SELECT'ler; RLS bunları zaten authenticated select ile döner).
    final offerIds = list
        .where((c) => c.relatedType == 'job_offer' && c.jobOfferId != null)
        .map((c) => c.jobOfferId!)
        .toSet();
    final seekIds = list
        .where((c) => c.relatedType == 'job_seek' && c.jobSeekPostId != null)
        .map((c) => c.jobSeekPostId!)
        .toSet();
    final Map<String, String> titles = <String, String>{};
    if (offerIds.isNotEmpty) {
      final r = await _client
          .from('job_offer_posts')
          .select('id, title')
          .inFilter('id', offerIds.toList(growable: false));
      for (final row in (r as List).cast<Map<String, dynamic>>()) {
        final id = row['id'] as String?;
        final t = row['title'] as String?;
        if (id != null && t != null) titles[id] = t;
      }
    }
    if (seekIds.isNotEmpty) {
      final r = await _client
          .from('job_seek_posts')
          .select('id, title')
          .inFilter('id', seekIds.toList(growable: false));
      for (final row in (r as List).cast<Map<String, dynamic>>()) {
        final id = row['id'] as String?;
        final t = row['title'] as String?;
        if (id != null && t != null) titles[id] = t;
      }
    }
    return list
        .map((c) {
          final key = c.relatedType == 'job_offer'
              ? c.jobOfferId
              : c.jobSeekPostId;
          return c.copyWith(relatedTitle: key == null ? null : titles[key]);
        })
        .toList(growable: false);
  }

  @override
  Future<List<JobMessage>> listMessages(String conversationId) async {
    _requireUserId();
    final rows = await _client
        .from('job_messages')
        .select(_msgColumns)
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(JobMessage.fromRow)
        .toList(growable: false);
  }

  Future<JobConversation?> _findExistingConversation({
    required String relatedType,
    String? jobOfferId,
    String? jobSeekPostId,
    required String initiatorId,
  }) async {
    final query = _client
        .from('job_conversations')
        .select(_convoColumns)
        .eq('related_type', relatedType)
        .eq('initiator_id', initiatorId);
    final filtered = relatedType == 'job_offer'
        ? query.eq('job_offer_id', jobOfferId!)
        : query.eq('job_seek_post_id', jobSeekPostId!);
    final row = await filtered.maybeSingle();
    if (row == null) return null;
    return JobConversation.fromRow(row);
  }

  @override
  Future<JobConversation> startForJobOffer({
    required JobOfferPost offer,
    required String firstMessage,
  }) async {
    final me = _requireUserId();
    if (offer.id == null) {
      throw StateError('İlan henüz kaydedilmedi.');
    }
    if (offer.ownerId == null || offer.ownerId == me) {
      throw StateError('Kendi ilanına başvuru yapılamaz.');
    }
    var existing = await _findExistingConversation(
      relatedType: 'job_offer',
      jobOfferId: offer.id,
      initiatorId: me,
    );
    if (existing == null) {
      final payload = <String, dynamic>{
        'related_type': 'job_offer',
        'job_offer_id': offer.id,
        'initiator_id': me,
        'recipient_id': offer.ownerId,
        'status': 'open',
      };
      final inserted = await _client
          .from('job_conversations')
          .insert(payload)
          .select(_convoColumns)
          .single();
      existing = JobConversation.fromRow(inserted);
    }
    if (firstMessage.trim().isNotEmpty) {
      await _appendMessage(existing.id!, firstMessage.trim());
    }
    _notify();
    return existing.copyWith(
      relatedTitle: offer.title,
      otherPartyName: offer.authorName,
    );
  }

  @override
  Future<JobConversation> startForJobSeek({
    required JobSeekPost post,
    required String firstMessage,
  }) async {
    final me = _requireUserId();
    if (post.id == null) {
      throw StateError('İlan henüz kaydedilmedi.');
    }
    if (post.ownerId == null || post.ownerId == me) {
      throw StateError('Kendi ilanına başvuru yapılamaz.');
    }
    var existing = await _findExistingConversation(
      relatedType: 'job_seek',
      jobSeekPostId: post.id,
      initiatorId: me,
    );
    if (existing == null) {
      final payload = <String, dynamic>{
        'related_type': 'job_seek',
        'job_seek_post_id': post.id,
        'initiator_id': me,
        'recipient_id': post.ownerId,
        'status': 'open',
      };
      final inserted = await _client
          .from('job_conversations')
          .insert(payload)
          .select(_convoColumns)
          .single();
      existing = JobConversation.fromRow(inserted);
    }
    if (firstMessage.trim().isNotEmpty) {
      await _appendMessage(existing.id!, firstMessage.trim());
    }
    _notify();
    return existing.copyWith(
      relatedTitle: post.title,
      otherPartyName: post.professionBadge,
    );
  }

  Future<JobMessage> _appendMessage(String conversationId, String body) async {
    final me = _requireUserId();
    final row = await _client
        .from('job_messages')
        .insert(<String, dynamic>{
          'conversation_id': conversationId,
          'sender_id': me,
          'body': body,
        })
        .select(_msgColumns)
        .single();
    return JobMessage.fromRow(row);
  }

  @override
  Future<JobMessage> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    if (body.trim().isEmpty) {
      throw StateError('Boş mesaj gönderilemez.');
    }
    final msg = await _appendMessage(conversationId, body.trim());
    _notify();
    return msg;
  }

  @override
  Future<void> softDeleteMessage(String messageId) async {
    final me = _requireUserId();
    await _client
        .from('job_messages')
        .update(<String, dynamic>{'is_deleted': true})
        .eq('id', messageId)
        .eq('sender_id', me);
    _notify();
  }

  @override
  Future<void> closeConversation(String conversationId) async {
    _requireUserId();
    await _client
        .from('job_conversations')
        .update(<String, dynamic>{'status': 'closed'})
        .eq('id', conversationId);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
