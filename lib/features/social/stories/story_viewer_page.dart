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
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/firinnet_avatar.dart';
import 'story_media_frame.dart';

class SocialStoryViewerPage extends ConsumerStatefulWidget {
  const SocialStoryViewerPage({super.key, required this.ownerId});

  final String ownerId;

  @override
  ConsumerState<SocialStoryViewerPage> createState() =>
      _SocialStoryViewerPageState();
}

class _SocialStoryViewerPageState extends ConsumerState<SocialStoryViewerPage>
    with SingleTickerProviderStateMixin {
  static const Duration _imageDuration = Duration(seconds: 5);
  int _index = 0;
  AnimationController? _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: _imageDuration)
      ..addStatusListener((s) {
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
    final ok = await showAppConfirmDialog(
      context,
      title: AppStrings.storyDeleteConfirm,
      confirmLabel: AppStrings.storyDeleteCta,
      cancelLabel: AppStrings.storyDeleteCancelCta,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) {
      _progress?.forward();
      return;
    }
    debugPrint('[FirinNet][StoryViewer] delete tap id=${story.id}');
    final repo = ref.read(socialStoriesRepositoryProvider);
    try {
      await repo.deleteStory(story.id).timeout(const Duration(seconds: 15));
      debugPrint('[FirinNet][StoryViewer] delete success id=${story.id}');
      if (!mounted) return;
      ref.invalidate(socialFreshStoriesProvider);
      ref.invalidate(socialUserFreshStoriesProvider(widget.ownerId));
      AppFeedback.success(context, AppStrings.storyDeletedSnack);
      // Sil sonrası pop — listede kalan story'leri tekrar render etmeye
      // gerek yok (basit, user akışı kırılmaz).
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('[FirinNet][StoryViewer] delete error: $e');
      if (!mounted) return;
      AppFeedback.error(context, AppStrings.storyDeleteFailed);
      _progress?.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final storiesAsync = ref.watch(
      socialUserFreshStoriesProvider(widget.ownerId),
    );
    final profileAsync = ref.watch(socialProfileProvider(widget.ownerId));
    final currentUser = ref.watch(currentAuthUserProvider);
    return Scaffold(
      backgroundColor: AppColors.imageScrimDark,
      body: storiesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.surface),
        ),
        error: (_, __) => Center(
          child: Text(
            AppStrings.storyLoadError,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.surface70,
            ),
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
                  // Media — oluşturma önizlemesiyle AYNI 9:16 çerçeve + fit:
                  // önizlemede görülen kadraj izleyicide birebir korunur.
                  StoryMediaFrame(
                    child: CachedNetworkImage(
                      key: const ValueKey('story_viewer_media'),
                      imageUrl: story.contentUrl,
                      fit: StoryMediaFrame.fit,
                      // Perf: tam ekran story görseli ekran genişliğinde
                      // decode edilir (çok büyük orijinaller için bellek kalkanı).
                      memCacheWidth: 1080,
                      placeholder: (_, __) =>
                          const ColoredBox(color: AppColors.imageScrimDark),
                      errorWidget: (_, __, ___) => AppImageState.error(
                        label: AppStrings.feedPostImageLoadError,
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
                                  backgroundColor: AppColors.surface.withValues(
                                    alpha: 0.25,
                                  ),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColors.surface,
                                      ),
                                  minHeight: 3,
                                );
                              },
                            ),
                          ),
                          if (i < stories.length - 1) const SizedBox(width: 4),
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
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _OwnerChip(profileAsync: profileAsync),
                          ),
                        ),
                        if (isOwner)
                          IconButton(
                            tooltip: AppStrings.storyDeleteCta,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.surface,
                              size: 26,
                            ),
                            onPressed: () => _onDelete(story),
                          ),
                        IconButton(
                          tooltip: AppStrings.socialCloseTooltip,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.surface,
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.imageScrimDark.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FirinNetAvatar(name: name, size: FirinNetAvatarSize.s),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.authorName.copyWith(
                color: AppColors.surface,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
