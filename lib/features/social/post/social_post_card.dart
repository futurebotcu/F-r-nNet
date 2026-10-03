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
import 'package:share_plus/share_plus.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/firinnet_avatar.dart';
import '../../../core/widgets/interactions.dart';
import '../../../core/utils/relative_time.dart';
import '../../academy/academy_navigation.dart';
import '../../academy/providers/academy_providers.dart';
import '../../academy/screens/academy_page.dart' show AcademyAiBadge;
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../feed/models/feed_media.dart';
import '../../feed/models/feed_post.dart';
import '../../feed/models/post_type.dart';
import '../../feed/providers/feed_providers.dart';
import '../../feed/repositories/feed_repository.dart';
import '../../safety/models/report_models.dart';
import '../../safety/widgets/block_user_dialog.dart';
import '../../safety/widgets/report_sheet.dart';
import '../comments/comments_page.dart';
import 'widgets/feed_post_image.dart';
import 'widgets/social_post_video.dart';

/// Gönderi etkileşimleri (beğen / kaydet / yeniden paylaş / paylaş / sil +
/// ⋮ menü) — feed kartı ve gönderi detayı AYNI handler'ları kullanır.
/// Optimistic UI (flip + hata olursa geri al) burada tek yerde.
///
/// Kullanan state yalnız [post]'u sağlar; [buildPostHeader] ve
/// [buildPostActionRow] ortak kimlik + aksiyon satırını üretir.
mixin SocialPostInteractionsMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  FeedPost get post;

  /// Silme başarılı olunca çağrılır (detay sayfası kendini kapatır).
  void onPostDeleted() {}

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
    // Akademi botuna dokunuş → tüm Akademi içeriklerinin toplu sayfası
    // (Akademi'deyken tekrar push edilmez). Mizah botu kendi kimliğiyle
    // normal profil sayfasına gider.
    openUserProfileOrAcademy(context, ref, post.ownerId);
  }

  Future<void> _onLikeTap(FeedRepository repo) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    AppHaptics.toggle();
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
        AppFeedback.error(context, AppStrings.feedLikeUpdateError);
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
    AppHaptics.toggle();
    final wasSaved = _displaySaved;
    setState(() {
      _saveBusy = true;
      _savedOverride = !wasSaved;
    });
    try {
      await repo.toggleSave(post.id).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() => _savedOverride = null);
      // Kaydet görünür bir geri bildirim ister (sayaç yok): kısa onay.
      AppFeedback.success(
        context,
        wasSaved
            ? AppStrings.feedActionUnsavedSnack
            : AppStrings.feedActionSavedSnack,
      );
    } on GuestActionRequiredException {
      if (mounted) {
        setState(() => _savedOverride = wasSaved);
        await showAuthRequiredSheet(context, ref);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _savedOverride = wasSaved);
        AppFeedback.error(context, AppStrings.feedSaveUpdateError);
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
      AppFeedback.success(
        context,
        newReposted
            ? AppStrings.feedRepostedSnack
            : AppStrings.feedRepostUndoneSnack,
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
        AppFeedback.error(context, AppStrings.feedRepostUpdateError);
      }
    } finally {
      if (mounted) setState(() => _repostBusy = false);
    }
  }

  Future<void> _onShareTap() async {
    setState(() => _shareBusy = true);
    try {
      final buf = StringBuffer()
        ..writeln(AppStrings.feedShareHeadline)
        ..writeln()
        ..writeln(post.text.trim())
        ..writeln()
        ..write(AppStrings.feedShareAuthorLine(post.author));
      if (post.tags.isNotEmpty) {
        buf
          ..writeln()
          ..writeln()
          ..write(post.tags.map((t) => '#$t').join(' '));
      }
      await Share.share(buf.toString(), subject: AppStrings.feedShareSubject);
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(context, AppStrings.feedShareError);
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _onDeleteTap() async {
    final ok = await showAppConfirmDialog(
      context,
      title: AppStrings.feedPostDeleteConfirmTitle,
      message: AppStrings.feedPostDeleteConfirmBody,
      confirmLabel: AppStrings.feedPostDeleteCta,
      cancelLabel: AppStrings.feedPostDeleteCancelCta,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
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
      AppFeedback.success(context, AppStrings.feedPostDeleteSuccess);
      onPostDeleted();
    } on GuestActionRequiredException {
      debugPrint(
        '[FirinNet][PostCard] delete blocked: guest guard postId=${post.id}',
      );
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugPrint('[FirinNet][PostCard] delete error: $e');
      if (!mounted) return;
      AppFeedback.error(context, AppStrings.feedPostDeleteError);
    }
  }

  /// Yazar kimliği: avatar + ad + (tür · AI rozeti · rol · zaman) + ⋮ menü.
  /// Feed kartı ve detay AYNI widget'ı çizer.
  Widget buildPostHeader() {
    final isOwner = _isOwner();
    final bot = ref.watch(academyBotsByIdProvider).valueOrNull?[post.ownerId];
    return SocialPostHeader(
      post: post,
      timeAgo: relativeTimeTr(post.createdAt),
      isOwner: isOwner,
      isAcademyBot: bot != null && !bot.isHumor,
      academyBadge: switch (bot) {
        null => null,
        final b when b.isHumor => AppStrings.academyHumorBadge,
        _ => AppStrings.academyAiBadge,
      },
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
          : () => confirmAndBlockUser(context, ref, userId: post.ownerId),
    );
  }

  /// Beğen · Yorum · Repost · Kaydet · Paylaş — sayılar ikon yanında.
  Widget buildPostActionRow({required VoidCallback onComment}) {
    final repo = ref.read(feedRepositoryProvider);
    return SocialPostActionRow(
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
      onComment: onComment,
      onRepost: _repostBusy ? null : () => _onRepostTap(repo),
      onShare: _shareBusy ? null : _onShareTap,
      onSave: _saveBusy ? null : () => _onSaveTap(repo),
    );
  }
}

class SocialPostCard extends ConsumerStatefulWidget {
  const SocialPostCard({super.key, required this.post});

  final FeedPost post;

  @override
  ConsumerState<SocialPostCard> createState() => _SocialPostCardState();
}

class _SocialPostCardState extends ConsumerState<SocialPostCard>
    with SocialPostInteractionsMixin<SocialPostCard> {
  @override
  FeedPost get post => widget.post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstImage = post.firstImage;
    // V2 Commit 3 — Video post desteği. Image yoksa video varsa player
    // render edilir. Tek post'ta image OR video (V3'te kombo).
    final videoUrl = post.firstVideo?.publicUrl;
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
          // Repost surfacing — "🔁 <Ad> yeniden paylaştı" attribution satırı.
          if (post.isRepostEntry)
            _RepostAttribution(
              name:
                  post.repostedByName ??
                  AppStrings.feedRepostAttributionFallback,
            ),
          buildPostHeader(),
          // Twitter/X: kart gövdesine (metin + etiket + görsel) dokunmak
          // detay sayfasını açar. Action ikonları kendi InkWell'leriyle bu
          // tap'i ezmez (en içteki handler kazanır → çakışma yok). Video
          // kendi oynatma kontrollerini koruması için tap sarmalayıcı DIŞINDA.
          InkWell(
            onTap: () {
              debugPrint(
                '[FirinNet][PostCard] card tap → detail postId=${post.id}',
              );
              SocialCommentsPage.show(context, post.id, initialPost: post);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SocialPostCaption(text: post.text),
                if (post.tags.isNotEmpty) SocialPostTags(tags: post.tags),
                if (firstImage != null) _PostMedia(media: firstImage),
              ],
            ),
          ),
          if (firstImage == null && videoUrl != null)
            SocialPostVideo(url: videoUrl),
          // Sayılar (beğeni/yorum/repost) action row'da ikon yanında.
          buildPostActionRow(
            onComment: () {
              debugPrint('[FirinNet][PostCard] comment tap postId=${post.id}');
              SocialCommentsPage.show(context, post.id, initialPost: post);
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Repost surfacing — kart üstünde sade "🔁 [Ad] yeniden paylaştı" satırı.
class _RepostAttribution extends StatelessWidget {
  const _RepostAttribution({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        0,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.repeat_rounded,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              AppStrings.feedRepostedByLabel(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.meta,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gönderi kimlik satırı — feed kartı ve gönderi detayının ORTAK başlığı.
class SocialPostHeader extends StatelessWidget {
  const SocialPostHeader({
    super.key,
    required this.post,
    required this.timeAgo,
    required this.isOwner,
    required this.onAuthorTap,
    this.academyBadge,
    this.isAcademyBot = false,
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

  /// Bot içeriği rozeti ('Akademi • AI' / 'Mizah • AI'); null → insan.
  final String? academyBadge;

  /// Akademi botu → marka avatarı (baş harf yerine).
  final bool isAcademyBot;
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
          // Avatar: 40px görsel, 48px dokunma alanı (backend avatar URL'i
          // vermiyor → baş harf; Akademi botu → marka işareti).
          InkWell(
            onTap: onAuthorTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: FirinNetAvatar(
                key: const ValueKey('post_author_avatar'),
                name: post.author,
                size: FirinNetAvatarSize.m,
                kind: isAcademyBot
                    ? FirinNetAvatarKind.academy
                    : FirinNetAvatarKind.person,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
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
                    // İsim satırında yalnız isim: rozetler dar ekranda /
                    // büyük yazıda taşıyordu → meta satırına (Wrap) indi.
                    child: Text(
                      post.author,
                      key: const ValueKey('post_author_name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.authorName,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Meta satırı: tür · AI rozeti · rol · zaman. Wrap → dar
                // genişlikte alt satıra kayar, taşma yok.
                Wrap(
                  key: const ValueKey('post_card_meta'),
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _TypeBadge(type: post.type),
                    if (academyBadge != null)
                      AcademyAiBadge(label: academyBadge!),
                    // Rol: nötr gri pill (sarı aşırı kullanımı azaltıldı).
                    if (post.role.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLine,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            post.role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      timeAgo,
                      key: const ValueKey('post_time'),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
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
              key: const ValueKey('post_more_menu'),
              tooltip: AppStrings.moreActionsTooltip,
              // Kanonik "daha fazla" ikonu (uygulama geneli more_vert).
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textSecondary,
                size: 22,
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
                  PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.block_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.safetyActionBlock,
                          style: _dangerMenuStyle,
                        ),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.feedPostDeleteCta,
                          style: _dangerMenuStyle,
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

/// ⋮ menüdeki yıkıcı seçenek (Engelle / Sil) metni.
final TextStyle _dangerMenuStyle = AppTypography.bodyMedium.copyWith(
  color: AppColors.danger,
);

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final PostType type;

  @override
  Widget build(BuildContext context) {
    // Nötr tür rozeti: açık gri zemin + mürekkep/ikincil metin. Limon
    // tonlu accent beyaz üstünde okunmuyordu; sarı CTA/seçili duruma kaldı.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceLine,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: AppTypography.badge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostMedia extends StatelessWidget {
  const _PostMedia({required this.media});
  final FeedMedia media;

  @override
  Widget build(BuildContext context) {
    return FeedPostImage(
      imageUrl: media.publicUrl,
      width: media.width,
      height: media.height,
      // Perf: feed full-width görseli telefon ekranı için decode edilir;
      // tam çözünürlük decode (bellek spike) yerine 720px üst sınır.
      memCacheWidth: 720,
    );
  }
}

/// FırınNet action row — 4 eşit dağılmış sade buton: beğen / yorum / kaydet /
/// paylaş. Beğeni ve yorum sayıları ikon+etiketin yanında gösterilir (0 ise
/// gizli); ayrı "etkileşim özeti" satırı yok (çift gösterim istenmiyor).
/// Kaydet/Paylaş'ta public sayı olmadığı için sayaç gösterilmez.
class SocialPostActionRow extends StatelessWidget {
  const SocialPostActionRow({
    super.key,
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

  /// Aksiyon satırındaki tüm ikonların ortak boyutu.
  static const double iconSize = 22;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('post_action_row'),
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
              color: isLiked ? AppColors.brandInk : AppColors.textPrimary,
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
              color: isSaved ? AppColors.brandInk : AppColors.textPrimary,
              label: AppStrings.feedActionSave,
              onTap: onSave,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.share_outlined,
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
    // Dokunma alanı ≥ 48px (ikon 20px; satır yüksekliği sabit 48).
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
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
                    // Kanonik aksiyon ikonu boyutu (22) — beş ikon eşit.
                    size: SocialPostActionRow.iconSize,
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
                      style: AppTypography.meta.copyWith(
                        color: onTap == null ? AppColors.textMuted : color,
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
      ),
    );
  }
}

/// Gönderi metni — feed'de [collapsedMaxLines] satırda kesilir ve
/// "devamını gör" açar; detayda ([expandable] false) metin tam gösterilir.
class SocialPostCaption extends StatefulWidget {
  const SocialPostCaption({
    super.key,
    required this.text,
    this.expandable = true,
  });
  final String text;
  final bool expandable;

  /// Feed okuma stili — `bodyLarge` rolü (yalnız-metin gönderi ağır
  /// görünmesin diye 16.5 → 15.5; satır aralığı rahat).
  static const TextStyle textStyle = AppTypography.bodyLarge;

  /// Detay okuma stili — aynı aile, biraz daha ferah (büyük satır aralığı).
  static final TextStyle detailTextStyle = AppTypography.bodyLarge.copyWith(
    fontSize: 16,
    height: 1.6,
  );

  /// Uzun metin akışta bu kadar satırda kesilir; "devamını gör" açar.
  static const int collapsedMaxLines = 6;

  @override
  State<SocialPostCaption> createState() => _CaptionState();
}

class _CaptionState extends State<SocialPostCaption> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // V1 P0 — Twitter/Facebook okunabilirlik: caption ana içerik. Detayda
    // (expandable=false) aynı aile, daha ferah satır aralığı + nefes.
    final style = widget.expandable
        ? SocialPostCaption.textStyle
        : SocialPostCaption.detailTextStyle;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.m,
        widget.expandable ? AppSpacing.xs : AppSpacing.s,
        AppSpacing.m,
        widget.expandable ? AppSpacing.m : AppSpacing.l,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_expanded || !widget.expandable) {
            return Text(
              widget.text,
              key: const ValueKey('post_caption'),
              style: style,
            );
          }
          final painter = TextPainter(
            // Ölçüm, Text'in gerçekte kullandığı stille (tema fontu dahil)
            // yapılmalı; aksi hâlde kısa metinde de "devamını gör" çıkıyordu.
            text: TextSpan(
              text: widget.text,
              style: DefaultTextStyle.of(context).style.merge(style),
            ),
            maxLines: SocialPostCaption.collapsedMaxLines,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          final overflows = painter.didExceedMaxLines;
          painter.dispose();
          final text = Text(
            widget.text,
            key: const ValueKey('post_caption'),
            maxLines: SocialPostCaption.collapsedMaxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
          if (!overflows) return text;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              const SizedBox(height: 2),
              InkWell(
                key: const ValueKey('post_caption_expand'),
                onTap: () => setState(() => _expanded = true),
                borderRadius: BorderRadius.circular(AppRadius.s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    AppStrings.feedCaptionSeeMore,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SocialPostTags extends StatelessWidget {
  const SocialPostTags({super.key, required this.tags});
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
        children: [for (final t in tags) _NeutralTag(label: t)],
      ),
    );
  }
}

/// Nötr hashtag etiketi: açık gri zemin + ikincil metin. Sarı pill her
/// gönderide tekrarlanınca akışı boğuyordu; sarı CTA/seçili duruma kaldı.
class _NeutralTag extends StatelessWidget {
  const _NeutralTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLine,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '#$label',
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
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
