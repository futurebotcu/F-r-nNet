import '../../auth/services/auth_required_guard.dart';
import '../../jobs/models/job_offer_post.dart';
import '../../worker/models/job_seek_post.dart';
import '../models/job_conversation.dart';
import '../models/job_message.dart';
import 'job_messaging_repository.dart';

/// Guest yazma korumalı [JobMessagingRepository] dekoratörü.
///
/// Liste/okuma metotları pass-through. Yazma metotları (conversation başlat,
/// mesaj gönder, soft delete, close) auth yoksa [GuestActionRequiredException]
/// fırlatır → UI [runGuardedMutation] ile yakalayıp AuthRequired sheet açar.
class GuardedJobMessagingRepository implements JobMessagingRepository {
  GuardedJobMessagingRepository({
    required this.inner,
    required this.canWriteCheck,
  });

  final JobMessagingRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  @override
  Future<List<JobConversation>> listMyConversations() =>
      inner.listMyConversations();

  @override
  Future<List<JobMessage>> listMessages(String conversationId) =>
      inner.listMessages(conversationId);

  @override
  Future<JobConversation> startForJobOffer({
    required JobOfferPost offer,
    required String firstMessage,
  }) {
    _requireWrite('ilan sahibine mesaj yollamak');
    return inner.startForJobOffer(offer: offer, firstMessage: firstMessage);
  }

  @override
  Future<JobConversation> startForJobSeek({
    required JobSeekPost post,
    required String firstMessage,
  }) {
    _requireWrite('iş arayan ile iletişime geçmek');
    return inner.startForJobSeek(post: post, firstMessage: firstMessage);
  }

  @override
  Future<JobMessage> sendMessage({
    required String conversationId,
    required String body,
  }) {
    _requireWrite('mesaj göndermek');
    return inner.sendMessage(conversationId: conversationId, body: body);
  }

  @override
  Future<void> softDeleteMessage(String messageId) {
    _requireWrite('mesajı silmek');
    return inner.softDeleteMessage(messageId);
  }

  @override
  Future<void> closeConversation(String conversationId) {
    _requireWrite('sohbeti kapatmak');
    return inner.closeConversation(conversationId);
  }

  @override
  Stream<void> watch() => inner.watch();
}
