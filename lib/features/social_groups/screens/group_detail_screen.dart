import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/interactions.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../../app/router/app_router.dart';
import '../models/group_category.dart';
import '../models/group_join_request.dart';
import '../models/group_member.dart';
import '../models/group_message.dart';
import '../models/social_group.dart';
import '../providers/social_group_providers.dart';
import '../services/group_join_result.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupByIdProvider(groupId));
    final messagesAsync = ref.watch(groupMessagesProvider(groupId));
    final joined = ref.watch(isJoinedProvider(groupId));

    return PremiumScaffold(
      appBar: AppBar(
        title: groupAsync.maybeWhen(
          data: (g) => Text(g?.name ?? AppStrings.groupDetailFallbackTitle),
          orElse: () => const Text(AppStrings.groupDetailFallbackTitle),
        ),
      ),
      body: SafeArea(
        top: false,
        child: groupAsync.when(
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
            // V1 P1-D — Private + non-member içerik gated; mesajlar gizli.
            final user = ref.watch(currentAuthUserProvider);
            final isOwner = user != null && g.ownerId == user.id;
            final contentVisible = !g.isPrivate || joined || isOwner;
            return ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    AppSpacing.s,
                    AppSpacing.pageH,
                    0,
                  ),
                  child: FadeSlideIn(child: _GroupHero(group: g)),
                ),
                if (g.isFull && !joined)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      AppSpacing.m,
                      AppSpacing.pageH,
                      0,
                    ),
                    child: _FullBanner(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    AppSpacing.l,
                    AppSpacing.pageH,
                    0,
                  ),
                  child: PrimaryActionButton(
                    group: g,
                    isJoined: joined,
                  ),
                ),
                // Sprint 2 — Üyeler giriş satırı. contentVisible kullanıcılar
                // için gösterilir (owner, member, public-non-member).
                if (contentVisible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      AppSpacing.s,
                      AppSpacing.pageH,
                      0,
                    ),
                    child: _MembersEntryRow(
                      group: g,
                      isOwner: isOwner,
                    ),
                  ),
                // Owner için pending istekler bölümü.
                if (isOwner) ...[
                  const SectionLabel(
                    title: AppStrings.groupJoinRequestsTitle,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageH,
                    ),
                    child: PendingRequestsSection(groupId: g.id),
                  ),
                ],
                if (!contentVisible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      AppSpacing.l,
                      AppSpacing.pageH,
                      0,
                    ),
                    child: _PrivateGatedInfo(),
                  )
                else ...[
                  const SectionLabel(
                    title: AppStrings.groupDetailMessagesSection,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageH,
                    ),
                    child: messagesAsync.when(
                      loading: () => const _MiniLoading(),
                      error: (_, __) => const Text(
                        AppStrings.groupMessagesErrorGeneric,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      data: (msgs) => _MessagesList(messages: msgs),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageH,
                    ),
                    child: GroupComposer(
                      group: g,
                      isJoined: joined,
                      isOwner: isOwner,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────── Hero

class _GroupHero extends StatelessWidget {
  const _GroupHero({required this.group});
  final SocialGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroFrom, AppColors.heroTo],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.copper.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: AppShadow.heroGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.copper.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  border: Border.all(
                    color: AppColors.copper.withValues(alpha: 0.32),
                    width: 0.6,
                  ),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: AppColors.softGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  group.category.label,
                  style: const TextStyle(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (group.isPrivate)
                _MiniBadge(
                  // G.N5 — Tek terim: "Katılım onaylı".
                  label: AppStrings.groupApprovalRequiredBadge,
                  color: AppColors.softGold,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            group.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            group.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Row(
            children: [
              _StatItem(
                label: AppStrings.groupDetailMembersLabel,
                value: NumberFormatter.integer(group.currentMemberCount),
              ),
              const SizedBox(width: AppSpacing.l),
              _StatItem(
                label: AppStrings.groupDetailLimitLabel,
                value: group.isUnlimited
                    ? AppStrings.groupBadgeUnlimited
                    : NumberFormatter.integer(group.maxMembers!),
              ),
              const Spacer(),
              if (group.city.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: AppColors.softGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      group.city,
                      style: const TextStyle(
                        color: AppColors.softGold,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (!group.isUnlimited) ...[
            const SizedBox(height: AppSpacing.s),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: group.fillRatio,
                minHeight: 4,
                backgroundColor: AppColors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(
                  group.isFull
                      ? AppColors.danger
                      : group.fillRatio > 0.8
                          ? AppColors.copper
                          : AppColors.softGold,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              const Icon(
                Icons.shield_moon_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${AppStrings.groupDetailOwnerLabel}: ${group.ownerName}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: 0.36),
          width: 0.6,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _FullBanner extends StatelessWidget {
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
        children: [
          const Icon(
            Icons.lock_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.s),
          const Expanded(
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

/// V1.4 P1.20 — Widget regresyon testi tarafından doğrudan pump
/// edilebilmesi için library-public (underscore'suz). Sadece bu dosyada
/// construct ediliyor; UI'a yeni surface eklemiyor.
///
/// V1 P1-D: Private + non-member kullanıcı için "Katılma isteği gönder"
/// akışı. Pending istek varsa label "İstek gönderildi" + disabled.
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
    // Sprint 1 / GB-1 — Owner için "Katıl"/"Ayrıl"/"Katılma isteği gönder"
    // hiçbir koşulda gösterilmez. Owner kendi grubuna zaten bağlı; ayrıca
    // owner gruptan ayrılamaz (leaveGroup silent no-op, GB-8). Cache race
    // (GB-2) ile isJoined=false dönse bile owner branch en başta yakalanır.
    //
    // Sprint 2 — Status card artık tıklanabilir: yönet sheet açar
    // (Üyeler / Gruptan çık / Grubu kapat).
    if (isOwner) {
      return _OwnerStatusCard(
        onTap: () => _openOwnerManageSheet(context, ref, group),
      );
    }
    // Private + non-member: katılma isteği akışı; mevcut request lookup.
    if (group.isPrivate && !isJoined && !isOwner) {
      final requestAsync = ref.watch(myJoinRequestProvider(group.id));
      return requestAsync.when(
        loading: () => const SizedBox(
          width: double.infinity,
          height: 50,
          child: Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
        ),
        error: (_, __) => _RequestButton(
          group: group,
          existing: null,
          repo: repo,
        ),
        data: (existing) => _RequestButton(
          group: group,
          existing: existing,
          repo: repo,
        ),
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
                // Sprint 2 — Non-owner "Ayrıl" artık confirm dialog ile
                // leave_group_safely RPC'ye çevrilir. Owner branch en üstte
                // _OwnerStatusCard'a düşer, buraya gelmez.
                if (isJoined) {
                  await _confirmAndLeaveGroup(
                    context,
                    ref,
                    group,
                    isOwner: false,
                  );
                  return;
                }
                // V1.3.3 — guarded repo guest exception atar; helper yakalar.
                await runGuardedMutation(
                  context,
                  ref,
                  action: () async {
                    final r = await repo.joinGroup(group.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(r.message)),
                    );
                  },
                );
              }
            : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: isJoined ? AppColors.textPrimary : Colors.white,
          disabledBackgroundColor: color,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
            side: isJoined
                ? const BorderSide(
                    color: AppColors.borderHairline,
                    width: 0.6,
                  )
                : BorderSide.none,
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

/// Sprint 1 / GB-1 — Owner kullanıcısı için PrimaryActionButton yerine
/// gösterilen pasif durum kartı. Kurucuya "Katıl"/"Ayrıl" hiç gösterilmesin
/// diye var. Yönetim menüsü Sprint 3'te eklenecek (şu an passive).
class _OwnerStatusCard extends StatelessWidget {
  const _OwnerStatusCard({this.onTap});

  /// Sprint 2 — tıklanırsa yönet sheet açılır. Test/legacy kullanımda
  /// `onTap` null kalabilir (sadece status göstergesi).
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
            const Icon(
              Icons.tune_rounded,
              color: AppColors.copper,
              size: 18,
            ),
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
///
/// State:
/// - existing == null veya status == cancelled → "Katılma isteği gönder"
/// - status == pending → "İstek gönderildi" (disabled)
/// - status == rejected → "Tekrar istek gönder"
/// - status == approved → bu widget normalde gösterilmez (joined olmuş olmalı)
class _RequestButton extends ConsumerWidget {
  const _RequestButton({
    required this.group,
    required this.existing,
    required this.repo,
  });

  final SocialGroup group;
  final GroupJoinRequest? existing;
  final dynamic repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

/// V1 P1-D — Private + non-member için içerik gating mesajı (mesaj listesi
/// yerine).
class _PrivateGatedInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.elevatedCard,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: AppColors.borderHairline,
          width: 0.6,
        ),
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
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// V1 P1-D — Grup owner için pending join requests listesi.
///
/// Library-public (test edilebilirlik için underscore'suz); yalnız
/// group_detail_screen kullanıyor.
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
                child: _PendingRequestRow(
                  request: r,
                  groupId: groupId,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PendingRequestRow extends ConsumerStatefulWidget {
  const _PendingRequestRow({
    required this.request,
    required this.groupId,
  });
  final GroupJoinRequest request;
  final String groupId;

  @override
  ConsumerState<_PendingRequestRow> createState() =>
      _PendingRequestRowState();
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
          content: Text(approve
              ? AppStrings.groupJoinRequestApproved
              : AppStrings.groupJoinRequestRejected),
        ),
      );
      ref.invalidate(pendingJoinRequestsProvider(widget.groupId));
    } on GuestActionRequiredException {
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.groupJoinRequestDecideError),
        ),
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
        color: AppColors.elevatedCard,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
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
                    foregroundColor: Colors.white,
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

// ─────────────────────────────────────── Messages

class _MessagesList extends StatelessWidget {
  const _MessagesList({required this.messages});
  final List<GroupMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: const Row(
          children: [
            Icon(
              Icons.forum_outlined,
              color: AppColors.textMuted,
              size: 18,
            ),
            SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                AppStrings.groupDetailMessagesEmpty,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }
    final dt = DateFormat('d MMM, HH:mm', 'tr_TR');
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < messages.length; i++) ...[
            _MessageRow(message: messages[i], dt: dt),
            if (i != messages.length - 1)
              const Divider(
                height: 0,
                indent: 60,
                endIndent: AppSpacing.l,
                color: AppColors.borderHairline,
              ),
          ],
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.dt});
  final GroupMessage message;
  final DateFormat dt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.m,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
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
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.authorName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (message.isPinned)
                      _PinnedBadge(),
                  ],
                ),
                Text(
                  '${message.authorRole} · ${dt.format(message.createdAt)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message.text,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                if (message.reactionCount > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 13,
                        color: AppColors.copper,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${message.reactionCount}',
                        style: const TextStyle(
                          color: AppColors.copper,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
        AppStrings.groupDetailPinnedBadge,
        style: TextStyle(
          color: AppColors.softGold,
          fontWeight: FontWeight.w800,
          fontSize: 9,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────── Composer

/// V1.4 P1.21 — Widget regresyon testi tarafından doğrudan pump
/// edilebilmesi için library-public (underscore'suz). Sadece bu dosyada
/// construct ediliyor; UI'a yeni surface eklemiyor.
class GroupComposer extends ConsumerStatefulWidget {
  const GroupComposer({
    super.key,
    required this.group,
    required this.isJoined,
    required this.isOwner,
  });
  final SocialGroup group;
  final bool isJoined;

  /// Sprint 1 / GB-3 — Owner kendi grubuna her zaman mesaj yazabilmeli.
  /// isJoined cache race'i (GB-2) owner için sıfıra indirilse bile, composer
  /// burada da owner'ı bağımsız olarak yetkilendirir.
  final bool isOwner;

  @override
  ConsumerState<GroupComposer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<GroupComposer> {
  final _ctrl = TextEditingController();

  /// Sprint 1 / GB-3 — Yazma yetkisi: owner VEYA üye.
  /// isJoined tek başına yeterli değil; owner cache race senaryosunda
  /// false dönse bile composer açık kalır.
  bool get _effectiveCanWrite => widget.isOwner || widget.isJoined;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || !_effectiveCanWrite) return;
    // V1.3.2 — Grup mesajı kullanıcı sahipliği gerektirir.
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final repo = ref.read(socialGroupRepositoryProvider);
    final now = DateTime.now();
    try {
      await repo.postMessage(
        GroupMessage(
          id: 'gm_${now.microsecondsSinceEpoch}',
          groupId: widget.group.id,
          authorName: 'Misafir',
          authorRole: 'Üye',
          text: t,
          createdAt: now,
        ),
      );
      if (!mounted) return;
      _ctrl.clear();
    } on GuestActionRequiredException {
      // Defense-in-depth: pre-check sonrası repo katmanı guest exception
      // atarsa sessizce yutmayalım — auth sheet aç.
      if (!mounted) return;
      await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (!mounted) return;
      // Mesaj input'ta korunur (clear çağrılmaz) ki kullanıcı tek tıkla
      // tekrar deneyebilsin. Ham exception UI'a sızmaz.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.groupMessageSendError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_effectiveCanWrite) {
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
        Expanded(
          child: TextField(
            controller: _ctrl,
            maxLines: 1,
            decoration: const InputDecoration(
              hintText: AppStrings.groupDetailComposeHint,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: 14,
              ),
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        SizedBox(
          height: 56,
          width: 56,
          child: FilledButton(
            onPressed: _send,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.copper,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
            ),
            child: const Icon(Icons.send_rounded),
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
// Sprint 2 — Members entry, manage sheet, members sheet + leave/close flow
// ═════════════════════════════════════════════════════════════════════════

/// "Üyeler · 4" girişi. Tap → üyeler bottom sheet.
class _MembersEntryRow extends ConsumerWidget {
  const _MembersEntryRow({required this.group, required this.isOwner});

  final SocialGroup group;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: () => _openMembersSheet(context, ref, group, isOwner: isOwner),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
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
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Owner status card'a tap → yönet sheet açar.
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

/// Üyeler bottom sheet.
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
                separatorBuilder: (_, __) => const Divider(
                  height: 0,
                  color: AppColors.borderHairline,
                ),
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
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.groupLeaveError)),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.groupDeleteError)),
    );
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
