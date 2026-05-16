import '../../auth/services/auth_required_guard.dart';
import '../models/job_offer_post.dart';
import 'job_offer_repository.dart';

/// V1.3.3 — guest write korumalı [JobOfferRepository] dekoratörü.
class GuardedJobOfferRepository implements JobOfferRepository {
  GuardedJobOfferRepository({
    required this.inner,
    required this.canWriteCheck,
  });

  final JobOfferRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  @override
  Future<List<JobOfferPost>> listActiveOffers({int limit = 100}) =>
      inner.listActiveOffers(limit: limit);

  @override
  Future<List<JobOfferPost>> listMyOffers() => inner.listMyOffers();

  @override
  Future<JobOfferPost?> getOffer(String id) => inner.getOffer(id);

  @override
  Future<JobOfferPost> upsertOffer(JobOfferPost post) {
    _requireWrite('usta arıyor ilanı kaydetmek');
    return inner.upsertOffer(post);
  }

  @override
  Future<void> setActive(String id, bool active) {
    _requireWrite('ilan durumunu güncellemek');
    return inner.setActive(id, active);
  }

  @override
  Future<void> deleteOffer(String id) {
    _requireWrite('ilanı silmek');
    return inner.deleteOffer(id);
  }

  @override
  Stream<void> watch() => inner.watch();
}
