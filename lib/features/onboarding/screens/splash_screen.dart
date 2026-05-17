import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/guest_mode_storage.dart';
import '../../profile/providers/profile_provider.dart';
import '../../profile/repositories/profile_repository.dart';

/// V1.3 — Splash boot decision.
///
/// 6 olası rota:
///   1. supabaseEnabled=false + guest=false → `/auth` (AuthEntryScreen)
///   2. supabaseEnabled=false + guest=true  → `/feed` (local guest demo)
///   3. supabaseEnabled=true  + user=null + guest=false → `/auth`
///   4. supabaseEnabled=true  + user=null + guest=true  → `/feed`
///   5. supabaseEnabled=true  + user!=null + profile complete → `/panel`
///   6. supabaseEnabled=true  + user!=null + profile missing/incomplete → `/profile/create`
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _routed = false;
  // V1.4 P1.2 — Timer field olarak tutuluyor ki dispose'da cancel
  // edilebilsin. Önceden anonim Timer'dı; widget pop edilirse callback
  // hâlâ tetikleniyor, _routed flag double-route'u kapatıyor ama Timer
  // process'i ölü widget üzerinde kaynak israfı yapıyordu.
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Görsel animasyon için kısa bir bekleme + senkron olmayan kararlar paralel.
    _timer = Timer(const Duration(milliseconds: 700), _route);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _route() async {
    if (!mounted || _routed) return;
    _routed = true;

    final guest = await GuestModeStorage.instance.read();

    // 1 / 2 — Supabase yapılandırılmamış
    if (!AppConfig.supabaseEnabled) {
      if (!mounted) return;
      if (guest) {
        ref.read(profileControllerProvider.notifier).useGuest();
        context.go(AppRoutes.feed);
      } else {
        context.go(AppRoutes.authEntry);
      }
      return;
    }

    // 3 / 4 — Supabase var ama oturum yok
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      if (!mounted) return;
      if (guest) {
        ref.read(profileControllerProvider.notifier).useGuest();
        context.go(AppRoutes.feed);
      } else {
        context.go(AppRoutes.authEntry);
      }
      return;
    }

    // 5 / 6 — Supabase var + oturum var → profile completeness'i değerlendir
    final repo = ref.read(profileRepositoryProvider);
    ProfileRepository? r = repo;
    final profile = r != null ? await r.fetchProfile(user.id) : null;
    if (!mounted) return;

    if (profile == null || !profile.isComplete) {
      context.go(AppRoutes.createProfile);
      return;
    }

    // Sahip mode → guest flag temizle (auth aktif).
    await GuestModeStorage.instance.clear();
    if (!mounted) return;
    // V1.3.5 — Login sonrası ilk açılış Feed (sektör akışı). Panel'e
    // bottom nav 5. tab'dan ulaşılır. Brief ürün kararı.
    context.go(AppRoutes.feed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.copper, AppColors.copperMuted],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.copper.withValues(alpha: 0.18),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              AppStrings.appName,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              AppStrings.appPitch,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              AppStrings.launchHint,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
