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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../feed/models/feed_post.dart';
import '../../feed/models/post_type.dart';
import '../../feed/providers/feed_providers.dart';
import '../../feed/repositories/feed_repository.dart';
import '../comments/comments_page.dart';

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

  // Donor optimistic UI pattern (PostBloc.state.isLiked override).
  bool? _likedOverride;
  bool? _savedOverride;
  int? _likeCountOverride;

  FeedPost get post => widget.post;

  bool get _displayLiked => _likedOverride ?? post.isLiked;
  bool get _displaySaved => _savedOverride ?? post.isSaved;
  int get _displayLikeCount => _likeCountOverride ?? post.likeCount;

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
    final newCount =
        newLiked ? wasCount + 1 : (wasCount > 0 ? wasCount - 1 : 0);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.feedShareError)),
      );
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
      await repo
          .deletePost(post.id)
          .timeout(const Duration(seconds: 15));
      debugPrint(
        '[FirinNet][PostCard] delete success postId=${post.id}',
      );
      if (!mounted) return;
      // V1 P0 wiring-fix: _notify() stream tick'ine ek olarak manuel
      // invalidate. Feed listesi + profile post listesi + comments
      // page'in post header cache'i hepsi refresh olsun.
      ref.invalidate(feedPostsProvider);
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
    final imageUrl = post.firstImage?.publicUrl;
    final isOwner = _isOwner();
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        6, // V1 P0 — kartlar arası 12 px nefes (önceki 8)
        AppSpacing.pageH,
        6,
      ),
      decoration: BoxDecoration(
        color: AppColors.elevatedCard,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
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
            onGoToGroup: post.groupId == null
                ? null
                : () => context.push('${AppRoutes.groups}/${post.groupId}'),
          ),
          _Caption(author: post.author, text: post.text),
          if (post.tags.isNotEmpty) _TagsRow(tags: post.tags),
          if (imageUrl != null) _PostMedia(imageUrl: imageUrl),
          _ActionRow(
            isLiked: _displayLiked,
            isSaved: _displaySaved,
            likeCount: _displayLikeCount,
            commentCount: post.commentCount,
            likeBusy: _likeBusy,
            saveBusy: _saveBusy,
            shareBusy: _shareBusy,
            onLike: _likeBusy ? null : () => _onLikeTap(repo),
            onComment: () {
              debugPrint(
                '[FirinNet][PostCard] comment tap postId=${post.id}',
              );
              SocialCommentsPage.show(context, post.id);
            },
            onShare: _shareBusy ? null : _onShareTap,
            onSave: _saveBusy ? null : () => _onSaveTap(repo),
          ),
          if (post.commentCount > 0)
            _CommentsPreview(
              count: post.commentCount,
              onTap: () {
                debugPrint(
                  '[FirinNet][PostCard] preview tap postId=${post.id}',
                );
                SocialCommentsPage.show(context, post.id);
              },
            ),
          const SizedBox(height: AppSpacing.s),
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
    required this.onGoToGroup,
  });

  final FeedPost post;
  final String timeAgo;
  final bool isOwner;
  final VoidCallback onAuthorTap;
  final VoidCallback? onDelete;
  final VoidCallback? onGoToGroup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.s,
        AppSpacing.s,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onAuthorTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.softGold.withValues(alpha: 0.16),
                border: Border.all(
                  color: AppColors.softGold.withValues(alpha: 0.32),
                  width: 0.8,
                ),
              ),
              child: Text(
                post.author.isNotEmpty ? post.author[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.softGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
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
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TypeBadge(type: post.type),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      post.role,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                    const Text(
                      '  •  ',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onDelete != null || onGoToGroup != null)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.textMuted,
              ),
              color: AppColors.elevatedCard,
              onSelected: (v) {
                if (v == 'delete') onDelete?.call();
                if (v == 'group') onGoToGroup?.call();
              },
              itemBuilder: (_) => [
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: type.accent.withValues(alpha: 0.32),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 14, color: type.accent),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: TextStyle(
              color: type.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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

/// FırınNet action row — 4 eşit dağılmış buton: beğen / yorum / kaydet /
/// paylaş. Instagram'ın 3 sol + 1 sağ paterni yerine FırınNet kullanıcısı
/// (fırıncı/usta/bayi) için **eşit dağılmış**, **sayılarla**, **etiket
/// görünür** layout.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.isLiked,
    required this.isSaved,
    required this.likeCount,
    required this.commentCount,
    required this.likeBusy,
    required this.saveBusy,
    required this.shareBusy,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
  });

  final bool isLiked;
  final bool isSaved;
  final int likeCount;
  final int commentCount;
  final bool likeBusy;
  final bool saveBusy;
  final bool shareBusy;
  final VoidCallback? onLike;
  final VoidCallback onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderHairline, width: 0.6),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      child: Row(
        children: [
          // V1 P0 — Beğeni Icons.favorite (kalp) yerine thumb_up_alt.
          // Kalp + kırmızı romantik Instagram dili istemiyoruz.
          // Aktif renk: softGold (amber). Idle: textPrimary.
          Expanded(
            child: _ActionButton(
              icon: isLiked
                  ? Icons.thumb_up_alt_rounded
                  : Icons.thumb_up_alt_outlined,
              color: isLiked ? AppColors.softGold : AppColors.textPrimary,
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
          Expanded(
            child: _ActionButton(
              icon: isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: isSaved ? AppColors.softGold : AppColors.textPrimary,
              label: AppStrings.feedActionSave,
              count: 0,
              onTap: onSave,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.ios_share_rounded,
              color: AppColors.textPrimary,
              label: AppStrings.feedActionShare,
              count: 0,
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
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;

  /// Sayı varsa label sonuna " · N" eklenir; 0 ise sadece label.
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final display = count > 0 ? '$label · $count' : label;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s,
          horizontal: 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              display,
              style: TextStyle(
                color: onTap == null ? AppColors.textMuted : color,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
        AppSpacing.l,
        AppSpacing.xs,
        AppSpacing.l,
        AppSpacing.s,
      ),
      // V1 P0 — Twitter/Facebook okunabilirlik: caption ana içerik, 17 px
      // h:1.4. Önceki 13.5 px Instagram caption hissi veriyordu.
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          height: 1.4,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.xs,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: tags
            .map(
              (t) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.borderHairline,
                    width: 0.6,
                  ),
                ),
                child: Text(
                  '#$t',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// "Tüm yorumları gör →" — net link görünümü. Daha önce muted/küçük
/// satırdı, kullanıcı "kart tıklanınca yanlış akış" hissi yaşıyordu;
/// chevron + softGold renk ile tap-edilebilir olduğu net.
class _CommentsPreview extends StatelessWidget {
  const _CommentsPreview({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count ${AppStrings.postCommentsCountLabel}  —  '
                '${AppStrings.postViewAllComments}',
                style: const TextStyle(
                  color: AppColors.softGold,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.softGold,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
