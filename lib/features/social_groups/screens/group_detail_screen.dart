import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/interactions.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/group_category.dart';
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
          error: (e, _) => Center(child: Text('Hata: $e')),
          data: (g) {
            if (g == null) {
              return const Center(child: Text(AppStrings.groupDetailNotFound));
            }
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
                  child: _PrimaryAction(
                    group: g,
                    isJoined: joined,
                  ),
                ),
                const SectionLabel(
                  title: AppStrings.groupDetailMessagesSection,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageH,
                  ),
                  child: messagesAsync.when(
                    loading: () => const _MiniLoading(),
                    error: (e, _) => Text('Mesaj: $e'),
                    data: (msgs) => _MessagesList(messages: msgs),
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageH,
                  ),
                  child: _Composer(group: g, isJoined: joined),
                ),
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
                  label: AppStrings.groupBadgePrivate,
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

class _PrimaryAction extends ConsumerWidget {
  const _PrimaryAction({required this.group, required this.isJoined});
  final SocialGroup group;
  final bool isJoined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(socialGroupRepositoryProvider);
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
                // V1.3.3 — guarded repo guest exception atar; helper yakalar.
                await runGuardedMutation(
                  context,
                  ref,
                  action: () async {
                    if (isJoined) {
                      await repo.leaveGroup(group.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              AppStrings.groupDetailLeaveSnackSuccess),
                        ),
                      );
                    } else {
                      final r = await repo.joinGroup(group.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(r.message)),
                      );
                    }
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

class _Composer extends ConsumerStatefulWidget {
  const _Composer({required this.group, required this.isJoined});
  final SocialGroup group;
  final bool isJoined;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || !widget.isJoined) return;
    // V1.3.2 — Grup mesajı kullanıcı sahipliği gerektirir.
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final repo = ref.read(socialGroupRepositoryProvider);
    final now = DateTime.now();
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
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isJoined) {
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
