import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../data/academy_repository.dart';
import '../data/supabase_academy_repository.dart';
import '../models/academy_bot_profile.dart';

/// Akademi okuma repository'si — Supabase açıksa canlı, değilse boş.
final academyRepositoryProvider = Provider<AcademyRepository>((ref) {
  if (!AppConfig.supabaseEnabled) return const EmptyAcademyRepository();
  return SupabaseAcademyRepository(sb.Supabase.instance.client);
});

/// Görünür Akademi bot id seti (feed kartı bot rozeti için). Az satır (≤11),
/// autoDispose + cache; feed her post için tek sette üyelik kontrol eder.
final academyBotIdsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  return ref.watch(academyRepositoryProvider).visibleBotIds();
});

/// Belirli bir profilin Akademi bot metadata'sı (profil sayfası davranışı).
/// null → normal kullanıcı.
final academyBotProfileProvider = FutureProvider.family
    .autoDispose<AcademyBotProfile?, String>((ref, userId) async {
      return ref.watch(academyRepositoryProvider).botProfile(userId);
    });
