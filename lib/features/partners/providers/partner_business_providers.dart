import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/local_partner_business_repository.dart';
import '../data/partner_business_repository.dart';
import '../data/supabase_partner_business_repository.dart';
import '../models/partner_business.dart';

/// Partner reposu — Supabase açıksa gerçek repo, değilse local seed
/// (test/offline). P0 kalıbı: yalnız userId izlenir.
final partnerBusinessRepositoryProvider = Provider<PartnerBusinessRepository>((
  ref,
) {
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  if (AppConfig.supabaseEnabled && userId != null) {
    return SupabasePartnerBusinessRepository(sb.Supabase.instance.client);
  }
  return LocalPartnerBusinessRepository(seed: true);
});

/// Aktif anlaşmalı iş yerleri (ilk 50; V1 client-side filtre bunun üzerinde).
final activePartnersProvider =
    FutureProvider.autoDispose<List<PartnerBusiness>>(
      (ref) => ref.watch(partnerBusinessRepositoryProvider).activePartners(),
    );

final partnerByIdProvider = FutureProvider.autoDispose
    .family<PartnerBusiness?, String>(
      (ref, id) => ref.watch(partnerBusinessRepositoryProvider).partnerById(id),
    );
