import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../../../core/widgets/premium/chat_media_picker_sheet.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../messaging/services/chat_media_upload_service.dart';
import '../../messaging/widgets/chat_video_viewer.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/group_join_request.dart';
import '../models/group_member.dart';
import '../models/group_message.dart';
import '../models/social_group.dart';
import '../providers/social_group_providers.dart';
import '../services/group_join_result.dart';

/// V1 UX Reset — WhatsApp benzeri chat-centric grup ekranı.
///
/// Eski yapı (büyük hero kartı, owner status kartı, ana akıştaki Üyeler
/// kartı, pending istekler bölümü) chat alanını aşağıya itiyordu. Bu reset:
///   * AppBar: grup adı + altında küçük "N üye · Katılım onaylı" rozet.
///   * Body: Column(Expanded(messages), composer) — sticky composer.
///   * Yönetim: AppBar PopupMenuButton (Üyeler / Katılım istekleri /
///     Gruptan çık / Grubu kapat) — owner/member rolüne göre filtrelenir.
///   * Pending istekler: sadece owner için, sadece count>0 → kompakt alert
///     mesaj listesinin üstünde. Boş hâl gösterilmez.
///   * Non-member private: gated card; chat görünmez.
///   * Non-member public: chat görünür, composer yerine "Sohbete katıl" CTA.
class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupByIdProvider(groupId));

    return PremiumScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: groupAsync.maybeWhen(
          data: (g) => _AppBarTitle(group: g),
          orElse: () => const Text(AppStrings.groupDetailFallbackTitle),
        ),
        actions: [
          groupAsync.maybeWhen(
            data: (g) => g == null
                ? const SizedBox.shrink()
                : _GroupMenuButton(group: g),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Padding(
          padding: EdgeInsets.all(AppSpacing.l),
          child: Center(
            child: Text(
              AppStrings.groupDetailErrorGeneric,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
        ),
        data: (g) {
          if (g == null) {
            return const Center(child: Text(AppStrings.groupDetailNotFound));
          }
          return _GroupBody(group: g);
        },
      ),
    );
  }
}

class _AppBarTitle extends ConsumerWidget {
  const _AppBarTitle({required this.group});
  final SocialGroup? group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = group;
    if (g == null) {
      return const Text(AppStrings.groupDetailFallbackTitle);
    }
    final subtitle = StringBuffer(
      AppStrings.groupInfoMembers(g.currentMemberCount),
    );
    if (g.isPrivate) {
      subtitle
        ..write(' · ')
        ..write(AppStrings.groupApprovalRequiredBadge);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          g.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: -0.2,
            color: AppColors.textPrimary,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Body — chat-centric layout
// ═════════════════════════════════════════════════════════════════════════

class _GroupBody extends ConsumerWidget {
  const _GroupBody({required this.group});
  final SocialGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAuthUserProvider);
    final isOwner = user != null && group.ownerId == user.id;
    final joined = ref.watch(isJoinedProvider(group.id));
    if (kDebugMode) {
      debugPrint('[FirinNet][Groups] body BUILD group=${group.id} '
          'uid=${user?.id} owner=$isOwner joined=$joined');
    }
    // contentVisible = chat'i göstermeye yetkili miyim?
    // - Public grup: herkes görür.
    // - Private grup: yalnız üye veya owner görür; non-member gated.
    final contentVisible = !group.isPrivate || joined || isOwner;

    if (!contentVisible) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: _PrivateGated(group: group),
        ),
      );
    }

    final messagesAsync = ref.watch(groupMessagesProvider(group.id));
    return SafeArea(
      top: false,
      child: Column(
        children: [
          // G-6/G-7 — Topluluk başlığı: açıklama + üye avatar önizleme.
          // Kompakt; chat ön planda kalır (büyük hero değil).
          _GroupCommunityHeader(group: group),
          // Owner için kompakt pending istek uyarısı — sadece count > 0.
          if (isOwner) _OwnerPendingAlert(group: group),
          if (group.isFull && !joined && !isOwner)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.s,
                AppSpacing.pageH,
                0,
              ),
              child: _FullBanner(),
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const _MiniLoading(),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(AppSpacing.l),
                child: Center(
                  child: Text(
                    AppStrings.groupMessagesErrorGeneric,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              data: (msgs) => _ChatMessageList(messages: msgs),
            ),
          ),
          // Footer: composer (üye/owner) veya "Sohbete katıl" (non-member public).
          _GroupFooter(group: group, isJoined: joined, isOwner: isOwner),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// G-6/G-7 — Topluluk başlığı (compact community header)
// ═════════════════════════════════════════════════════════════════════════

/// Sohbetin üstünde sabit, kompakt topluluk şeridi: grup açıklaması +
/// üye avatar önizlemesi. Gerçek veri kullanır; veri yoksa hiç render
/// edilmez (boş kutu yok, sahte avatar/aktivite yok).
class _GroupCommunityHeader extends ConsumerWidget {
  const _GroupCommunityHeader({required this.group});
  final SocialGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desc = group.description.trim();
    final membersAsync = ref.watch(groupMembersProvider(group.id));
    final members = membersAsync.maybeWhen(
      data: (m) => m,
      orElse: () => const <GroupMemberProfile>[],
    );

    // Gösterilecek anlamlı içerik yoksa şeridi hiç çizme.
    if (desc.isEmpty && members.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.isNotEmpty)
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          if (members.isNotEmpty) ...[
            SizedBox(height: desc.isNotEmpty ? AppSpacing.s : 0),
            Row(
              children: [
                _GroupAvatarStack(members: members),
                const SizedBox(width: AppSpacing.s),
                Text(
                  AppStrings.groupInfoMembers(group.currentMemberCount),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Üst üste binmiş üye avatarları (ilk 5). İçerik gerçek üye snapshot'ından.
class _GroupAvatarStack extends StatelessWidget {
  const _GroupAvatarStack({required this.members});
  final List<GroupMemberProfile> members;

  @override
  Widget build(BuildContext context) {
    const double size = 24;
    const double step = 16;
    final shown = members.take(5).toList(growable: false);
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: step * (shown.length - 1) + size,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: _avatarCircle(shown[i].displayName, size),
            ),
        ],
      ),
    );
  }

  Widget _avatarCircle(String name, double size) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandLemonPale,
        border: Border.all(color: AppColors.surface, width: 1.4),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.brandInk,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// AppBar menu — yönetim aksiyonları tek menüde
// ═════════════════════════════════════════════════════════════════════════

class _GroupMenuButton extends ConsumerWidget {
  const _GroupMenuButton({required this.group});
  final SocialGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAuthUserProvider);
    final isOwner = user != null && group.ownerId == user.id;
    final joined = ref.watch(isJoinedProvider(group.id));
    // Non-member non-owner → menüye giren aksiyon yok.
    if (!isOwner && !joined) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: AppStrings.groupManage,
      onSelected: (key) {
        switch (key) {
          case 'members':
            _openMembersSheet(context, ref, group, isOwner: isOwner);
            break;
          case 'requests':
            _openJoinRequestsSheet(context, ref, group);
            break;
          case 'leave':
            _confirmAndLeaveGroup(context, ref, group, isOwner: isOwner);
            break;
          case 'close':
            _confirmAndCloseGroup(context, ref, group);
            break;
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem<String>(
          value: 'members',
          child: _MenuRow(
            icon: Icons.group_rounded,
            label: AppStrings.groupMembers,
          ),
        ),
        if (isOwner)
          const PopupMenuItem<String>(
            value: 'requests',
            child: _MenuRow(
              icon: Icons.hourglass_top_rounded,
              label: AppStrings.groupJoinRequestsMenu,
            ),
          ),
        const PopupMenuItem<String>(
          value: 'leave',
          child: _MenuRow(
            icon: Icons.logout_rounded,
            label: AppStrings.groupLeave,
          ),
        ),
        if (isOwner)
          const PopupMenuItem<String>(
            value: 'close',
            child: _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: AppStrings.groupDelete,
              danger: true,
            ),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.s),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Owner pending compact alert
// ═════════════════════════════════════════════════════════════════════════

class _OwnerPendingAlert extends ConsumerWidget {
  const _OwnerPendingAlert({required this.group});
  final SocialGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(pendingJoinRequestCountProvider(group.id));
    final count = countAsync.maybeWhen(data: (n) => n, orElse: () => 0);
    if (count <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        0,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.m),
          onTap: () => _openJoinRequestsSheet(context, ref, group),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.copper.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(
                color: AppColors.copper.withValues(alpha: 0.32),
                width: 0.6,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.copper,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    AppStrings.groupJoinRequestsCompact(count),
                    style: const TextStyle(
                      color: AppColors.copper,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.copper,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Chat message list — newest at bottom, scroll-to-bottom
// ═════════════════════════════════════════════════════════════════════════

class _ChatMessageList extends StatelessWidget {
  const _ChatMessageList({required this.messages});
  final List<GroupMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.forum_outlined,
                color: AppColors.textMuted,
                size: 32,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                AppStrings.groupFirstMessage,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                AppStrings.groupDetailMessagesEmpty,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    // Sıralama: createdAt ascending — eski üstte, yeni altta.
    final ordered = List<GroupMessage>.from(messages)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final dt = DateFormat('d MMM, HH:mm', 'tr_TR');
    // reverse:true → liste 0. eleman dipte; ordered[length-1-i] kullanarak
    // newest-at-bottom semantik korunur ve ilk açılışta dip görünür.
    return ListView.builder(
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageH,
        vertical: AppSpacing.s,
      ),
      itemCount: ordered.length,
      itemBuilder: (_, i) {
        final m = ordered[ordered.length - 1 - i];
        return _ChatBubble(message: m, dt: dt);
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.dt});
  final GroupMessage message;
  final DateFormat dt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.softGold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            alignment: Alignment.center,
            child: Text(
              message.authorName.isNotEmpty
                  ? message.authorName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.softGold,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        message.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dt.format(message.createdAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                    if (message.isPinned) ...[
                      const SizedBox(width: 6),
                      const _PinnedBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // Sprint G — resim eki varsa image bubble; caption placeholder
                // değilse altında metin gösterilir. V1.1 — video eki varsa
                // video bubble; bilinmeyen media_type text fallback'e düşer.
                if (message.hasImage && (message.imageUrl ?? '').isNotEmpty)
                  _GroupImageBubble(
                    url: message.imageUrl!,
                    caption: message.text == AppStrings.messagingImageFallback
                        ? null
                        : message.text,
                  )
                else if (message.hasVideo &&
                    (message.videoUrl ?? '').isNotEmpty)
                  _GroupVideoBubble(
                    url: message.videoUrl!,
                    caption: message.text == AppStrings.messagingVideoFallback
                        ? null
                        : message.text,
                  )
                // Medya eki var ama signed URL üretilememiş (geçici yetki/ağ
                // sorunu) → emoji-text yerine açık "Medya yüklenemedi" durumu.
                else if (message.hasImage || message.hasVideo)
                  const _GroupMediaUnavailable()
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(AppRadius.m),
                        topRight: const Radius.circular(AppRadius.m),
                        bottomLeft: const Radius.circular(AppRadius.m),
                        bottomRight: const Radius.circular(AppRadius.s),
                      ),
                      boxShadow: AppShadow.card,
                    ),
                    child: Text(
                      message.text,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sprint G — grup sohbeti resim bubble'ı (cached_network_image + viewer).
class _GroupImageBubble extends StatelessWidget {
  const _GroupImageBubble({required this.url, this.caption});
  final String url;
  final String? caption;

  void _openViewer(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).maybePop(),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.surface,
                    size: 48,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.surface),
                  onPressed: () => Navigator.of(ctx).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _openViewer(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.m),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 280),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 160,
                  width: 220,
                  color: AppColors.surfaceVariant,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 120,
                  width: 220,
                  color: AppColors.surfaceVariant,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_rounded,
                      color: AppColors.textMuted),
                ),
              ),
            ),
          ),
        ),
        if (caption != null && caption!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// V1.1 — medya eki var ama URL çözülememiş (signed URL hatası) fallback'i.
/// Emoji-text yerine açık durum: ikon + "Medya yüklenemedi". Liste yeniden
/// yüklendiğinde (gruba tekrar giriş) enrich yeniden denenir.
class _GroupMediaUnavailable extends StatelessWidget {
  const _GroupMediaUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.broken_image_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
          SizedBox(width: AppSpacing.s),
          Text(
            AppStrings.chatMediaUnavailable,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// V1.1 — grup sohbeti video bubble'ı: koyu yüzey + play overlay + "Video"
/// etiketi (thumbnail P2). Tap → showChatVideoViewer (chewie player dialog).
class _GroupVideoBubble extends StatelessWidget {
  const _GroupVideoBubble({required this.url, this.caption});
  final String url;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => showChatVideoViewer(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.m),
            child: Container(
              width: 240,
              height: 160,
              color: AppColors.imageScrimDark,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.surface,
                      size: 34,
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.videocam_rounded,
                          color: AppColors.surface,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          AppStrings.chatMediaVideoLabel,
                          style: TextStyle(
                            color: AppColors.surface,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (caption != null && caption!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _PinnedBadge extends StatelessWidget {
  const _PinnedBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.copper.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.copper.withValues(alpha: 0.32),
          width: 0.6,
        ),
      ),
      child: const Text(
        AppStrings.groupDetailPinnedBadge,
        style: TextStyle(
          color: AppColors.softGold,
          fontWeight: FontWeight.w800,
          fontSize: 8.5,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Sticky footer — composer / join CTA / private gate
// ═════════════════════════════════════════════════════════════════════════

class _GroupFooter extends StatelessWidget {
  const _GroupFooter({
    required this.group,
    required this.isJoined,
    required this.isOwner,
  });
  final SocialGroup group;
  final bool isJoined;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final canWrite = isOwner || isJoined;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.borderHairline, width: 0.6),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.s,
      ),
      child: canWrite
          ? GroupComposer(group: group, isJoined: isJoined, isOwner: isOwner)
          : _JoinFooterCta(group: group, isJoined: isJoined),
    );
  }
}

class _JoinFooterCta extends ConsumerWidget {
  const _JoinFooterCta({required this.group, required this.isJoined});
  final SocialGroup group;
  final bool isJoined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Non-member non-owner. Public → "Sohbete katıl", Private → request akışı.
    if (group.isPrivate) {
      final requestAsync = ref.watch(myJoinRequestProvider(group.id));
      return requestAsync.when(
        loading: () => const SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
        ),
        error: (_, __) => _RequestButton(group: group, existing: null),
        data: (existing) => _RequestButton(group: group, existing: existing),
      );
    }
    final repo = ref.read(socialGroupRepositoryProvider);
    final enabled = !group.isFull;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: enabled
            ? () async {
                await runGuardedMutation(
                  context,
                  ref,
                  action: () async {
                    final r = await repo.joinGroup(group.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(r.message)));
                  },
                );
              }
            : null,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
        label: Text(
          group.isFull
              ? AppStrings.groupActionFull
              : AppStrings.groupJoinNowCta,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.copper,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.surfaceLine,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Public widgets retained for direct widget tests (Sprint 1 regression)
// ═════════════════════════════════════════════════════════════════════════

/// V1 UX Reset — yeni layout `PrimaryActionButton`'u ana akışta KULLANMIYOR;
/// kurucu için status card AppBar menüsüne taşındı, "Ayrıl"/"Katıl" ise
/// composer/CTA bandına geçti. Widget kendisi geriye dönük yapılan testler
/// için (Sprint 1 GB-1/GB-8 — `groups_sprint1_owner_state_test.dart`)
/// korunur.
///
/// V1.4 P1.20 — Widget regresyon testi tarafından doğrudan pump
/// edilebilmesi için library-public.
class PrimaryActionButton extends ConsumerWidget {
  const PrimaryActionButton({
    super.key,
    required this.group,
    required this.isJoined,
  });
  final SocialGroup group;
  final bool isJoined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(socialGroupRepositoryProvider);
    final user = ref.watch(currentAuthUserProvider);
    final isOwner = user != null && group.ownerId == user.id;
    if (isOwner) {
      return _OwnerStatusCard(
        onTap: () => _openOwnerManageSheet(context, ref, group),
      );
    }
    if (group.isPrivate && !isJoined && !isOwner) {
      final requestAsync = ref.watch(myJoinRequestProvider(group.id));
      return requestAsync.when(
        loading: () => const SizedBox(
          width: double.infinity,
          height: 50,
          child: Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
        ),
        error: (_, __) => _RequestButton(group: group, existing: null),
        data: (existing) => _RequestButton(group: group, existing: existing),
      );
    }
    final String label;
    final IconData icon;
    final Color color;
    final bool enabled;

    if (isJoined) {
      label = AppStrings.groupActionLeave;
      icon = Icons.logout_rounded;
      color = AppColors.surface;
      enabled = true;
    } else if (group.isFull) {
      label = AppStrings.groupActionFull;
      icon = Icons.lock_rounded;
      color = AppColors.surfaceLine;
      enabled = false;
    } else {
      label = AppStrings.groupActionJoin;
      icon = Icons.add_rounded;
      color = AppColors.copper;
      enabled = true;
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: enabled
            ? () async {
                if (isJoined) {
                  await _confirmAndLeaveGroup(
                    context,
                    ref,
                    group,
                    isOwner: false,
                  );
                  return;
                }
                await runGuardedMutation(
                  context,
                  ref,
                  action: () async {
                    final r = await repo.joinGroup(group.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(r.message)));
                  },
                );
              }
            : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: isJoined ? AppColors.textPrimary : AppColors.surface,
          disabledBackgroundColor: color,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
            side: isJoined
                ? const BorderSide(color: AppColors.borderHairline, width: 0.6)
                : BorderSide.none,
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _OwnerStatusCard extends StatelessWidget {
  const _OwnerStatusCard({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.m,
      ),
      decoration: BoxDecoration(
        color: AppColors.copper.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: AppColors.copper.withValues(alpha: 0.32),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_moon_rounded,
            color: AppColors.copper,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.s),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.groupOwnerStatusTitle,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    letterSpacing: -0.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  AppStrings.groupOwnerStatusSubtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.tune_rounded, color: AppColors.copper, size: 18),
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: card,
    );
  }
}

/// V1 P1-D — Private grup için Request-Join button.
class _RequestButton extends ConsumerWidget {
  const _RequestButton({required this.group, required this.existing});

  final SocialGroup group;
  final GroupJoinRequest? existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(socialGroupRepositoryProvider);
    final String label;
    final bool enabled;
    final IconData icon;

    if (existing?.status == GroupJoinRequestStatus.pending) {
      label = AppStrings.groupJoinRequestPending;
      enabled = false;
      icon = Icons.hourglass_top_rounded;
    } else if (existing?.status == GroupJoinRequestStatus.rejected) {
      label = AppStrings.groupJoinRequestResend;
      enabled = true;
      icon = Icons.refresh_rounded;
    } else {
      label = AppStrings.groupJoinRequestSend;
      enabled = true;
      icon = Icons.send_outlined;
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: enabled
            ? () async {
                await runGuardedMutation(
                  context,
                  ref,
                  action: () async {
                    try {
                      await repo.requestJoinGroup(group.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(AppStrings.groupJoinRequestSent),
                        ),
                      );
                      ref.invalidate(myJoinRequestProvider(group.id));
                    } on GuestActionRequiredException {
                      rethrow;
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(AppStrings.groupJoinRequestError),
                        ),
                      );
                    }
                  },
                );
              }
            : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.copper,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _PrivateGated extends StatelessWidget {
  const _PrivateGated({required this.group});
  final SocialGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.l),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.m),
            boxShadow: AppShadow.card,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(
                Icons.lock_outline_rounded,
                color: AppColors.softGold,
                size: 20,
              ),
              SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  AppStrings.groupPrivateInfo,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        // Public bir join "Sohbete katıl" yerine private request CTA aynı
        // footer mantığı ile.
        _JoinFooterCta(group: group, isJoined: false),
      ],
    );
  }
}

class _FullBanner extends StatelessWidget {
  const _FullBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.32),
          width: 0.6,
        ),
      ),
      child: Row(
        children: const [
          Icon(Icons.lock_rounded, color: AppColors.danger, size: 18),
          SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              AppStrings.groupDetailFullBanner,
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Sprint 2 — Pending requests sheet (taşınan: önceden ana akıştaydı)
// ═════════════════════════════════════════════════════════════════════════

void _openJoinRequestsSheet(
  BuildContext context,
  WidgetRef ref,
  SocialGroup group,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
    ),
    builder: (sheetCtx) => SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.m),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(AppSpacing.l),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: AppColors.softGold,
                    size: 18,
                  ),
                  SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      AppStrings.groupJoinRequestsTitle,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                ),
                child: PendingRequestsSection(groupId: group.id),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// V1 P1-D — Grup owner için pending join requests listesi.
class PendingRequestsSection extends ConsumerWidget {
  const PendingRequestsSection({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingJoinRequestsProvider(groupId));
    return async.when(
      loading: () => const _MiniLoading(),
      error: (_, __) => const Text(
        AppStrings.groupJoinRequestDecideError,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
            child: Text(
              AppStrings.groupJoinRequestsEmpty,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final r in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: _PendingRequestRow(request: r, groupId: groupId),
              ),
          ],
        );
      },
    );
  }
}

class _PendingRequestRow extends ConsumerStatefulWidget {
  const _PendingRequestRow({required this.request, required this.groupId});
  final GroupJoinRequest request;
  final String groupId;

  @override
  ConsumerState<_PendingRequestRow> createState() => _PendingRequestRowState();
}

class _PendingRequestRowState extends ConsumerState<_PendingRequestRow> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    final repo = ref.read(socialGroupRepositoryProvider);
    try {
      if (approve) {
        await repo.approveJoinRequest(widget.request.id);
      } else {
        await repo.rejectJoinRequest(widget.request.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? AppStrings.groupJoinRequestApproved
                : AppStrings.groupJoinRequestRejected,
          ),
        ),
      );
      ref.invalidate(pendingJoinRequestsProvider(widget.groupId));
    } on GuestActionRequiredException {
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.groupJoinRequestDecideError)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.softGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                alignment: Alignment.center,
                child: Text(
                  (r.requesterName?.isNotEmpty == true)
                      ? r.requesterName![0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.requesterName ?? '—',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((r.requesterBadge ?? r.requesterCity) != null &&
                        ((r.requesterBadge?.isNotEmpty ?? false) ||
                            (r.requesterCity?.isNotEmpty ?? false)))
                      Text(
                        [
                          if (r.requesterBadge?.isNotEmpty == true)
                            r.requesterBadge!,
                          if (r.requesterCity?.isNotEmpty == true)
                            r.requesterCity!,
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (r.message != null && r.message!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r.message!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _decide(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(
                      color: AppColors.borderHairline,
                      width: 0.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  child: const Text(AppStrings.groupJoinRequestRejectCta),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _decide(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.copper,
                    foregroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  child: const Text(AppStrings.groupJoinRequestApproveCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Composer — sticky, single-line input + send button
// ═════════════════════════════════════════════════════════════════════════

class GroupComposer extends ConsumerStatefulWidget {
  const GroupComposer({
    super.key,
    required this.group,
    required this.isJoined,
    required this.isOwner,
  });
  final SocialGroup group;
  final bool isJoined;
  final bool isOwner;

  @override
  ConsumerState<GroupComposer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<GroupComposer> {
  final _ctrl = TextEditingController();

  // G-8 — Gönderim sırasında buton loading + tekrar tıklamayı engelle
  // (duplicate post riskini düşürür).
  bool _sending = false;

  bool get _effectiveCanWrite => widget.isOwner || widget.isJoined;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || !_effectiveCanWrite || _sending) return;
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final repo = ref.read(socialGroupRepositoryProvider);
    final now = DateTime.now();
    // G-5 — Yazar adı artık kör "Misafir" değil: oturum açmış kullanıcının
    // profil display_name'i. Boşsa güvenli "FırınNet Kullanıcısı" fallback.
    // (Supabase yolunda author_name zaten server-side trigger ile profiles'tan
    // doldurulur; bu değer local/optimistic gösterim sözleşmesini düzeltir.)
    final profile = ref.read(profileControllerProvider);
    final displayName = profile?.displayName.trim() ?? '';
    final authorName =
        displayName.isNotEmpty ? displayName : PublicProfile.fallbackName;
    setState(() => _sending = true);
    try {
      await repo.postMessage(
        GroupMessage(
          id: 'gm_${now.microsecondsSinceEpoch}',
          groupId: widget.group.id,
          authorName: authorName,
          authorRole: widget.isOwner ? AppStrings.groupFounder : 'Üye',
          text: t,
          createdAt: now,
        ),
      );
      if (!mounted) return;
      // Başarı → input temizlenir (mesaj listesi refresh ile gelir).
      _ctrl.clear();
    } on GuestActionRequiredException {
      if (!mounted) return;
      await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (!mounted) return;
      // G-8 — Hata: metin KORUNUR (temizlenmez), üst şerit "Tekrar dene" sunar.
      PremiumTopBannerController.show(
        context,
        message: AppStrings.groupMessageSendError,
        tone: PremiumTopBannerTone.danger,
        actionLabel: AppStrings.messagingRetryCta,
        duration: const Duration(seconds: 6),
        onAction: _send,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Sprint G + V1.1 — medya eki (image/video): ikon → sheet → seç/çek →
  // yükle → postMessage.
  Future<void> _attach() async {
    if (!_effectiveCanWrite || _sending) return;
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final pick = await ChatMediaPickerSheet.show(context);
    if (pick == null || !mounted) return;
    final svc = ref.read(chatMediaUploadServiceProvider);
    if (svc == null) return;
    XFile? file;
    try {
      file = pick.isVideo
          ? await svc.pickVideo(pick.source)
          : await svc.pickImage(pick.source);
    } catch (e) {
      debugLogMediaPick('pick', e);
      if (mounted) {
        PremiumTopBannerController.show(
          context,
          message: AppStrings.chatMediaPermissionDenied,
          tone: PremiumTopBannerTone.warning,
        );
      }
      return;
    }
    if (file == null || !mounted) return;
    await _uploadAndPost(file, kind: pick.kind);
  }

  Future<void> _uploadAndPost(
    XFile file, {
    ChatMediaKind kind = ChatMediaKind.image,
  }) async {
    final isVideo = kind == ChatMediaKind.video;
    final svc = ref.read(chatMediaUploadServiceProvider);
    final repo = ref.read(socialGroupRepositoryProvider);
    if (svc == null) return;
    // Medyaya özel (narrow) auth dayanıklılığı — global guard'a dokunulmaz.
    // Native picker resume'unda stale-null cache'i persist session'dan tazele.
    ref.invalidate(currentAuthUserProvider);
    // Owner path segmenti gerçek uid olmalı (storage RLS auth.uid). Tazelenmiş
    // cache → canlı fallback; local-user-me/'' fallback YOK. İkisi de null ise
    // gerçek oturum yok → guest guard (signOut yok).
    final meId = ref.read(currentAuthUserProvider)?.id ??
        ref.read(authRepositoryProvider)?.currentUser?.id;
    if (meId == null) {
      if (mounted) await showAuthRequiredSheet(context, ref);
      return;
    }
    final profile = ref.read(profileControllerProvider);
    final displayName = profile?.displayName.trim() ?? '';
    final authorName =
        displayName.isNotEmpty ? displayName : PublicProfile.fallbackName;
    setState(() => _sending = true);
    PremiumTopBannerController.show(
      context,
      message: isVideo
          ? AppStrings.chatMediaVideoUploading
          : AppStrings.chatMediaUploading,
      tone: PremiumTopBannerTone.info,
      duration: Duration.zero,
    );
    try {
      final res = await svc.upload(
        scope: 'groups',
        scopeId: widget.group.id,
        ownerId: meId,
        file: file,
        kind: kind,
      );
      await repo.postMessage(
        GroupMessage(
          id: 'gm_${DateTime.now().microsecondsSinceEpoch}',
          groupId: widget.group.id,
          authorName: authorName,
          authorRole: widget.isOwner ? AppStrings.groupFounder : 'Üye',
          text: isVideo
              ? AppStrings.messagingVideoFallback
              : AppStrings.messagingImageFallback,
          createdAt: DateTime.now(),
          attachments: res.toAttachments(),
        ),
      );
      // Liste groupChangesProvider tick ile yenilenir (signed url enrich).
      PremiumTopBannerController.dismiss();
    } on ChatMediaTooLargeException {
      PremiumTopBannerController.dismiss();
      if (mounted) {
        PremiumTopBannerController.show(context,
            message: isVideo
                ? AppStrings.chatMediaVideoTooLarge
                : AppStrings.chatMediaTooLarge,
            tone: PremiumTopBannerTone.warning);
      }
    } on ChatMediaUnsupportedException {
      PremiumTopBannerController.dismiss();
      if (mounted) {
        PremiumTopBannerController.show(context,
            message: isVideo
                ? AppStrings.chatMediaVideoUnsupported
                : AppStrings.chatMediaUnsupported,
            tone: PremiumTopBannerTone.warning);
      }
    } on GuestActionRequiredException {
      PremiumTopBannerController.dismiss();
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugLogMediaPick('upload', e);
      PremiumTopBannerController.dismiss();
      if (mounted) {
        // Retry aynı dosyayla; başarısızlıkta hiç mesaj eklenmedi (kayıp yok).
        PremiumTopBannerController.show(
          context,
          message: isVideo
              ? AppStrings.chatMediaVideoSendError
              : AppStrings.chatMediaSendError,
          tone: PremiumTopBannerTone.danger,
          actionLabel: AppStrings.messagingRetryCta,
          duration: const Duration(seconds: 6),
          onAction: () => _uploadAndPost(file, kind: kind),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_effectiveCanWrite) {
      // Backwards compat — direct widget usage (non-joined non-owner).
      return PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: const Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textMuted,
              size: 16,
            ),
            SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                AppStrings.groupDetailComposeJoinedOnly,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        // Sprint G — medya (resim) ekle.
        IconButton(
          onPressed: _sending ? null : _attach,
          icon: const Icon(Icons.add_photo_alternate_rounded),
          color: AppColors.copper,
          tooltip: AppStrings.chatMediaSheetTitle,
        ),
        Expanded(
          child: TextField(
            controller: _ctrl,
            maxLines: 1,
            textInputAction: TextInputAction.send,
            decoration: const InputDecoration(
              hintText: AppStrings.groupDetailComposeHint,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: 12,
              ),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        SizedBox(
          height: 48,
          width: 48,
          child: FilledButton(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.copper,
              foregroundColor: AppColors.surface,
              disabledBackgroundColor: AppColors.copper.withValues(alpha: 0.6),
              disabledForegroundColor: AppColors.surface,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation(AppColors.surface),
                    ),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ),
      ],
    );
  }
}

class _MiniLoading extends StatelessWidget {
  const _MiniLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 80,
    child: Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 1.6),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// Sprint 2 — Members sheet + leave/close flow (taşınan; sheet'ler içinde)
// ═════════════════════════════════════════════════════════════════════════

void _openOwnerManageSheet(
  BuildContext context,
  WidgetRef ref,
  SocialGroup group,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
    ),
    builder: (sheetCtx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.m),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderHairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          _ManageSheetTile(
            icon: Icons.group_rounded,
            label: AppStrings.groupMembers,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _openMembersSheet(context, ref, group, isOwner: true);
            },
          ),
          _ManageSheetTile(
            icon: Icons.logout_rounded,
            label: AppStrings.groupLeave,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _confirmAndLeaveGroup(context, ref, group, isOwner: true);
            },
          ),
          _ManageSheetTile(
            icon: Icons.delete_outline_rounded,
            label: AppStrings.groupDelete,
            danger: true,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _confirmAndCloseGroup(context, ref, group);
            },
          ),
          const SizedBox(height: AppSpacing.m),
        ],
      ),
    ),
  );
}

class _ManageSheetTile extends StatelessWidget {
  const _ManageSheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
        ),
      ),
      onTap: onTap,
    );
  }
}

void _openMembersSheet(
  BuildContext context,
  WidgetRef ref,
  SocialGroup group, {
  required bool isOwner,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
    ),
    builder: (sheetCtx) => SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.75,
        child: _MembersSheetBody(group: group, isOwnerViewing: isOwner),
      ),
    ),
  );
}

class _MembersSheetBody extends ConsumerWidget {
  const _MembersSheetBody({required this.group, required this.isOwnerViewing});

  final SocialGroup group;
  final bool isOwnerViewing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupMembersProvider(group.id));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.m),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderHairline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Row(
            children: [
              const Icon(
                Icons.group_rounded,
                color: AppColors.softGold,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  '${AppStrings.groupMembers} · ${group.currentMemberCount}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const _MiniLoading(),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(AppSpacing.l),
              child: Center(
                child: Text(
                  AppStrings.groupMembersEmpty,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            data: (members) {
              if (members.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.l),
                  child: Center(
                    child: Text(
                      AppStrings.groupMembersEmpty,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                ),
                itemCount: members.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 0, color: AppColors.borderHairline),
                itemBuilder: (_, i) {
                  final m = members[i];
                  return _MemberRow(
                    member: m,
                    canRemove: isOwnerViewing && !m.isOwner,
                    onRemove: () =>
                        _confirmAndRemoveMember(context, ref, group, m),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.canRemove,
    required this.onRemove,
  });

  final GroupMemberProfile member;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (member.professionBadge?.isNotEmpty ?? false) member.professionBadge!,
      if (member.city?.isNotEmpty ?? false) member.city!,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.softGold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
        alignment: Alignment.center,
        child: Text(
          member.displayName.isNotEmpty
              ? member.displayName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: AppColors.softGold,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              member.displayName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (member.isOwner) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.copper.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: AppColors.copper.withValues(alpha: 0.32),
                  width: 0.6,
                ),
              ),
              child: const Text(
                AppStrings.groupFounder,
                style: TextStyle(
                  color: AppColors.copper,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(
              subtitleParts.join(' · '),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
      trailing: canRemove
          ? IconButton(
              icon: const Icon(
                Icons.person_remove_outlined,
                color: AppColors.danger,
                size: 20,
              ),
              tooltip: AppStrings.groupRemoveMember,
              onPressed: onRemove,
            )
          : null,
    );
  }
}

// ── Confirm helpers ──────────────────────────────────────────────────────

Future<bool> _showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dctx).pop(true),
          style: danger
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<void> _confirmAndLeaveGroup(
  BuildContext context,
  WidgetRef ref,
  SocialGroup group, {
  required bool isOwner,
}) async {
  final body = isOwner
      ? (group.currentMemberCount <= 1
            ? AppStrings.groupLeaveConfirmBodyClose
            : AppStrings.groupLeaveConfirmBodyTransfer)
      : AppStrings.groupLeaveConfirmBodyMember;

  final ok = await _showConfirmDialog(
    context,
    title: AppStrings.groupLeaveConfirmTitle,
    body: body,
    confirmLabel: AppStrings.groupLeave,
  );
  if (!ok || !context.mounted) return;

  final repo = ref.read(socialGroupRepositoryProvider);
  try {
    final outcome = await repo.leaveGroupSafely(group.id);
    if (!context.mounted) return;
    final msg = switch (outcome) {
      GroupLeaveOutcome.transferred => AppStrings.groupLeftTransferred,
      GroupLeaveOutcome.closed => AppStrings.groupLeftClosed,
      GroupLeaveOutcome.left => AppStrings.groupLeft,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    context.go(AppRoutes.groups);
  } on GuestActionRequiredException {
    if (context.mounted) await showAuthRequiredSheet(context, ref);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.groupLeaveError)));
  }
}

Future<void> _confirmAndCloseGroup(
  BuildContext context,
  WidgetRef ref,
  SocialGroup group,
) async {
  final ok = await _showConfirmDialog(
    context,
    title: AppStrings.groupDeleteConfirmTitle,
    body: AppStrings.groupDeleteConfirmBody,
    confirmLabel: AppStrings.groupDeleteCta,
    danger: true,
  );
  if (!ok || !context.mounted) return;

  final repo = ref.read(socialGroupRepositoryProvider);
  try {
    await repo.closeGroup(group.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.groupDeleteSuccess)),
    );
    context.go(AppRoutes.groups);
  } on GuestActionRequiredException {
    if (context.mounted) await showAuthRequiredSheet(context, ref);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.groupDeleteError)));
  }
}

Future<void> _confirmAndRemoveMember(
  BuildContext context,
  WidgetRef ref,
  SocialGroup group,
  GroupMemberProfile member,
) async {
  final ok = await _showConfirmDialog(
    context,
    title: AppStrings.groupMemberRemoveConfirmTitle,
    body: AppStrings.groupMemberRemoveConfirmBody,
    confirmLabel: AppStrings.groupMemberRemoveCta,
    danger: true,
  );
  if (!ok || !context.mounted) return;

  final repo = ref.read(socialGroupRepositoryProvider);
  try {
    await repo.removeMember(group.id, member.userId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.groupMemberRemoveSuccess)),
    );
    ref.invalidate(groupMembersProvider(group.id));
  } on GuestActionRequiredException {
    if (context.mounted) await showAuthRequiredSheet(context, ref);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.groupMemberRemoveError)),
    );
  }
}
