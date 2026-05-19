import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/social_comment.dart';
import '../repositories/guarded_social_comments_repository.dart';
import '../repositories/local_social_comments_repository.dart';
import '../repositories/social_comments_repository.dart';
import '../repositories/supabase_social_comments_repository.dart';

/// FırınNet Social — provider katmanı.
///
/// Donor-first sosyal modül için Riverpod glue. Comments / future feed /
/// profile / follow / stories aynı dosyada toplu provider olarak verilir;
/// kazalardan kaçınmak için interface'ler net.

// ═══════════════════════════════════════════════════════════════════════
// Comments
// ═══════════════════════════════════════════════════════════════════════

final socialCommentsRepositoryProvider =
    Provider<SocialCommentsRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  final SocialCommentsRepository inner;
  if (AppConfig.supabaseEnabled && user != null) {
    inner = SupabaseSocialCommentsRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalSocialCommentsRepository(
      currentUserId: user?.id ?? 'me_misafir',
    );
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedSocialCommentsRepository(
    inner: inner,
    canWriteCheck: canWrite,
  );
});

/// Tick — comment repository değişikliklerinde fire eder.
final socialCommentsChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(socialCommentsRepositoryProvider);
  return repo.watch();
});

/// Bir post için yorumlar (eski tarih önce).
final socialCommentsProvider = FutureProvider.autoDispose
    .family<List<SocialComment>, String>((ref, postId) async {
  ref.watch(socialCommentsChangesProvider);
  final repo = ref.watch(socialCommentsRepositoryProvider);
  return repo.listComments(postId);
});
