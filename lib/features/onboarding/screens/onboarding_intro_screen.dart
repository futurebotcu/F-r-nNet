// Faz 2 UI Pass 3 — 3 sayfalık premium intro onboarding.
//
// İlk açılışta uygulamanın NE İŞE YARADIĞINI net anlatır: Topluluk /
// İlanlar+Mesajlar / İşletme araçları. White-first, lemon vurgu, hafif
// geçişler, page indicator, Atla/Devam/Başla. Yeni dependency / ağır asset
// YOK — Material ikonlarıyla zarif hero. "Başla"/"Atla" sonrası seen flag
// set edilir ve /auth'a gidilir (auth/session akışı korunur).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../services/onboarding_seen_storage.dart';

class _IntroPage {
  const _IntroPage({
    required this.icon,
    required this.satellites,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final List<IconData> satellites;
  final String title;
  final String body;
}

const _pages = <_IntroPage>[
  _IntroPage(
    icon: Icons.forum_rounded,
    satellites: [
      Icons.groups_2_rounded,
      Icons.dynamic_feed_rounded,
      Icons.favorite_rounded,
    ],
    title: AppStrings.introP1Title,
    body: AppStrings.introP1Body,
  ),
  _IntroPage(
    icon: Icons.work_rounded,
    satellites: [
      Icons.storefront_rounded,
      Icons.chat_bubble_rounded,
      Icons.handshake_rounded,
    ],
    title: AppStrings.introP2Title,
    body: AppStrings.introP2Body,
  ),
  _IntroPage(
    icon: Icons.dashboard_customize_rounded,
    satellites: [
      Icons.receipt_long_rounded,
      Icons.insights_rounded,
      Icons.menu_book_rounded,
    ],
    title: AppStrings.introP3Title,
    body: AppStrings.introP3Body,
  ),
];

class OnboardingIntroScreen extends ConsumerStatefulWidget {
  const OnboardingIntroScreen({super.key});

  @override
  ConsumerState<OnboardingIntroScreen> createState() =>
      _OnboardingIntroScreenState();
}

class _OnboardingIntroScreenState extends ConsumerState<OnboardingIntroScreen> {
  final _controller = PageController();
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
            // Atla — sağ üst secondary.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, AppSpacing.s, AppSpacing.s, 0),
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
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _IntroPageView(page: _pages[i]),
              ),
            ),
            // Page indicator.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: AppDuration.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppColors.brandLemonPressed
                          : AppColors.borderHairline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.l,
                AppSpacing.xl,
                AppSpacing.l,
              ),
              child: AppPrimaryButton(
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

class _IntroPageView extends StatelessWidget {
  const _IntroPageView({required this.page});
  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Hero(page: page),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Merkez lemon disk + 3 yörünge ikon rozeti — hafif, asset'siz "illustration".
class _Hero extends StatelessWidget {
  const _Hero({required this.page});
  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft pale-lemon halo.
          Container(
            width: 230,
            height: 230,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandLemonPale,
            ),
          ),
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.brandLemonSoft, width: 1),
              boxShadow: AppShadow.soft,
            ),
          ),
          // Merkez ikon — lemon disk.
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandLemon,
            ),
            child: Icon(page.icon, size: 46, color: AppColors.brandInk),
          ),
          // 3 yörünge rozeti.
          _Satellite(icon: page.satellites[0], alignment: const Alignment(0, -1)),
          _Satellite(
            icon: page.satellites[1],
            alignment: const Alignment(0.92, 0.5),
          ),
          _Satellite(
            icon: page.satellites[2],
            alignment: const Alignment(-0.92, 0.5),
          ),
        ],
      ),
    );
  }
}

class _Satellite extends StatelessWidget {
  const _Satellite({required this.icon, required this.alignment});
  final IconData icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderHairline, width: 0.8),
          boxShadow: AppShadow.card,
        ),
        child: Icon(icon, size: 22, color: AppColors.brandInk),
      ),
    );
  }
}
