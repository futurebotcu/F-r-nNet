import 'dart:async';

import '../../jobs/models/job_offer_post.dart';
import '../../worker/models/job_seek_post.dart';
import '../models/job_conversation.dart';
import '../models/job_message.dart';
import 'job_messaging_repository.dart';

/// In-memory mesajlaşma deposu — Supabase kapalı veya guest local mod
/// için. Gerçek auth/cross-user gizliliği yoktur; yalnız tek cihazlık
/// preview davranışı sağlar.
class LocalJobMessagingRepository implements JobMessagingRepository {
  LocalJobMessagingRepository({String? selfId})
      : _selfId = selfId ?? 'local_self';

  final String _selfId;
  final List<JobConversation> _conversations = <JobConversation>[];
  final List<JobMessage> _messages = <JobMessage>[];
  final StreamController<void> _changes =
      StreamController<void>.broadcast();

  int _seq = 0;
  String _gen(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  void _notify() => _changes.add(null);

  @override
  Future<List<JobConversation>> listMyConversations() async {
    final out = _conversations
        .where((c) => c.initiatorId == _selfId || c.recipientId == _selfId)
        .toList();
    out.sort((a, b) {
      final ad = a.lastMessageAt ?? a.createdAt ?? DateTime(1900);
      final bd = b.lastMessageAt ?? b.createdAt ?? DateTime(1900);
      return bd.compareTo(ad);
    });
    return List.unmodifiable(out);
  }

  @override
  Future<List<JobMessage>> listMessages(String conversationId) async {
    final out = _messages
        .where((m) => m.conversationId == conversationId)
        .toList();
    out.sort((a, b) {
      final ad = a.createdAt ?? DateTime(1900);
      final bd = b.createdAt ?? DateTime(1900);
      return ad.compareTo(bd);
    });
    return List.unmodifiable(out);
  }

  JobConversation? _findExisting({
    required String relatedType,
    String? jobOfferId,
    String? jobSeekPostId,
    required String initiatorId,
  }) {
    for (final c in _conversations) {
      if (c.relatedType != relatedType) continue;
      if (c.initiatorId != initiatorId) continue;
      if (relatedType == 'job_offer' && c.jobOfferId == jobOfferId) return c;
      if (relatedType == 'job_seek' && c.jobSeekPostId == jobSeekPostId) {
        return c;
      }
    }
    return null;
  }

  @override
  Future<JobConversation> startForJobOffer({
    required JobOfferPost offer,
    required String firstMessage,
  }) async {
    if (offer.id == null) {
      throw StateError('İlan henüz kaydedilmedi.');
    }
    if (offer.ownerId == null || offer.ownerId == _selfId) {
      throw StateError('Kendi ilanına başvuru yapılamaz.');
    }
    final existing = _findExisting(
      relatedType: 'job_offer',
      jobOfferId: offer.id,
      initiatorId: _selfId,
    );
    final convo = existing ??
        JobConversation(
          id: _gen('lc'),
          relatedType: 'job_offer',
          jobOfferId: offer.id,
          initiatorId: _selfId,
          recipientId: offer.ownerId!,
          createdAt: DateTime.now(),
          relatedTitle: offer.title,
          otherPartyName: offer.authorName,
        );
    if (existing == null) _conversations.add(convo);
    if (firstMessage.trim().isNotEmpty) {
      await _appendMessage(convo.id!, firstMessage.trim());
    }
    _notify();
    return convo;
  }

  @override
  Future<JobConversation> startForJobSeek({
    required JobSeekPost post,
    required String firstMessage,
  }) async {
    if (post.id == null) {
      throw StateError('İlan henüz kaydedilmedi.');
    }
    if (post.ownerId == null || post.ownerId == _selfId) {
      throw StateError('Kendi ilanına başvuru yapılamaz.');
    }
    final existing = _findExisting(
      relatedType: 'job_seek',
      jobSeekPostId: post.id,
      initiatorId: _selfId,
    );
    final convo = existing ??
        JobConversation(
          id: _gen('lc'),
          relatedType: 'job_seek',
          jobSeekPostId: post.id,
          initiatorId: _selfId,
          recipientId: post.ownerId!,
          createdAt: DateTime.now(),
          relatedTitle: post.title,
          otherPartyName: post.professionBadge,
        );
    if (existing == null) _conversations.add(convo);
    if (firstMessage.trim().isNotEmpty) {
      await _appendMessage(convo.id!, firstMessage.trim());
    }
    _notify();
    return convo;
  }

  Future<JobMessage> _appendMessage(String conversationId, String body) async {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx < 0) throw StateError('Conversation bulunamadı.');
    final now = DateTime.now();
    final msg = JobMessage(
      id: _gen('lm'),
      conversationId: conversationId,
      senderId: _selfId,
      body: body,
      createdAt: now,
    );
    _messages.add(msg);
    _conversations[idx] =
        _conversations[idx].copyWith(lastMessageAt: now, updatedAt: now);
    _notify();
    return msg;
  }

  @override
  Future<JobMessage> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    if (body.trim().isEmpty) {
      throw StateError('Boş mesaj gönderilemez.');
    }
    final convoIdx = _conversations.indexWhere((c) => c.id == conversationId);
    if (convoIdx < 0) throw StateError('Conversation bulunamadı.');
    if (_conversations[convoIdx].isClosed) {
      throw StateError('Bu sohbet kapalı.');
    }
    return _appendMessage(conversationId, body.trim());
  }

  @override
  Future<void> softDeleteMessage(String messageId) async {
    final i = _messages.indexWhere((m) => m.id == messageId);
    if (i < 0) return;
    if (_messages[i].senderId != _selfId) {
      throw StateError('Sadece kendi mesajını silebilirsin.');
    }
    _messages[i] = _messages[i].copyWith(isDeleted: true);
    _notify();
  }

  @override
  Future<void> closeConversation(String conversationId) async {
    final i = _conversations.indexWhere((c) => c.id == conversationId);
    if (i < 0) return;
    _conversations[i] = _conversations[i].copyWith(
      status: 'closed',
      updatedAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
