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
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../notifications/widgets/notifications_header_action.dart';
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

    // V1 UX Reset — FAB kaldırıldı (header'daki + butonu yeterli; bottom nav
    // + kart "Aç" butonu üst üste binmesin diye). Header bildirim + grup
    // oluştur aksiyonu hâlâ erişilebilir.
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: allAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _GroupsErrorState(
            message: AppStrings.groupsErrorGeneric,
          ),
          data: (all) {
            final filtered = _applySearch(all);
            final isDefaultView = _query.isEmpty && _category == null;
            // V1 UX Reset — "Tüm gruplar" altında joined grupları gösterme
            // (yukarıda kompakt joined satırı var; tekrar bloğu kaldır).
            // Arama/kategori durumunda full liste — kullanıcı bir şey arıyor.
            final joinedIds = joinedAsync.maybeWhen(
              data: (list) => list.map((g) => g.id).toSet(),
              orElse: () => <String>{},
            );
            final allListItems = isDefaultView
                ? filtered.where((g) => !joinedIds.contains(g.id)).toList()
                : filtered;
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
                    // G.N1 — Gruplar header'da bildirim bell + badge. Owner
                    // grup detayına girmeden pending istekleri fark etsin.
                    const NotificationsHeaderAction(),
                    const SizedBox(width: 8),
                    HeaderActionButton(
                      icon: Icons.add_rounded,
                      tooltip: AppStrings.groupsCreateTooltip,
                      onTap: () => context.push(AppRoutes.groupCreate),
                    ),
                  ],
                ),
                // Görsel kalite — header ile içerik arası çok hafif ayraç.
                const Divider(
                  height: 1,
                  thickness: 0.6,
                  color: AppColors.borderHairline,
                ),
                const SizedBox(height: AppSpacing.s),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    AppSpacing.s,
                    AppSpacing.pageH,
                    AppSpacing.s,
                  ),
                  // Görsel kalite — premium filled input: krem dolgu, ince
                  // hairline border, focus'ta bakır vurgu. İşlev değişmedi.
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: AppStrings.groupsSearchHint,
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.softGold,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.card,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.l,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        borderSide: const BorderSide(
                          color: AppColors.borderHairline,
                          width: 0.8,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        borderSide: const BorderSide(
                          color: AppColors.copper,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                _CategoryRow(
                  selected: _category,
                  onChange: (c) => setState(() => _category = c),
                ),
                if (isDefaultView) ...[
                  joinedAsync.when(
                    loading: () => const _MiniLoading(),
                    error: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.pageH,
                      ),
                      child: Text(
                        AppStrings.groupsErrorGeneric,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    data: (joined) {
                      if (joined.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel(
                            title: AppStrings.groupsSectionJoined,
                            topGap: AppSpacing.l,
                          ),
                          _JoinedRow(joined: joined),
                        ],
                      );
                    },
                  ),
                  if (allListItems.isNotEmpty)
                    const SectionLabel(
                      title: AppStrings.groupsSectionAll,
                    ),
                ],
                if (allListItems.isEmpty)
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
                  for (final g in allListItems)
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
    // Görsel kalite — default ChoiceChip yerine rafine bakır/krem pill.
    // Seçim mantığı (onChange/selected) ve kategori filtre işleyişi aynı.
    return SizedBox(
      height: 40,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        scrollDirection: Axis.horizontal,
        children: [
          _CatChip(
            label: AppStrings.groupsCategoryAll,
            selected: selected == null,
            onTap: () => onChange(null),
          ),
          const SizedBox(width: AppSpacing.s),
          for (final c in all) ...[
            _CatChip(
              label: c.label,
              selected: selected == c,
              onTap: () => onChange(c),
            ),
            const SizedBox(width: AppSpacing.s),
          ],
        ],
      ),
    );
  }
}

/// Rafine kategori pill'i — seçili: bakır dolu + beyaz; pasif: krem + ince
/// hairline + sıcak kahve metin. Yalnız görsel; logic `onTap`'te.
class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: AppDuration.fast,
          curve: Curves.easeOut,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.copper : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? AppColors.copper
                  : AppColors.borderHairline,
              width: 0.8,
            ),
            boxShadow: selected ? AppShadow.subtle : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ),
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
    // V1 UX Reset — joined satırı daha kompakt: yükseklik 290 → 200, kart
    // genişliği 280 → 240. Carousel artık ana akışı ezmiyor.
    return SizedBox(
      height: 200,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        scrollDirection: Axis.horizontal,
        itemCount: joined.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
        itemBuilder: (_, i) => _GroupCardWired(
          group: joined[i],
          width: 240,
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
    // G.N4 — Owner kendi grup kartında "X bekleyen istek" sinyali görür.
    // Owner değilse provider hiç watch edilmez (autoDispose; fazladan
    // network çağrısı yok). Compact varyantta GroupCard kendi pill'i
    // gizler — yine de count'u pass etmek zararsız.
    final user = ref.watch(currentAuthUserProvider);
    final isOwner = user != null && group.ownerId == user.id;
    final pendingCount = isOwner
        ? ref.watch(pendingJoinRequestCountProvider(group.id)).maybeWhen(
              data: (n) => n,
              orElse: () => 0,
            )
        : 0;
    return GroupCard(
      group: group,
      isJoined: joined,
      width: width,
      compact: compact,
      pendingRequestCount: pendingCount,
      onTap: () => context.push('${AppRoutes.groups}/${group.id}'),
      onPrimary: () async {
        if (joined) {
          context.push('${AppRoutes.groups}/${group.id}');
          return;
        }
        // V1 P0 — Private gruplar `joinGroup` yolundan değil
        // `requestJoinGroup` ile katılır. Liste kartı CTA'sı "Katılma
        // isteği gönder" gösterir; handler RPC'yi tetikler. Onay sonrası
        // notification + sonraki listJoined refresh ile member olunur.
        if (group.isPrivate) {
          await runGuardedMutation(
            context,
            ref,
            action: () async {
              final repo = ref.read(socialGroupRepositoryProvider);
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

/// Sosyal Omurga V1 — gruplar listesi hata durumunda gösterilen sade
/// placeholder. Ham exception mesajı kullanıcıya yansıtılmaz.
class _GroupsErrorState extends StatelessWidget {
  const _GroupsErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.softGold,
            size: 32,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

