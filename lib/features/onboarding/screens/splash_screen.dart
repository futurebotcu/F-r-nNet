import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/guest_mode_provider.dart';
import '../../auth/services/guest_mode_storage.dart';
import '../../profile/providers/profile_provider.dart';
import '../services/onboarding_seen_storage.dart';

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

  /// İlk açılış kararı: intro onboarding görülmediyse `/intro`, görüldüyse
  /// doğrudan `/auth`. (Yalnız oturum YOK + guest DEĞİL durumunda çağrılır;
  /// guest/login akışı bu yoldan geçmez, korunur.)
  Future<void> _goAuthOrIntro() async {
    final seen = await OnboardingSeenStorage.instance.read();
    if (!mounted) return;
    context.go(seen ? AppRoutes.authEntry : AppRoutes.intro);
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
        await _goAuthOrIntro();
      }
      return;
    }

    // 3 / 4 — Supabase var ama oturum yok
    final user = ref.read(currentAuthUserProvider);

    // V1.4 P1.4 — Defensive mutual-exclusion guard.
    //
    // Supabase aktif + signed-in user + guest flag aynı anda true olamaz.
    // Race condition senaryoları:
    //   - OAuth callback sırasında "Kayıtsız Devam Et" storage yazımı
    //     araya girer ve user oturum aldıktan sonra guest=true kalır.
    //   - Uninstall/reinstall sonrası eski guest flag SharedPreferences'ta
    //     korunmuş olur (bazı OEM'lerde app data tam silinmez).
    // setGuest(false) hem Riverpod state hem SharedPreferences'ı tek
    // çağrıda senkronize eder. user == null branch'i bu noktadan sonra
    // davranışını değiştirmez (zaten user != null olduğu için 5/6 yoluna
    // düşer); guard sadece tutarsız state'i temizler.
    if (user != null && guest) {
      await ref.read(guestModeProvider.notifier).setGuest(false);
      if (!mounted) return;
    }

    if (user == null) {
      if (!mounted) return;
      if (guest) {
        ref.read(profileControllerProvider.notifier).useGuest();
        context.go(AppRoutes.feed);
      } else {
        await _goAuthOrIntro();
      }
      return;
    }

    // 5 / 6 — Supabase var + oturum var → profile completeness'i değerlendir
    final repo = ref.read(profileRepositoryProvider);
    if (repo == null) {
      if (!mounted) return;
      context.go(AppRoutes.createProfile);
      return;
    }

    // OFFLINE COLD-START (PR-OFFLINE-1): profil fetch network ister. İnternet
    // yokken bu çağrı throw/hang ederse splash'ta SONSUZ TAKILMA olurdu (app
    // açılmıyor). Timeout + try/catch ile:
    //   - başarı  → normal completeness kararı,
    //   - hata/timeout (offline) → oturumu KAPATMA / logout YAPMA / sonsuz
    //     spinner'a SOKMA; ana akışa (Feed shell) al. Network alanları kendi
    //     "İnternet bağlantısı yok / Tekrar dene" state'ini gösterir.
    try {
      final profile = await repo
          .fetchProfile(user.id)
          .timeout(const Duration(seconds: 4));
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
    } catch (e) {
      debugPrint('[FirinNet][Splash] profile fetch failed (offline?): $e');
      if (!mounted) return;
      context.go(AppRoutes.feed);
    }
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
                boxShadow: AppShadow.card,
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.surface,
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
