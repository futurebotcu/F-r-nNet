import '../models/job_offer_post.dart';

/// Ticari/Toptancı "Usta Arıyor" ilanları için soyut erişim.
abstract class JobOfferRepository {
  Future<List<JobOfferPost>> listActiveOffers({int limit = 100});
  Future<List<JobOfferPost>> listMyOffers();
  Future<JobOfferPost?> getOffer(String id);
  Future<JobOfferPost> upsertOffer(JobOfferPost post);
  Future<void> setActive(String id, bool active);
  Future<void> deleteOffer(String id);
  Stream<void> watch();
}
