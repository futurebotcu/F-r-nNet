import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import 'providers/academy_providers.dart';

/// Kullanıcı (yazar/takipçi) profiline git — Akademi botu (mizah hariç) ise
/// tek tek bot profili ("FırınNet Hijyen" vb.) yerine toplu Akademi sayfası.
/// Zaten Akademi sayfasındaysa aynı route TEKRAR push edilmez.
void openUserProfileOrAcademy(
  BuildContext context,
  WidgetRef ref,
  String userId,
) {
  if (userId.isEmpty) return;
  final bot = ref.read(academyBotsByIdProvider).valueOrNull?[userId];
  if (bot != null && !bot.isHumor) {
    if (_currentPath(context) == AppRoutes.academy) return;
    context.push(AppRoutes.academy);
    return;
  }
  context.push('${AppRoutes.userPublicProfile}/$userId');
}

String? _currentPath(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.path;
  } catch (_) {
    return null;
  }
}
