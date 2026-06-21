// FırınNet — Donor-first SocialPostCard (port from
// `flutter-instagram-offline-first-clone`, MIT, see THIRD_PARTY_NOTICES.md).
//
// Donor: lib/feed/post/view/post_view.dart (PostView + PostLargeView) and
// instagram_blocks_ui PostLarge widget. Donor widget tree:
//   * Author header (avatar + name + ⋮ menu)
//   * Media (image carousel)
//   * Action row (heart / chat_bubble / send / bookmark)
//   * Likes count line
//   * Caption ("author bold + caption")
//   * Comments preview ("View all N comments")
//
// FırınNet adaptasyonu:
//   * BLoC PostBloc yok → Riverpod feedRepositoryProvider.
//   * Optimistic UI (like/save flip + revert on fail) korunur.
//   * Guest guard: canWriteWithRef + showAuthRequiredSheet.
//   * Native share donor SharePost modal yerine system share sheet.
//   * Owner-only ⋮ menü (Sil + Grupta gör).
//   * Donor `UserStoriesAvatar` yerine basit FırınNet avatar (V5'te story).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../feed/models/feed_post.dart';
import '../../feed/models/post_type.dart';
import '../../feed/providers/feed_providers.dart';
import '../../feed/repositories/feed_repository.dart';
import '../../safety/models/report_models.dart';
import '../../safety/widgets/block_user_dialog.dart';
import '../../safety/widgets/report_sheet.dart';
import '../comments/comments_page.dart';
import 'widgets/social_post_video.dart';

class SocialPostCard extends ConsumerStatefulWidget {
  const SocialPostCard({super.key, required this.post});

  final FeedPost post;

  @override
  ConsumerState<SocialPostCard> createState() => _SocialPostCardState();
}

class _SocialPostCardState extends ConsumerState<SocialPostCard> {
  bool _likeBusy = false;
  bool _saveBusy = false;
  bool _shareBusy = false;
  bool _repostBusy = false;

  // Donor optimistic UI pattern (PostBloc.state.isLiked override).
  bool? _likedOverride;
  bool? _savedOverride;
  int? _likeCountOverride;
  bool? _repostedOverride;
  int? _repostCountOverride;

  FeedPost get post => widget.post;

  bool get _displayLiked => _likedOverride ?? post.isLiked;
  bool get _displaySaved => _savedOverride ?? post.isSaved;
  int get _displayLikeCount => _likeCountOverride ?? post.likeCount;
  bool get _displayReposted => _repostedOverride ?? post.isReposted;
  int get _displayRepostCount => _repostCountOverride ?? post.repostCount;

  // Dar yorum-sayacı: yorum eklenince paged feed yeniden çekilmeden kart
  // sayacı override ile anında artar (max(model, override)).
  int get _displayCommentCount {
    ref.watch(feedCommentCountOverrideProvider);
    return ref
        .read(feedCommentCountOverrideProvider.notifier)
        .resolve(post.id, post.commentCount);
  }

  bool _isOwner() {
    final user = ref.watch(currentAuthUserProvider);
    return user != null && user.id == post.ownerId;
  }

  void _onAuthorTap() {
    if (post.ownerId.isEmpty) return;
    context.push('${AppRoutes.userPublicProfile}/${post.ownerId}');
  }

  Future<void> _onLikeTap(FeedRepository repo) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final wasLiked = _displayLiked;
    final wasCount = _displayLikeCount;
    final newLiked = !wasLiked;
    final newCount = newLiked
        ? wasCount + 1
        : (wasCount > 0 ? wasCount - 1 : 0);
    setState(() {
      _likeBusy = true;
      _likedOverride = newLiked;
      _likeCountOverride = newCount;
    });
    try {
      await repo.toggleLike(post.id).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _likedOverride = null;
        _likeCountOverride = null;
      });
    } on GuestActionRequiredException {
      if (mounted) {
        setState(() {
          _likedOverride = wasLiked;
          _likeCountOverride = wasCount;
        });
        await showAuthRequiredSheet(context, ref);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _likedOverride = wasLiked;
          _likeCountOverride = wasCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.feedLikeUpdateError)),
        );
      }
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  Future<void> _onSaveTap(FeedRepository repo) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final wasSaved = _displaySaved;
    setState(() {
      _saveBusy = true;
      _savedOverride = !wasSaved;
    });
    try {
      await repo.toggleSave(post.id).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() => _savedOverride = null);
    } on GuestActionRequiredException {
      if (mounted) {
        setState(() => _savedOverride = wasSaved);
        await showAuthRequiredSheet(context, ref);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _savedOverride = wasSaved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.feedSaveUpdateError)),
        );
      }
    } finally {
      if (mounted) setState(() => _saveBusy = false);
    }
  }

  Future<void> _onRepostTap(FeedRepository repo) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final wasReposted = _displayReposted;
    final wasCount = _displayRepostCount;
    final newReposted = !wasReposted;
    final newCount = newReposted
        ? wasCount + 1
        : (wasCount > 0 ? wasCount - 1 : 0);
    setState(() {
      _repostBusy = true;
      _repostedOverride = newReposted;
      _repostCountOverride = newCount;
    });
    try {
      await repo.toggleRepost(post.id).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _repostedOverride = null;
        _repostCountOverride = null;
      });
      // Toggle yönünü kullanıcıya kısa geri bildirimle bildir.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newReposted
                ? AppStrings.feedRepostedSnack
                : AppStrings.feedRepostUndoneSnack,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } on GuestActionRequiredException {
      if (mounted) {
        setState(() {
          _repostedOverride = wasReposted;
          _repostCountOverride = wasCount;
        });
        await showAuthRequiredSheet(context, ref);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _repostedOverride = wasReposted;
          _repostCountOverride = wasCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.feedRepostUpdateError)),
        );
      }
    } finally {
      if (mounted) setState(() => _repostBusy = false);
    }
  }

  Future<void> _onShareTap() async {
    setState(() => _shareBusy = true);
    try {
      final buf = StringBuffer()
        ..writeln("FırınNet'te bir paylaşım")
        ..writeln()
        ..writeln(post.text.trim())
        ..writeln()
        ..write('Paylaşan: ${post.author}');
      if (post.tags.isNotEmpty) {
        buf
          ..writeln()
          ..writeln()
          ..write(post.tags.map((t) => '#$t').join(' '));
      }
      await Share.share(buf.toString(), subject: AppStrings.feedShareSubject);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.feedShareError)));
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _onDeleteTap() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text(AppStrings.feedPostDeleteConfirmTitle),
        content: const Text(AppStrings.feedPostDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text(AppStrings.feedPostDeleteCancelCta),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text(AppStrings.feedPostDeleteCta),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    debugPrint('[FirinNet][PostCard] delete tap postId=${post.id}');
    final repo = ref.read(feedRepositoryProvider);
    try {
      await repo.deletePost(post.id).timeout(const Duration(seconds: 15));
      debugPrint('[FirinNet][PostCard] delete success postId=${post.id}');
      if (!mounted) return;
      // V1 P0 wiring-fix: _notify() stream tick'ine ek olarak manuel
      // invalidate. Feed listesi + profile post listesi + comments
      // page'in post header cache'i hepsi refresh olsun.
      ref.invalidate(feedPostsProvider);
      ref.invalidate(feedPagedNotifierProvider);
      ref.invalidate(feedPostByIdProvider(post.id));
      ref.invalidate(userPostsProvider(post.ownerId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.feedPostDeleteSuccess)),
      );
    } on GuestActionRequiredException {
      debugPrint(
        '[FirinNet][PostCard] delete blocked: guest guard postId=${post.id}',
      );
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugPrint('[FirinNet][PostCard] delete error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.feedPostDeleteError)),
      );
    }
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return 'şimdi';
    if (d.inHours < 24) return '${d.inHours} sa önce';
    if (d.inDays < 2) return 'dün';
    return '${d.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(feedRepositoryProvider);
    final theme = Theme.of(context);
    final imageUrl = post.firstImage?.publicUrl;
    // V2 Commit 3 — Video post desteği. Image yoksa video varsa player
    // render edilir. Tek post'ta image OR video (V3'te kombo).
    final videoUrl = post.firstVideo?.publicUrl;
    final isOwner = _isOwner();
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        // Visual North Star Sprint 1A — kartlar arası 12 px nefes
        // (önceki 6); referans tasarıma yaklaşma, görsel ayrışma.
        10,
        AppSpacing.pageH,
        10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: AppShadow.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            post: post,
            timeAgo: _timeAgo(post.createdAt),
            isOwner: isOwner,
            onAuthorTap: _onAuthorTap,
            onDelete: isOwner ? _onDeleteTap : null,
            onEdit: isOwner
                ? () => context.push(AppRoutes.socialPostEditFor(post.id))
                : null,
            onGoToGroup: post.groupId == null
                ? null
                : () => context.push('${AppRoutes.groups}/${post.groupId}'),
            // UGC Safety V1 — kendi gönderisi şikayet/engel SUNULMAZ.
            onReport: (isOwner || post.ownerId.isEmpty)
                ? null
                : () => showReportSheet(
                      context,
                      ref,
                      targetType: ReportTargetType.feedPost,
                      targetId: post.id,
                      reportedUserId: post.ownerId,
                    ),
            onBlock: (isOwner || post.ownerId.isEmpty)
                ? null
                : () =>
                    confirmAndBlockUser(context, ref, userId: post.ownerId),
          ),
          // Twitter/X: kart gövdesine (metin + etiket + görsel) dokunmak
          // detay sayfasını açar. Action ikonları kendi InkWell'leriyle bu
          // tap'i ezmez (en içteki handler kazanır → çakışma yok). Video
          // kendi oynatma kontrollerini koruması için tap sarmalayıcı DIŞINDA.
          InkWell(
            onTap: () {
              debugPrint(
                '[FirinNet][PostCard] card tap → detail postId=${post.id}',
              );
              SocialCommentsPage.show(context, post.id);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Caption(author: post.author, text: post.text),
                if (post.tags.isNotEmpty) _TagsRow(tags: post.tags),
                if (imageUrl != null) _PostMedia(imageUrl: imageUrl),
              ],
            ),
          ),
          if (imageUrl == null && videoUrl != null)
            SocialPostVideo(url: videoUrl),
          // Sayılar (beğeni/yorum/repost) action row'da ikon yanında.
          _ActionRow(
            isLiked: _displayLiked,
            isSaved: _displaySaved,
            isReposted: _displayReposted,
            likeBusy: _likeBusy,
            saveBusy: _saveBusy,
            shareBusy: _shareBusy,
            likeCount: _displayLikeCount,
            commentCount: _displayCommentCount,
            repostCount: _displayRepostCount,
            onLike: _likeBusy ? null : () => _onLikeTap(repo),
            onComment: () {
              debugPrint('[FirinNet][PostCard] comment tap postId=${post.id}');
              SocialCommentsPage.show(context, post.id);
            },
            onRepost: _repostBusy ? null : () => _onRepostTap(repo),
            onShare: _shareBusy ? null : _onShareTap,
            onSave: _saveBusy ? null : () => _onSaveTap(repo),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.post,
    required this.timeAgo,
    required this.isOwner,
    required this.onAuthorTap,
    required this.onDelete,
    required this.onEdit,
    required this.onGoToGroup,
    required this.onReport,
    required this.onBlock,
  });

  final FeedPost post;
  final String timeAgo;
  final bool isOwner;
  final VoidCallback onAuthorTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onGoToGroup;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.s,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onAuthorTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.borderHairline, width: 1),
                boxShadow: AppShadow.card,
              ),
              child: Text(
                post.author.isNotEmpty ? post.author[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.brandInk,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          // V1 P0 wiring-fix: author name area artık geniş Expanded InkWell
          // değil; sadece author Text + role/time satırı kendi tap target'ı
          // kadar tıklanabilir. Kartın ortasının (geniş Expanded) yanlışlıkla
          // profile push tetiklemesi engellendi.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onAuthorTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TypeBadge(type: post.type),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Feed Premium Sprint - rol rozeti: sade lemon pale pill.
                    if (post.role.isNotEmpty) ...[
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandLemonPale,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            post.role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.brandInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onDelete != null ||
              onEdit != null ||
              onGoToGroup != null ||
              onReport != null ||
              onBlock != null)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              color: theme.colorScheme.surface,
              onSelected: (v) {
                if (v == 'edit') onEdit?.call();
                if (v == 'delete') onDelete?.call();
                if (v == 'group') onGoToGroup?.call();
                if (v == 'report') onReport?.call();
                if (v == 'block') onBlock?.call();
              },
              itemBuilder: (_) => [
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 8),
                        Text(AppStrings.postEditMenuItem),
                      ],
                    ),
                  ),
                if (onGoToGroup != null)
                  const PopupMenuItem(
                    value: 'group',
                    child: Row(
                      children: [
                        Icon(
                          Icons.forum_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 8),
                        Text(AppStrings.feedActionGoToGroup),
                      ],
                    ),
                  ),
                if (onReport != null)
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 8),
                        Text(AppStrings.safetyActionReport),
                      ],
                    ),
                  ),
                if (onBlock != null)
                  const PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(
                          Icons.block_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        SizedBox(width: 8),
                        Text(
                          AppStrings.safetyActionBlock,
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        SizedBox(width: 8),
                        Text(
                          AppStrings.feedPostDeleteCta,
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final PostType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: type.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: type.accent.withValues(alpha: 0.32),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 13, color: type.accent),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: TextStyle(
              color: type.accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostMedia extends StatelessWidget {
  const _PostMedia({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        // Perf: feed full-width görseli telefon ekranı için decode edilir;
        // tam çözünürlük decode (bellek spike) yerine 720px üst sınır.
        memCacheWidth: 720,
        placeholder: (_, __) => Container(
          color: AppColors.surface,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 1.6),
        ),
        errorWidget: (_, __, ___) => Container(
          color: AppColors.surface,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// FırınNet action row — 4 eşit dağılmış sade buton: beğen / yorum / kaydet /
/// paylaş. Beğeni ve yorum sayıları ikon+etiketin yanında gösterilir (0 ise
/// gizli); ayrı "etkileşim özeti" satırı yok (çift gösterim istenmiyor).
/// Kaydet/Paylaş'ta public sayı olmadığı için sayaç gösterilmez.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.isLiked,
    required this.isSaved,
    required this.isReposted,
    required this.likeBusy,
    required this.saveBusy,
    required this.shareBusy,
    required this.likeCount,
    required this.commentCount,
    required this.repostCount,
    required this.onLike,
    required this.onComment,
    required this.onRepost,
    required this.onShare,
    required this.onSave,
  });

  final bool isLiked;
  final bool isSaved;
  final bool isReposted;
  final bool likeBusy;
  final bool saveBusy;
  final bool shareBusy;
  final int likeCount;
  final int commentCount;
  final int repostCount;
  final VoidCallback? onLike;
  final VoidCallback onComment;
  final VoidCallback? onRepost;
  final VoidCallback? onShare;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(boxShadow: const []),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 0,
      ),
      child: Row(
        children: [
          // V1 P0 — Beğeni Icons.favorite (kalp) yerine thumb_up_alt.
          // Kalp + kırmızı romantik Instagram dili istemiyoruz.
          // Aktif renk: pressed lemon. Idle: textPrimary.
          Expanded(
            child: _ActionButton(
              icon: isLiked
                  ? Icons.thumb_up_alt_rounded
                  : Icons.thumb_up_alt_outlined,
              color: isLiked
                  ? AppColors.brandLemonPressed
                  : AppColors.textPrimary,
              label: AppStrings.feedActionLike,
              count: likeCount,
              onTap: onLike,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.mode_comment_outlined,
              color: AppColors.textPrimary,
              label: AppStrings.feedActionComment,
              count: commentCount,
              onTap: onComment,
            ),
          ),
          // Repost — Twitter/X "yeniden paylaş". Aktif: yeşil. Sıra:
          // Beğen · Yorum · Repost · Kaydet · Paylaş.
          Expanded(
            child: _ActionButton(
              icon: Icons.repeat_rounded,
              color: isReposted ? AppColors.success : AppColors.textPrimary,
              label: AppStrings.feedActionRepost,
              count: repostCount,
              onTap: onRepost,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: isSaved
                  ? AppColors.brandLemonPressed
                  : AppColors.textPrimary,
              label: AppStrings.feedActionSave,
              onTap: onSave,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.ios_share_rounded,
              color: AppColors.textPrimary,
              label: AppStrings.feedActionShare,
              onTap: onShare,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  /// İkon+etiketin yanında gösterilecek sayaç. `null` veya `0` ise hiç
  /// gösterilmez (yalnız ikon+etiket kalır). Kaydet/Paylaş'ta public sayı
  /// olmadığı için bu butonlara count geçilmez.
  final int? count;

  @override
  Widget build(BuildContext context) {
    // Yazısız ikon satırı (Twitter/Instagram dili). Etiket görünmez;
    // erişilebilirlik için Tooltip + Icon.semanticLabel taşır. Sayı varsa
    // ikonun yanında (0/null gizli, kibar TR format: 142 / 1,2 B / 1,1 Mn).
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Faz 2 Pass 3 — ikon değişiminde (toggle) zarif scale+fade pop.
              AnimatedSwitcher(
                duration: AppDuration.fast,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: Tween<double>(begin: 0.82, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  color: color,
                  size: 20,
                  semanticLabel: label,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _formatCount(count!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onTap == null ? AppColors.textMuted : color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.author, required this.text});
  final String author;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.m,
      ),
      // V1 P0 — Twitter/Facebook okunabilirlik: caption ana içerik, 17 px.
      // Post card polish — height 1.4 → 1.5 (daha rahat satır aralığı).
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16.5,
          height: 1.48,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TagsRow extends StatelessWidget {
  const _TagsRow({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    // Visual North Star Sprint 1A — TagChip ortak widget'a geçti.
    // softGold pill bg + label (AppTypography.labelLarge), `#` prefix
    // TagChip içinde otomatik.
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, 0, AppSpacing.m, 6),
      child: Wrap(
        spacing: 5,
        runSpacing: 4,
        children: [for (final t in tags) TagChip(label: t)],
      ),
    );
  }
}

/// Kibar Türkçe etkileşim sayısı formatı (İngilizce K/M değil B/Mn).
///   < 1.000      → 142
///   < 1.000.000  → 1,2 B  /  12,4 B
///   ≥ 1.000.000  → 1,1 Mn
String _formatCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) return '${_shortDecimal(value / 1000)} B';
  return '${_shortDecimal(value / 1000000)} Mn';
}

/// Tek ondalık, virgül ayraç; ",0" kuyruğunu kırpar (1,0 → 1).
String _shortDecimal(double d) {
  final s = d.toStringAsFixed(1);
  final dot = s.indexOf('.');
  final intPart = s.substring(0, dot);
  final dec = s.substring(dot + 1);
  return dec == '0' ? intPart : '$intPart,$dec';
}
