import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/job_offer_post.dart';
import '../repositories/guarded_job_offer_repository.dart';
import '../repositories/job_offer_repository.dart';
import '../repositories/local_job_offer_repository.dart';
import '../repositories/supabase_job_offer_repository.dart';

final jobOfferRepositoryProvider = Provider<JobOfferRepository>((ref) {
  // P0 kalıbı: yalnız userId izlenir (token refresh repo resetlemesin).
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  final JobOfferRepository inner;
  if (AppConfig.supabaseEnabled && userId != null) {
    inner = SupabaseJobOfferRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalJobOfferRepository();
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedJobOfferRepository(inner: inner, canWriteCheck: canWrite);
});

final jobOfferChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(jobOfferRepositoryProvider);
  return repo.watch();
});

/// V1.4 P1.1 — autoDispose: jobs ekranı kapandığında listenicisi kalmayan
/// provider state'i silinir. Sayfa tekrar açıldığında taze fetch.
final activeJobOffersProvider =
    FutureProvider.autoDispose<List<JobOfferPost>>((ref) async {
  ref.watch(jobOfferChangesProvider);
  return ref.watch(jobOfferRepositoryProvider).listActiveOffers();
});

final myJobOffersProvider = FutureProvider<List<JobOfferPost>>((ref) async {
  ref.watch(jobOfferChangesProvider);
  return ref.watch(jobOfferRepositoryProvider).listMyOffers();
});
