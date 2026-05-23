// FırınNet V1 Unified Profile M2 — public_profile_detail RPC provider.
//
// Family by userId. SocialProfilePage tek public profile sayfası için
// header + worker + experiences + bakery aggregate çeker. Recipes ayrı
// (mevcut publicRecipesByOwnerProvider zaten is_public=true filter eder).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../models/public_profile_detail.dart';

final publicProfileDetailProvider = FutureProvider.family
    .autoDispose<PublicProfileDetail?, String>((ref, userId) async {
  if (!AppConfig.supabaseEnabled) {
    // V1: Supabase-off modunda RPC çağrılmaz. UI tarafı header'a düşer
    // veya boş gösterir.
    return null;
  }
  final client = sb.Supabase.instance.client;
  final raw = await client.rpc<dynamic>(
    'public_profile_detail',
    params: <String, dynamic>{'p_user_id': userId},
  );
  return PublicProfileDetail.fromRpcJson(raw);
});
