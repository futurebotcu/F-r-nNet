// 4 sayfalık premium intro onboarding.
//
// İlk açılışta FırınNet'in NE OLDUĞUNU anlatır: sektör ağı → sosyal paylaşım →
// pazar/teklif → işletme araçları. White-first, Bumble sarısı vurgu, çok hafif
// sıcak krem yüzeyler; yumuşak PageView geçişleri, animasyonlu dot indicator,
// CTA mikro-geçişi. İlk sayfada gerçek FırınNet marka ikonu gösterilir.
//
// AKIŞ SÖZLEŞMESİ (DEĞİŞMEZ): "Atla" veya son sayfada "FırınNet'e Başla" →
// OnboardingSeenStorage.markSeen() + context.go(AppRoutes.authEntry). Splash
// gate'i ve auth/guest/session akışı bu ekrandan etkilenmez.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/onboarding_page_data.dart';
import '../services/onboarding_seen_storage.dart';
import '../widgets/onboarding_cta_button.dart';
import '../widgets/onboarding_dots.dart';
import '../widgets/onboarding_page.dart';

const List<OnboardingPageData> _pages = <OnboardingPageData>[
  OnboardingPageData(
    kind: OnboardingHeroKind.brand,
    title: AppStrings.introP1Title,
    body: AppStrings.introP1Body,
  ),
  OnboardingPageData(
    kind: OnboardingHeroKind.social,
    title: AppStrings.introP2Title,
    body: AppStrings.introP2Body,
  ),
  OnboardingPageData(
    kind: OnboardingHeroKind.market,
    title: AppStrings.introP3Title,
    body: AppStrings.introP3Body,
  ),
  OnboardingPageData(
    kind: OnboardingHeroKind.ledger,
    title: AppStrings.introP4Title,
    body: AppStrings.introP4Body,
  ),
];

class OnboardingIntroScreen extends StatefulWidget {
  const OnboardingIntroScreen({super.key});

  @override
  State<OnboardingIntroScreen> createState() => _OnboardingIntroScreenState();
}

class _OnboardingIntroScreenState extends State<OnboardingIntroScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingSeenStorage.instance.markSeen();
    if (!mounted) return;
    context.go(AppRoutes.authEntry);
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: AppDuration.normal,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // "Atla" — sağ üst; son sayfada yumuşakça kaybolur.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    0, AppSpacing.s, AppSpacing.s, 0),
                child: AnimatedOpacity(
                  duration: AppDuration.fast,
                  opacity: isLast ? 0 : 1,
                  child: IgnorePointer(
                    ignoring: isLast,
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text(
                        AppStrings.introSkip,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => OnboardingPage(data: _pages[i]),
              ),
            ),
            OnboardingDots(count: _pages.length, index: _index),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.l,
                AppSpacing.xl,
                AppSpacing.l,
              ),
              child: OnboardingCtaButton(
                label: isLast ? AppStrings.introStart : AppStrings.introNext,
                icon: isLast
                    ? Icons.arrow_forward_rounded
                    : Icons.arrow_forward_ios_rounded,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
