import '../../jobs/models/job_offer_post.dart';
import '../../worker/models/job_seek_post.dart';
import '../models/job_conversation.dart';
import '../models/job_message.dart';

/// FırınNet job_offer + job_seek mesajlaşma abstract API.
///
/// Mesajlaşma 1-1; her ilan için aynı initiator tek conversation açabilir
/// (Supabase'de partial unique index, lokal impl'de aynı kontrol). Repository
/// `startFor*` çağrıldığında mevcut conversation varsa yeniden kullanır.
abstract class JobMessagingRepository {
  /// Mevcut kullanıcının (initiator veya recipient olduğu) tüm
  /// conversation'larını döner, en son mesaja göre azalan sıralı.
  Future<List<JobConversation>> listMyConversations();

  /// Bir conversation'ın mesajlarını eski → yeni sıralı döner.
  Future<List<JobMessage>> listMessages(String conversationId);

  /// `job_offer_posts`'a bağlı yeni conversation başlatır veya mevcut olanı
  /// döner. `firstMessage` boş değilse o mesajı eklemeye çalışır.
  Future<JobConversation> startForJobOffer({
    required JobOfferPost offer,
    required String firstMessage,
  });

  /// `job_seek_posts`'a bağlı yeni conversation başlatır veya mevcut olanı
  /// döner. `firstMessage` boş değilse o mesajı eklemeye çalışır.
  Future<JobConversation> startForJobSeek({
    required JobSeekPost post,
    required String firstMessage,
  });

  /// Açık bir conversation'a mesaj gönderir.
  Future<JobMessage> sendMessage({
    required String conversationId,
    required String body,
  });

  /// Sadece sender kendi mesajını soft delete edebilir.
  Future<void> softDeleteMessage(String messageId);

  /// Conversation'ı kapatır (status='closed').
  Future<void> closeConversation(String conversationId);

  /// Listelerin invalidate tetiği.
  Stream<void> watch();
}
