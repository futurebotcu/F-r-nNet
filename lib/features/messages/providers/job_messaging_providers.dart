import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/job_conversation.dart';
import '../models/job_message.dart';
import '../repositories/guarded_job_messaging_repository.dart';
import '../repositories/job_messaging_repository.dart';
import '../repositories/local_job_messaging_repository.dart';
import '../repositories/supabase_job_messaging_repository.dart';

final jobMessagingRepositoryProvider = Provider<JobMessagingRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  final JobMessagingRepository inner;
  if (AppConfig.supabaseEnabled && user != null) {
    inner = SupabaseJobMessagingRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalJobMessagingRepository(selfId: user?.id ?? 'local_self');
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedJobMessagingRepository(
    inner: inner,
    canWriteCheck: canWrite,
  );
});

final jobMessagingChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(jobMessagingRepositoryProvider);
  return repo.watch();
});

final myJobConversationsProvider =
    FutureProvider<List<JobConversation>>((ref) async {
  ref.watch(jobMessagingChangesProvider);
  return ref.watch(jobMessagingRepositoryProvider).listMyConversations();
});

final jobMessagesProvider =
    FutureProvider.family<List<JobMessage>, String>((ref, convoId) async {
  ref.watch(jobMessagingChangesProvider);
  return ref.watch(jobMessagingRepositoryProvider).listMessages(convoId);
});
