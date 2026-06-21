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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
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
import '../providers/social_providers.dart';

/// Cevap hedefi (tek-seviye): bir ÜST yoruma cevap yazılırken composer bunu
/// okuyup `parentCommentId` geçirir. "Cevapla" set eder; gönderim/iptal
/// temizler. autoDispose: sayfa kapanınca sıfırlanır.
final _replyTargetProvider =
    StateProvider.autoDispose<({String id, String author})?>((ref) => null);

class SocialCommentsPage extends ConsumerWidget {
  const SocialCommentsPage({super.key, required this.postId});

  final String postId;

  /// Yorum ekranını tam ekran modal route olarak açar.
  static Future<void> show(BuildContext context, String postId) {
    debugPrint('[FirinNet][Comments] open postId=$postId');
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SocialCommentsPage(postId: postId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(socialCommentsProvider(postId));
    final postAsync = ref.watch(feedPostByIdProvider(postId));
    final user = ref.watch(currentAuthUserProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 26),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          // V1 P0 — Twitter post-detail mantığı: AppBar başlığı "Gönderi".
          // Sayfa içinde ayrı "Yorumlar (N)" başlığı var.
          AppStrings.postDetailTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
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
                  postAsync: postAsync,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, st) {
                  debugPrint('[FirinNet][Comments] list error: $e');
                  return _ScrollableShell(
                    postAsync: postAsync,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Center(
                        child: Text(
                          AppStrings.feedCommentErrorGeneric,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
                data: (items) {
                  debugPrint(
                    '[FirinNet][Comments] list loaded count=${items.length}',
                  );
                  return _PostDetailScroll(
                    postAsync: postAsync,
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
  const _ScrollableShell({required this.postAsync, required this.child});

  final AsyncValue<FeedPost?> postAsync;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        _PostContextHeader(postAsync: postAsync),
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
    required this.postAsync,
    required this.items,
    required this.user,
    required this.postId,
  });

  final AsyncValue<FeedPost?> postAsync;
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
          _PostContextHeader(postAsync: postAsync),
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
        if (i == 0) return _PostContextHeader(postAsync: postAsync);
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
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 15.5,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

/// Twitter post-detail header: üstte post kartı (avatar + author + role ·
/// time + caption 17 px + media + stat line "12 beğeni · 3 yorum").
class _PostContextHeader extends StatelessWidget {
  const _PostContextHeader({required this.postAsync});

  final AsyncValue<FeedPost?> postAsync;

  @override
  Widget build(BuildContext context) {
    final post = postAsync.maybeWhen(data: (p) => p, orElse: () => null);
    if (post == null) {
      // Cache miss / lookup başarısız: sade fallback (yorum yine açılır).
      return Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.s,
        ),
        padding: const EdgeInsets.all(AppSpacing.m),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.m),
          boxShadow: AppShadow.card,
        ),
        child: const Text(
          'Bu gönderiye ait yorumlar.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final imageUrl = post.firstImage?.publicUrl;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        boxShadow: AppShadow.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.s,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.10),
                  ),
                  child: Text(
                    post.author.isNotEmpty ? post.author[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${post.role} · ${_timeAgo(post.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              0,
              AppSpacing.m,
              AppSpacing.s,
            ),
            child: Text(
              post.text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                height: 1.4,
              ),
            ),
          ),
          if (imageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.surface),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.surface,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.s,
              AppSpacing.m,
              AppSpacing.m,
            ),
            child: Text(
              '${post.likeCount} ${AppStrings.postLikesShortLabel}  ·  '
              '${post.commentCount} ${AppStrings.postCommentsShortLabel}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'şimdi';
    if (d.inMinutes < 60) return '${d.inMinutes} dk';
    if (d.inHours < 24) return '${d.inHours} sa';
    if (d.inDays < 2) return 'dün';
    return '${d.inDays} gün';
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
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 30,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              isGuest
                  ? AppStrings.feedCommentEmptyGuest
                  : AppStrings.feedCommentEmpty,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.45,
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
          children: const [
            Icon(Icons.block_rounded, size: 16, color: AppColors.textMuted),
            SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                AppStrings.blockedContentPlaceholder,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
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

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'şimdi';
    if (d.inMinutes < 60) return '${d.inMinutes} dk';
    if (d.inHours < 24) return '${d.inHours} sa';
    if (d.inDays < 2) return 'dün';
    return '${d.inDays} gün';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = (comment.authorName.isNotEmpty)
        ? comment.authorName[0].toUpperCase()
        : '?';
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
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
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
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${_timeAgo(comment.createdAt)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (isOwn)
                        InkWell(
                          onTap: () => _confirmAndDelete(context, ref),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      // UGC Safety V1 — başkasının yorumu: şikayet + engelle.
                      else if (comment.ownerId.isNotEmpty)
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_horiz_rounded,
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
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'report',
                              child: Text(AppStrings.safetyActionReport),
                            ),
                            PopupMenuItem(
                              value: 'block',
                              child: Text(
                                AppStrings.safetyActionBlock,
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.text,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        content: const Text(
          AppStrings.feedCommentDeleteConfirm,
          style: TextStyle(fontSize: 15.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.feedCommentCancelCta),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text(AppStrings.feedCommentDeleteCta),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
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
        const SnackBar(content: Text(AppStrings.feedCommentDeletedSnack)),
      );
    } on GuestActionRequiredException {
      debugPrint('[FirinNet][Comments] delete blocked: guest guard');
      if (context.mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugPrint('[FirinNet][Comments] delete error: $e');
      messenger?.showSnackBar(
        const SnackBar(content: Text(AppStrings.feedCommentDeleteFailed)),
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
    setState(() {
      _busy = true;
      _likedOverride = !prevLiked;
      _countOverride =
          prevLiked ? (prevCount > 0 ? prevCount - 1 : 0) : prevCount + 1;
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
    final color = liked ? AppColors.brandLemonPressed : AppColors.textMuted;
    return InkWell(
      onTap: _busy ? null : _onTap,
      borderRadius: BorderRadius.circular(AppRadius.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked
                  ? Icons.thumb_up_alt_rounded
                  : Icons.thumb_up_alt_outlined,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              _count > 0 ? '$_count' : AppStrings.feedActionLike,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
    return InkWell(
      onTap: () {
        ref.read(_replyTargetProvider.notifier).state =
            (id: comment.id, author: comment.authorName);
      },
      borderRadius: BorderRadius.circular(AppRadius.s),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.reply_rounded, size: 16, color: AppColors.textMuted),
            SizedBox(width: 5),
            Text(
              'Cevapla',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
      debugPrint('[FirinNet][Comments] sent ok id=${c.id} '
          'parent=${reply?.id ?? "-"}');
      if (!mounted) return;
      // Dar sayaç güncellemesi: paged feed'i yeniden çekmeden kart sayacını
      // anında +1 yap. basis = o an bilinen gerçek sayaç.
      final basis =
          ref.read(feedPostByIdProvider(widget.postId)).valueOrNull?.commentCount ??
              0;
      ref
          .read(feedCommentCountOverrideProvider.notifier)
          .increment(widget.postId, basis);
      _ctrl.clear();
      _focus.unfocus();
      ref.read(_replyTargetProvider.notifier).state = null; // cevap modu kapanır
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
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
                const Icon(Icons.reply_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${reply.author} adlı kişiye cevap',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () =>
                      ref.read(_replyTargetProvider.notifier).state = null,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textMuted),
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
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13.5,
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
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _onSend(),
                    decoration: InputDecoration(
                      hintText: AppStrings.feedCommentComposerHint,
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15.5,
                      ),
                      isDense: false,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.borderHairline,
                          width: 0.6,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
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
                                  AppColors.surface,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: AppColors.surface,
                              size: 22,
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
