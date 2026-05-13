import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/group_category.dart';
import '../models/social_group.dart';
import '../providers/social_group_providers.dart';
import '../services/group_join_result.dart';
import '../widgets/group_card.dart';

class GroupsListScreen extends ConsumerStatefulWidget {
  const GroupsListScreen({super.key});

  @override
  ConsumerState<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends ConsumerState<GroupsListScreen> {
  String _query = '';
  GroupCategory? _category;

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(groupsListProvider(_category));
    final joinedAsync = ref.watch(joinedGroupsProvider);

    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: allAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Hata: $e')),
          data: (all) {
            final filtered = _applySearch(all);
            return ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                FirinNetHeader(
                  title: AppStrings.groupsTitle,
                  subtitle: 'Sektör konuşmaları, bölgesel ağlar',
                  showLogo: false,
                  actions: [
                    HeaderActionButton(
                      icon: Icons.add_rounded,
                      tooltip: AppStrings.groupsCreateTooltip,
                      onTap: () => context.push(AppRoutes.groupCreate),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    AppSpacing.s,
                    AppSpacing.pageH,
                    AppSpacing.s,
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: AppStrings.groupsSearchHint,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.softGold,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.l,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                _CategoryRow(
                  selected: _category,
                  onChange: (c) => setState(() => _category = c),
                ),
                if (_query.isEmpty && _category == null) ...[
                  const SectionLabel(
                    title: AppStrings.groupsSectionJoined,
                    topGap: AppSpacing.l,
                  ),
                  joinedAsync.when(
                    loading: () => const _MiniLoading(),
                    error: (e, _) => Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
                      child: Text('Hata: $e'),
                    ),
                    data: (joined) => _JoinedRow(joined: joined),
                  ),
                  const SectionLabel(
                    title: AppStrings.groupsSectionAll,
                  ),
                ],
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      AppSpacing.l,
                      AppSpacing.pageH,
                      0,
                    ),
                    child: PremiumCard(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Text(
                        AppStrings.groupsListEmpty,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  for (final g in filtered)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageH,
                        0,
                        AppSpacing.pageH,
                        AppSpacing.s,
                      ),
                      child: _GroupCardWired(group: g),
                    ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.groupCreate),
        backgroundColor: AppColors.copper,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(AppStrings.groupsCreateCta),
      ),
    );
  }

  List<SocialGroup> _applySearch(List<SocialGroup> src) {
    if (_query.isEmpty) return src;
    final q = _query.toLowerCase();
    return src
        .where((g) =>
            g.name.toLowerCase().contains(q) ||
            g.description.toLowerCase().contains(q) ||
            g.category.label.toLowerCase().contains(q) ||
            g.city.toLowerCase().contains(q) ||
            g.tags.any((t) => t.toLowerCase().contains(q)))
        .toList();
  }
}

// ─────────────────────────────────────── Category chip row

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.selected, required this.onChange});
  final GroupCategory? selected;
  final ValueChanged<GroupCategory?> onChange;

  @override
  Widget build(BuildContext context) {
    final all = GroupCategory.values;
    return SizedBox(
      height: 44,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            label: const Text(AppStrings.groupsCategoryAll),
            selected: selected == null,
            onSelected: (_) => onChange(null),
          ),
          const SizedBox(width: 6),
          for (final c in all) ...[
            ChoiceChip(
              label: Text(c.label),
              selected: selected == c,
              onSelected: (_) => onChange(c),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────── Joined row (horizontal)

class _JoinedRow extends ConsumerWidget {
  const _JoinedRow({required this.joined});
  final List<SocialGroup> joined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (joined.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        child: PremiumCard(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Text(
            AppStrings.groupsJoinedEmpty,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return SizedBox(
      height: 290,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        scrollDirection: Axis.horizontal,
        itemCount: joined.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
        itemBuilder: (_, i) => _GroupCardWired(
          group: joined[i],
          width: 280,
          compact: true,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────── Wired card (join/open handlers)

class _GroupCardWired extends ConsumerWidget {
  const _GroupCardWired({
    required this.group,
    this.width,
    this.compact = false,
  });
  final SocialGroup group;
  final double? width;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joined = ref.watch(isJoinedProvider(group.id));
    return GroupCard(
      group: group,
      isJoined: joined,
      width: width,
      compact: compact,
      onTap: () => context.push('${AppRoutes.groups}/${group.id}'),
      onPrimary: () async {
        if (joined) {
          context.push('${AppRoutes.groups}/${group.id}');
          return;
        }
        await runGuardedMutation(
          context,
          ref,
          action: () async {
            final repo = ref.read(socialGroupRepositoryProvider);
            final r = await repo.joinGroup(group.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(r.message)),
            );
            if (r == GroupJoinResult.success) {
              context.push('${AppRoutes.groups}/${group.id}');
            }
          },
        );
      },
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

