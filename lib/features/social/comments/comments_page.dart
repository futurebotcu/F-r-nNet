// FırınNet — Yorumlar sayfası (FırınNet UX, donor flow).
//
// "Donor'u al" demek "Instagram'ı birebir kopyala" değil. Bu dosya
// itsezlife flutter-instagram-offline-first-clone (MIT) CommentsPage'inin
// **flow mantığını** alır:
//   * Tam ekran route (fullscreen modal)
//   * Liste + composer-sticky-bottom yapısı
//   * Klavye `resizeToAvoidBottomInset` ile composer'ı yukarı iter
//   * Optimistic yok (post-comment kısa süreli backend ack ile yeterli)
//
// Ama görsel kimlik FırınNet'in: büyük tipografi, sıcak ton, geniş
// dokunma alanı, fırıncı/usta/bayi kullanıcısı için rahat okuma.
//
// Tasarım kuralları (kullanıcı PRD):
//   * Avatar 44px, isim 15.5px w800, metin 16px h:1.45
//   * Yorum item'ları dikey nefes (16-18px vertical padding)
//   * Composer min 60px yükseklik, gönder butonu 48px, AppColors.primary
//   * Loading sadece Gönder buton üzerinde (TextField/list bloklanmaz)
//   * Empty: "İlk yorumu sen yaz"
//   * Error: inline mesaj (snackbar değil)
//   * Guest: yorumları görür + alta büyük "Giriş yap" CTA.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../feed/models/feed_post.dart';
import '../../feed/providers/feed_providers.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../../feed/services/feed_boundary_classifier.dart';
import '../../safety/models/report_models.dart';
import '../../safety/providers/safety_providers.dart';
import '../../safety/widgets/block_user_dialog.dart';
import '../../safety/widgets/report_sheet.dart';
import '../models/social_comment.dart';
import '../post/widgets/feed_post_image.dart';
import '../providers/social_providers.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/firinnet_avatar.dart';
import '../../academy/providers/academy_providers.dart';
import '../post/social_post_card.dart';
import '../post/widgets/social_post_video.dart';
import '../../../core/widgets/interactions.dart';
import '../widgets/social_skeletons.dart';

/// Cevap hedefi (tek-seviye): bir ÜST yoruma cevap yazılırken composer bunu
/// okuyup `parentCommentId` geçirir. "Cevapla" set eder; gönderim/iptal
/// temizler. autoDispose: sayfa kapanınca sıfırlanır.
final _replyTargetProvider =
    StateProvider.autoDispose<({String id, String author})?>((ref) => null);

/// Detay aksiyon satırındaki "Yorum" → composer'a odak isteği (sayaç).
final _composerFocusRequestProvider = StateProvider.autoDispose<int>(
  (ref) => 0,
);

class SocialCommentsPage extends ConsumerWidget {
  const SocialCommentsPage({super.key, required this.postId, this.initialPost});

  final String postId;

  /// Feed kartından gelen bilinen gönderi. Verilirse detay açılışında ana
  /// gönderi İLK FRAME'de tam çizilir; postAsync loading'de küçük fallback'e
  /// düşüp post gelince yorumları aşağı itme/sıçrama OLMAZ. null ise async.
  final FeedPost? initialPost;

  /// Yorum ekranını tam ekran modal route olarak açar.
  static Future<void> show(
    BuildContext context,
    String postId, {
    FeedPost? initialPost,
  }) {
    debugPrint('[FirinNet][Comments] open postId=$postId');
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            SocialCommentsPage(postId: postId, initialPost: initialPost),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(socialCommentsProvider(postId));
    final postAsync = ref.watch(feedPostByIdProvider(postId));
    // Detay açılış pozisyonu fix: ana gönderi İLK FRAME'de tam çizilsin diye
    // önce feed kartından gelen bilinen [initialPost], sonra async refresh.
    final post = postAsync.valueOrNull ?? initialPost;
    final user = ref.watch(currentAuthUserProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leadingWidth: 56,
        leading: IconButton(
          tooltip: AppStrings.socialBackTooltip,
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          // V1 P0 — Twitter post-detail mantığı: AppBar başlığı "Gönderi".
          // Sayfa içinde ayrı "Yorumlar (N)" başlığı var.
          AppStrings.postDetailTitle,
          style: AppTypography.pageTitle,
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderHairline),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: commentsAsync.when(
                // Perf: yorum gönderildiğinde liste eski yorumları korur,
                // spinner flash yok; yeni yorum sessiz reload ile eklenir.
                skipLoadingOnReload: true,
                loading: () => _ScrollableShell(
                  post: post,
                  // Yorumlar yüklenirken: statik yorum satırı iskeleti.
                  child: const SocialListSkeleton(
                    key: ValueKey('comments_skeleton'),
                    count: 3,
                    avatarSize: FirinNetAvatarSize.s,
                  ),
                ),
                error: (e, st) {
                  debugPrint('[FirinNet][Comments] list error: $e');
                  return _ScrollableShell(
                    post: post,
                    // Statik metin yerine gerçek yeniden yükleme: yorum
                    // listesi + post provider'ı yeniden istenir.
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: ErrorRetryState(
                        key: const ValueKey('comments_error_retry'),
                        compact: true,
                        title: AppStrings.feedCommentErrorGeneric,
                        subtitle: null,
                        onRetry: () {
                          ref.invalidate(socialCommentsProvider(postId));
                          ref.invalidate(feedPostByIdProvider(postId));
                        },
                      ),
                    ),
                  );
                },
                data: (items) {
                  debugPrint(
                    '[FirinNet][Comments] list loaded count=${items.length}',
                  );
                  return _PostDetailScroll(
                    post: post,
                    items: items,
                    user: user,
                    postId: postId,
                  );
                },
              ),
            ),
            const Divider(height: 1, color: AppColors.borderHairline),
            _CommentComposer(postId: postId, guest: user == null),
          ],
        ),
      ),
    );
  }
}

/// Loading/error durumunda da post header'ı üstte göster: scroll'a sahip
/// bir gövde + üstte `_PostContextHeader` + altında child (loader/hata).
class _ScrollableShell extends StatelessWidget {
  const _ScrollableShell({required this.post, required this.child});

  final FeedPost? post;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        _PostContextHeader(post: post),
        const _SectionHeading(count: 0),
        child,
      ],
    );
  }
}

/// Veri geldiğinde — Twitter post detail mantığı: üstte post kartı +
/// "Yorumlar (N)" başlığı + altında yorumlar.
class _PostDetailScroll extends ConsumerWidget {
  const _PostDetailScroll({
    required this.post,
    required this.items,
    required this.user,
    required this.postId,
  });

  final FeedPost? post;
  final List<SocialComment> items;
  final dynamic user; // currentAuthUserProvider'ın dönüş tipi (AuthUser?)
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // UGC Safety V1 — engellenen kullanıcıların yorumları placeholder olur.
    final blocked = ref.watch(blockedUserIdsSyncProvider);
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          _PostContextHeader(post: post),
          const _SectionHeading(count: 0),
          _EmptyState(isGuest: user == null),
        ],
      );
    }
    // PR #2 — tek-seviye gruplama: her üst yorumun hemen altında cevapları.
    final ordered = _orderTopLevelThenReplies(items);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: ordered.length + 2,
      itemBuilder: (_, i) {
        if (i == 0) return _PostContextHeader(post: post);
        if (i == 1) return _SectionHeading(count: items.length);
        final c = ordered[i - 2];
        final isOwn = user != null && c.ownerId == user.id;
        return Padding(
          // Cevaplar sola girintili (tek seviye); üst yorumlar normal.
          padding: EdgeInsets.fromLTRB(
            c.isReply ? AppSpacing.l + 36 : AppSpacing.l,
            0,
            AppSpacing.l,
            0,
          ),
          // UGC Safety V1 — engellenen kullanıcının yorumu placeholder olur
          // (konuşma akışı kopmaz, içerik gizlenir).
          child: blocked.contains(c.ownerId)
              ? const _BlockedCommentPlaceholder()
              : _CommentItem(
                  comment: c,
                  isOwn: isOwn,
                  postId: postId,
                  isReply: c.isReply,
                ),
        );
      },
    );
  }

  /// Üst yorumlar zaman sırasıyla; her birinin hemen altında cevapları.
  static List<SocialComment> _orderTopLevelThenReplies(
    List<SocialComment> items,
  ) {
    final repliesByParent = <String, List<SocialComment>>{};
    for (final c in items) {
      if (c.parentCommentId != null) {
        (repliesByParent[c.parentCommentId!] ??= <SocialComment>[]).add(c);
      }
    }
    final ordered = <SocialComment>[];
    for (final c in items) {
      if (c.parentCommentId == null) {
        ordered.add(c);
        final rs = repliesByParent[c.id];
        if (rs != null) ordered.addAll(rs);
      }
    }
    // Parent'ı görünmeyen (teorik) yetim cevaplar kaybolmasın.
    final placed = ordered.map((c) => c.id).toSet();
    for (final c in items) {
      if (!placed.contains(c.id)) ordered.add(c);
    }
    return ordered;
  }
}

/// Yorum listesi üstündeki section başlığı: "Yorumlar (N)".
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Text(
        AppStrings.postCommentsHeading(count),
        style: AppTypography.sectionTitle,
      ),
    );
  }
}

/// Gönderi detayının üst bölümü — feed kartıyla AYNI kimlik: ortak
/// [SocialPostHeader] (avatar · ad · tür/AI rozeti · rol · zaman + ⋮),
/// aynı caption tipografisi (detayda kesilmeden), [FeedPostImage] / video ve
/// aynı aksiyon satırı (beğen/yorum/repost/kaydet/paylaş handler'ları
/// [SocialPostInteractionsMixin]'den gelir).
class _PostContextHeader extends ConsumerStatefulWidget {
  const _PostContextHeader({required this.post});

  final FeedPost? post;

  @override
  ConsumerState<_PostContextHeader> createState() => _PostContextHeaderState();
}

class _PostContextHeaderState extends ConsumerState<_PostContextHeader>
    with SocialPostInteractionsMixin<_PostContextHeader> {
  @override
  FeedPost get post => widget.post!;

  @override
  void onPostDeleted() {
    // Silinen gönderinin detayında kalınmaz.
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post; // yerel: null-check sonrası promote olsun
    if (post == null) {
      // Cache miss / lookup başarısız: sade fallback (yorum yine açılır).
      return Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          AppSpacing.m,
          AppSpacing.pageH,
          AppSpacing.s,
        ),
        padding: const EdgeInsets.all(AppSpacing.m),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          boxShadow: AppShadow.card,
        ),
        child: Text(
          AppStrings.commentsPostFallback,
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      );
    }
    final firstImage = post.firstImage;
    final videoUrl = post.firstVideo?.publicUrl;
    return Container(
      key: const ValueKey('post_detail_header'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.m,
        AppSpacing.pageH,
        AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: AppShadow.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildPostHeader(),
          // Detayda metin kesilmez ("devamını gör" yok).
          SocialPostCaption(text: post.text, expandable: false),
          if (post.tags.isNotEmpty) SocialPostTags(tags: post.tags),
          if (firstImage != null)
            FeedPostImage(
              imageUrl: firstImage.publicUrl,
              width: firstImage.width,
              height: firstImage.height,
              memCacheWidth: 1080,
            ),
          if (firstImage == null && videoUrl != null)
            SocialPostVideo(url: videoUrl),
          buildPostActionRow(
            // Detayda "Yorum" yazma alanını açar (sayfa zaten yorumlar).
            onComment: () =>
                ref.read(_composerFocusRequestProvider.notifier).state++,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isGuest});

  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceLine,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 30,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              isGuest
                  ? AppStrings.feedCommentEmptyGuest
                  : AppStrings.feedCommentEmpty,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// UGC Safety V1 — engellenen kullanıcının yorumu yerine gösterilen
/// placeholder (akış kopmaz; yazar adı ve içerik gizli).
class _BlockedCommentPlaceholder extends StatelessWidget {
  const _BlockedCommentPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.block_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                AppStrings.blockedContentPlaceholder,
                key: const ValueKey('blocked_comment_text'),
                style: AppTypography.meta.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentItem extends ConsumerWidget {
  const _CommentItem({
    required this.comment,
    required this.isOwn,
    required this.postId,
    this.isReply = false,
  });

  final SocialComment comment;
  final bool isOwn;
  final String postId;
  final bool isReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bot = ref
        .watch(academyBotsByIdProvider)
        .valueOrNull?[comment.ownerId];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.m),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.m),
          boxShadow: AppShadow.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FirinNetAvatar(
              key: const ValueKey('comment_author_avatar'),
              name: comment.authorName,
              size: FirinNetAvatarSize.s,
              kind: bot != null && !bot.isHumor
                  ? FirinNetAvatarKind.academy
                  : FirinNetAvatarKind.person,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isOwn
                              ? AppStrings.feedCommentOwnLabel
                              : comment.authorName,
                          style: AppTypography.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${relativeTimeShortTr(comment.createdAt)}',
                        style: AppTypography.caption,
                      ),
                      const Spacer(),
                      if (isOwn)
                        IconButton(
                          key: const ValueKey('comment_delete_button'),
                          tooltip: AppStrings.feedCommentDeleteCta,
                          onPressed: () => _confirmAndDelete(context, ref),
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                        )
                      // UGC Safety V1 — başkasının yorumu: şikayet + engelle.
                      else if (comment.ownerId.isNotEmpty)
                        PopupMenuButton<String>(
                          tooltip: AppStrings.moreActionsTooltip,
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                          onSelected: (v) {
                            if (v == 'report') {
                              showReportSheet(
                                context,
                                ref,
                                targetType: ReportTargetType.comment,
                                targetId: comment.id,
                                reportedUserId: comment.ownerId,
                              );
                            }
                            if (v == 'block') {
                              confirmAndBlockUser(
                                context,
                                ref,
                                userId: comment.ownerId,
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'report',
                              child: Text(AppStrings.safetyActionReport),
                            ),
                            PopupMenuItem(
                              value: 'block',
                              child: Text(
                                AppStrings.safetyActionBlock,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Detay ailesi: gövde metni bodyMedium, ferah satır aralığı.
                  Text(
                    comment.text,
                    key: const ValueKey('comment_text'),
                    style: AppTypography.bodyMedium.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // PR #2 — yoruma beğeni + (üst yoruma) cevap.
                  Row(
                    children: [
                      _CommentLikeButton(comment: comment),
                      if (!isReply) ...[
                        const SizedBox(width: 16),
                        _CommentReplyButton(comment: comment),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showAppConfirmDialog(
      context,
      title: AppStrings.feedCommentDeleteConfirm,
      confirmLabel: AppStrings.feedCommentDeleteCta,
      cancelLabel: AppStrings.feedCommentCancelCta,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !context.mounted) return;
    debugPrint('[FirinNet][Comments] delete tap id=${comment.id}');
    final repo = ref.read(socialCommentsRepositoryProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await repo.deleteComment(comment.id).timeout(const Duration(seconds: 15));
      debugPrint('[FirinNet][Comments] delete success id=${comment.id}');
      // V1 P0 wiring-fix: _notify() stream tick'ine ek olarak manuel
      // invalidate. autoDispose.family bazı senaryolarda watch
      // round-trip'ini geç yakaladığı için garantili refresh.
      ref.invalidate(socialCommentsProvider(postId));
      // Yorum sayısı (post header'daki "N yorum") da refresh.
      ref.invalidate(feedPostByIdProvider(postId));
      messenger?.showSnackBar(
        AppFeedback.build(
          AppStrings.feedCommentDeletedSnack,
          kind: AppFeedbackKind.success,
        ),
      );
    } on GuestActionRequiredException {
      debugPrint('[FirinNet][Comments] delete blocked: guest guard');
      if (context.mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugPrint('[FirinNet][Comments] delete error: $e');
      messenger?.showSnackBar(
        AppFeedback.build(
          AppStrings.feedCommentDeleteFailed,
          kind: AppFeedbackKind.error,
        ),
      );
    }
  }
}

/// Yoruma beğeni — optimistic toggle (ikon + sayı). isLiked/likeCount modelden
/// gelir; tıkta anında çevrilir, repo.toggleCommentLike çağrılır, hata olursa
/// geri alınır. Repo _notify() stream'i otoritatif tazeleyince override temizlenir.
class _CommentLikeButton extends ConsumerStatefulWidget {
  const _CommentLikeButton({required this.comment});
  final SocialComment comment;
  @override
  ConsumerState<_CommentLikeButton> createState() => _CommentLikeButtonState();
}

class _CommentLikeButtonState extends ConsumerState<_CommentLikeButton> {
  bool? _likedOverride;
  int? _countOverride;
  bool _busy = false;

  bool get _liked => _likedOverride ?? widget.comment.isLiked;
  int get _count => _countOverride ?? widget.comment.likeCount;

  @override
  void didUpdateWidget(covariant _CommentLikeButton old) {
    super.didUpdateWidget(old);
    // Model (refresh) güncellenince override'ı bırak → kaynak modeldir.
    if (old.comment.isLiked != widget.comment.isLiked ||
        old.comment.likeCount != widget.comment.likeCount) {
      _likedOverride = null;
      _countOverride = null;
    }
  }

  Future<void> _onTap() async {
    if (_busy) return;
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final prevLiked = _liked;
    final prevCount = _count;
    AppHaptics.toggle();
    setState(() {
      _busy = true;
      _likedOverride = !prevLiked;
      _countOverride = prevLiked
          ? (prevCount > 0 ? prevCount - 1 : 0)
          : prevCount + 1;
    });
    try {
      await ref
          .read(socialCommentsRepositoryProvider)
          .toggleCommentLike(widget.comment.id)
          .timeout(const Duration(seconds: 15));
    } on GuestActionRequiredException {
      if (mounted) {
        setState(() {
          _likedOverride = prevLiked;
          _countOverride = prevCount;
        });
        await showAuthRequiredSheet(context, ref);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _likedOverride = prevLiked;
          _countOverride = prevCount;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liked = _liked;
    // Aktif: mürekkep (limon tonu beyaz zeminde okunmaz) — feed ile aynı.
    final color = liked ? AppColors.brandInk : AppColors.textMuted;
    // Yazısız ikon (feed ile tutarlı): etiket Tooltip/semanticLabel'da; sayı
    // yalnız > 0 ise ikon yanında (0 gizli, görünür "Beğen" metni yok).
    return Tooltip(
      message: AppStrings.feedActionLike,
      child: InkWell(
        onTap: _busy ? null : _onTap,
        borderRadius: BorderRadius.circular(AppRadius.s),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                liked
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_up_alt_outlined,
                size: 16,
                color: color,
                semanticLabel: AppStrings.feedActionLike,
              ),
              if (_count > 0) ...[
                const SizedBox(width: 5),
                Text(
                  '$_count',
                  style: AppTypography.meta.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
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

/// "Cevapla" — composer'ı bu ÜST yoruma cevap moduna alır (tek seviye).
class _CommentReplyButton extends ConsumerWidget {
  const _CommentReplyButton({required this.comment});
  final SocialComment comment;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Yazısız ikon: görünür "Cevapla" metni yok; etiket Tooltip/semanticLabel.
    return Tooltip(
      message: AppStrings.feedActionReply,
      child: InkWell(
        onTap: () {
          ref.read(_replyTargetProvider.notifier).state = (
            id: comment.id,
            author: comment.authorName,
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.s),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.reply_rounded,
            size: 16,
            color: AppColors.textMuted,
            semanticLabel: AppStrings.feedActionReply,
          ),
        ),
      ),
    );
  }
}

class _CommentComposer extends ConsumerStatefulWidget {
  const _CommentComposer({required this.postId, required this.guest});

  final String postId;
  final bool guest;

  @override
  ConsumerState<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<_CommentComposer> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;
  String? _inlineError;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _inlineError = AppStrings.feedCommentEmptyError);
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      debugPrint('[FirinNet][Comments] send blocked: guest guard');
      await showAuthRequiredSheet(context, ref);
      return;
    }
    // Feed Boundary V1 — yorumlarda DAR kural: yalnız küfür/scam/link-spam
    // engellenir; ticari yönlendirme yorumlarda uygulanmaz (bağlam sohbet).
    final boundary = FeedBoundaryClassifier.classifyComment(text);
    if (!boundary.allowed) {
      PremiumTopBannerController.show(
        context,
        message: AppStrings.boundaryCommentBlocked,
        tone: PremiumTopBannerTone.warning,
      );
      return;
    }
    setState(() {
      _sending = true;
      _inlineError = null;
    });
    final repo = ref.read(socialCommentsRepositoryProvider);
    try {
      debugPrint(
        '[FirinNet][Comments] send postId=${widget.postId} '
        'textLen=${text.length}',
      );
      final reply = ref.read(_replyTargetProvider);
      final c = await repo
          .addComment(
            postId: widget.postId,
            text: text,
            parentCommentId: reply?.id,
          )
          .timeout(const Duration(seconds: 30));
      debugPrint(
        '[FirinNet][Comments] sent ok id=${c.id} '
        'parent=${reply?.id ?? "-"}',
      );
      if (!mounted) return;
      // Dar sayaç güncellemesi: paged feed'i yeniden çekmeden kart sayacını
      // anında +1 yap. basis = o an bilinen gerçek sayaç.
      final basis =
          ref
              .read(feedPostByIdProvider(widget.postId))
              .valueOrNull
              ?.commentCount ??
          0;
      ref
          .read(feedCommentCountOverrideProvider.notifier)
          .increment(widget.postId, basis);
      _ctrl.clear();
      _focus.unfocus();
      ref.read(_replyTargetProvider.notifier).state =
          null; // cevap modu kapanır
      AppFeedback.success(
        context,
        reply == null
            ? AppStrings.feedCommentSentSnack
            : AppStrings.feedReplySentSnack,
      );
    } on GuestActionRequiredException {
      debugPrint('[FirinNet][Comments] send guest exception');
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugPrint('[FirinNet][Comments] send error: $e');
      if (mounted) {
        setState(() => _inlineError = _humanizeError(e));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _humanizeError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('failed host') ||
        s.contains('network') ||
        s.contains('timeout')) {
      return AppStrings.feedCommentErrorNetwork;
    }
    return AppStrings.feedCommentErrorSubmit;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.guest) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.m,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: () => showAuthRequiredSheet(context, ref),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text(
              AppStrings.feedCommentGuestCta,
              style: AppTypography.buttonLabel,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.brandInk,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
            ),
          ),
        ),
      );
    }
    final reply = ref.watch(_replyTargetProvider);
    // Detaydaki "Yorum" aksiyonu ya da "Cevapla" → yazma alanına odak.
    ref.listen<int>(_composerFocusRequestProvider, (_, __) {
      _focus.requestFocus();
    });
    ref.listen(_replyTargetProvider, (_, next) {
      if (next != null) _focus.requestFocus();
    });
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reply != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.reply_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${reply.author}${AppStrings.commentReplyingToSuffix}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.meta.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.socialCloseTooltip,
                  onPressed: () =>
                      ref.read(_replyTargetProvider.notifier).state = null,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        if (_inlineError != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.32),
                width: 0.6,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: AppColors.danger,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    _inlineError!,
                    style: AppTypography.body.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.s,
            AppSpacing.m,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    style: AppTypography.bodyLarge.copyWith(height: 1.4),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _onSend(),
                    decoration: InputDecoration(
                      hintText: AppStrings.feedCommentComposerHint,
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                      isDense: false,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        borderSide: const BorderSide(
                          color: AppColors.borderHairline,
                          width: 0.6,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              SizedBox(
                width: 52,
                height: 52,
                child: Tooltip(
                  message: AppStrings.feedCommentSendTooltip,
                  child: Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _sending ? null : _onSend,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.brandInk,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: AppColors.brandInk,
                                size: 22,
                                semanticLabel:
                                    AppStrings.feedCommentSendTooltip,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
