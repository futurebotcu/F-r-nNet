// FırınNet Social V2 Commit 2 — Story viewer page.
//
// Donor `lib/stories/view/stories_page.dart` (story_view paketi) muadili.
// FırınNet sade: tek user'ın fresh story listesini tam ekran gösterir;
// tap-to-advance, swipe-down-to-close, owner için ⋮ → Sil.
//
// Donor'un `StoryController + gestures + autoplay duration` mekanizması
// olduğu gibi alınmadı (story_view paketi); sade FırınNet viewer:
//   * Mevcut index state, tap → next, tap-left → previous, swipe → close.
//   * Auto-advance 5s timer (image) — basit Timer.periodic.
//   * Progress indicator bar üstte.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/social_profile.dart';
import '../providers/social_providers.dart';
import 'models/social_story.dart';

class SocialStoryViewerPage extends ConsumerStatefulWidget {
  const SocialStoryViewerPage({super.key, required this.ownerId});

  final String ownerId;

  @override
  ConsumerState<SocialStoryViewerPage> createState() =>
      _SocialStoryViewerPageState();
}

class _SocialStoryViewerPageState
    extends ConsumerState<SocialStoryViewerPage>
    with SingleTickerProviderStateMixin {
  static const Duration _imageDuration = Duration(seconds: 5);
  int _index = 0;
  AnimationController? _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: _imageDuration,
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _next();
        }
      });
  }

  @override
  void dispose() {
    _progress?.dispose();
    super.dispose();
  }

  void _startProgress() {
    _progress
      ?..reset()
      ..forward();
  }

  void _next() {
    final stories = ref
        .read(socialUserFreshStoriesProvider(widget.ownerId))
        .valueOrNull;
    if (stories == null) return;
    if (_index + 1 >= stories.length) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _index++);
    _startProgress();
  }

  void _prev() {
    if (_index <= 0) return;
    setState(() => _index--);
    _startProgress();
  }

  Future<void> _onDelete(SocialStory story) async {
    _progress?.stop();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.elevatedCard,
        content: const Text(
          AppStrings.storyDeleteConfirm,
          style: TextStyle(fontSize: 15.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.storyDeleteCancelCta),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text(AppStrings.storyDeleteCta),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      _progress?.forward();
      return;
    }
    debugPrint('[FirinNet][StoryViewer] delete tap id=${story.id}');
    final repo = ref.read(socialStoriesRepositoryProvider);
    try {
      await repo
          .deleteStory(story.id)
          .timeout(const Duration(seconds: 15));
      debugPrint(
        '[FirinNet][StoryViewer] delete success id=${story.id}',
      );
      if (!mounted) return;
      ref.invalidate(socialFreshStoriesProvider);
      ref.invalidate(
        socialUserFreshStoriesProvider(widget.ownerId),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.storyDeletedSnack)),
      );
      // Sil sonrası pop — listede kalan story'leri tekrar render etmeye
      // gerek yok (basit, user akışı kırılmaz).
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('[FirinNet][StoryViewer] delete error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.storyDeleteFailed)),
      );
      _progress?.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final storiesAsync =
        ref.watch(socialUserFreshStoriesProvider(widget.ownerId));
    final profileAsync = ref.watch(socialProfileProvider(widget.ownerId));
    final currentUser = ref.watch(currentAuthUserProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: storiesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (_, __) => const Center(
          child: Text(
            'Hikaye yüklenemedi.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        data: (stories) {
          if (stories.isEmpty) {
            // Tüm story'ler sıralı/silinmiş; viewer'ı kapat.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.pop();
            });
            return const SizedBox.shrink();
          }
          if (_index >= stories.length) {
            _index = stories.length - 1;
          }
          // İlk frame'de progress başlat.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_progress?.status == AnimationStatus.dismissed) {
              _startProgress();
            }
          });
          final story = stories[_index];
          final isOwner =
              currentUser != null && currentUser.id == story.ownerId;
          return SafeArea(
            child: GestureDetector(
              onTapUp: (details) {
                final w = MediaQuery.of(context).size.width;
                if (details.localPosition.dx < w / 3) {
                  _prev();
                } else {
                  _next();
                }
              },
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 200) {
                  Navigator.of(context).maybePop();
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Media
                  Center(
                    child: CachedNetworkImage(
                      imageUrl: story.contentUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                  // Progress bars (her story için ince çubuk)
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        for (var i = 0; i < stories.length; i++) ...[
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _progress!,
                              builder: (_, __) {
                                final value = i < _index
                                    ? 1.0
                                    : i == _index
                                        ? _progress!.value
                                        : 0.0;
                                return LinearProgressIndicator(
                                  value: value,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.25),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  minHeight: 3,
                                );
                              },
                            ),
                          ),
                          if (i < stories.length - 1)
                            const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ),
                  // Üst başlık
                  Positioned(
                    top: 24,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        _OwnerChip(profileAsync: profileAsync),
                        const Spacer(),
                        if (isOwner)
                          IconButton(
                            tooltip: AppStrings.storyDeleteCta,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            onPressed: () => _onDelete(story),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OwnerChip extends StatelessWidget {
  const _OwnerChip({required this.profileAsync});
  final AsyncValue<SocialProfile> profileAsync;

  @override
  Widget build(BuildContext context) {
    final name = profileAsync.maybeWhen(
      data: (p) => p.displayNameOrFallback,
      orElse: () => 'FırınNet Kullanıcısı',
    );
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.softGold.withValues(alpha: 0.34),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}
