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
  final user = ref.watch(currentAuthUserProvider);
  final JobOfferRepository inner;
  if (AppConfig.supabaseEnabled && user != null) {
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

final activeJobOffersProvider =
    FutureProvider<List<JobOfferPost>>((ref) async {
  ref.watch(jobOfferChangesProvider);
  return ref.watch(jobOfferRepositoryProvider).listActiveOffers();
});

final myJobOffersProvider = FutureProvider<List<JobOfferPost>>((ref) async {
  ref.watch(jobOfferChangesProvider);
  return ref.watch(jobOfferRepositoryProvider).listMyOffers();
});
