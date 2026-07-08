// FırınNet V1 Unified Profile M2 — tek public profile sayfası.
//
// V1.2 öncesi: SocialProfilePage donor-first sosyal profil (header +
// statistics + posts). Unified Profile M2 ile aşağıdaki section'lar
// eklendi:
//   * AccountType rozet (Ticari/Bireysel/Toptancı) — publicProfileDetail
//   * Hakkında / İşletme — bakery (commercial)
//   * Mesleki Profil ve Deneyim — worker_profiles + worker_experiences
//   * Açık Reçeteler — recipe_calculations is_public=true (ProfileScreen
//     legacy section taşındı)
//   * Gönderiler — mevcut SocialPostCard listesi korundu
//
// Profession_badge sırası (V1): worker_profiles.profession_badge varsa
// onu kullan; yoksa profiles.profession_badge fallback.
//
// Self görüntülemede header altında "Profili düzenle" CTA görünür;
// non-self'te FollowButton + Mesaj CTA (M1.2 messaging).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/firinnet_taxonomy.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../../academy/models/academy_bot_profile.dart';
import '../../academy/providers/academy_providers.dart';
import '../../worker/models/job_seek_post.dart';
import '../../worker/providers/worker_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../bakery_panel/models/recipe_record.dart';
import '../../bakery_panel/providers/bakery_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../messaging/providers/messaging_providers.dart';
import '../../messaging/repositories/messaging_repository.dart';
import '../../profile/models/public_profile_detail.dart';
import '../../profile/providers/follow_providers.dart';
import '../../profile/providers/public_profile_detail_provider.dart';
import '../../profile/widgets/follow_button.dart';
import '../../profile/widgets/profile_edit_sheet.dart';
import '../../safety/models/report_models.dart';
import '../../safety/providers/safety_providers.dart';
import '../../safety/widgets/block_user_dialog.dart';
import '../../safety/widgets/report_sheet.dart';
import '../post/social_post_card.dart';
import '../providers/social_providers.dart';
import 'widgets/profile_about_section.dart';
import 'widgets/profile_category_tabs.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_statistics.dart';

class SocialProfilePage extends ConsumerStatefulWidget {
  const SocialProfilePage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<SocialProfilePage> createState() => _SocialProfilePageState();
}

class _SocialProfilePageState extends ConsumerState<SocialProfilePage> {
  // Yan yana yatay kategori: 0 Gönderiler, 1 Reçeteler, 2 Mesleki Bilgi.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    final profileAsync = ref.watch(socialProfileProvider(userId));
    final detailAsync = ref.watch(publicProfileDetailProvider(userId));
    // M4 Polish — profile postları paged. Yüksek-post kullanıcıda ilk
    // açılış 20'lik sayfa; "Daha fazla göster" CTA ile loadMore.
    final pagedAsync = ref.watch(userPostsPagedNotifierProvider(userId));
    final countsAsync = ref.watch(followCountsProvider(userId));
    final postCountAsync = ref.watch(socialProfilePostCountProvider(userId));
    final recipesAsync = ref.watch(publicRecipesByOwnerProvider(userId));
    final me = ref.watch(currentAuthUserProvider);
    final isSelf = me != null && me.id == userId;
    // FırınNet Akademi bot profili mi (public academy_bot_profiles). Bot ise
    // kullanıcı CTA'ları (takip/mesaj) gizlenir, account rozeti yerine AI
    // notu + bio/topic gösterilir. Geçmiş postlar mevcut owner_id akışıyla.
    final bot = ref.watch(academyBotProfileProvider(userId)).asData?.value;
    final isBot = bot != null;
    // Professional Profile Center Sprint 1 — aktif "iş arıyorum" ilanı
    // (varsa) profil vitrininde durum + kart için.
    final jobSeekAsync = ref.watch(activeJobSeekOfProvider(userId));

    return PremiumScaffold(
      appBar: AppBar(
        title: profileAsync.maybeWhen(
          data: (p) => Text(p.displayNameOrFallback),
          orElse: () => const Text(AppStrings.publicProfileTitle),
        ),
        actions: [
          if (isSelf)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: AppStrings.settingsTooltip,
              onPressed: () => context.push(AppRoutes.settings),
            )
          // UGC Safety V1 — ziyaretçi: profili şikayet et + engelle/kaldır.
          else
            Consumer(
              builder: (context, ref, _) {
                final blocked = ref.watch(blockedUserIdsSyncProvider);
                final isBlocked = blocked.contains(userId);
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (v) {
                    if (v == 'report') {
                      showReportSheet(
                        context,
                        ref,
                        targetType: ReportTargetType.profile,
                        targetId: userId,
                        reportedUserId: userId,
                      );
                    }
                    if (v == 'block') {
                      confirmAndBlockUser(context, ref, userId: userId);
                    }
                    if (v == 'unblock') {
                      unblockUser(context, ref, userId: userId);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'report',
                      child: Text(AppStrings.safetyActionReport),
                    ),
                    if (isBlocked)
                      const PopupMenuItem(
                        value: 'unblock',
                        child: Text(AppStrings.safetyActionUnblock),
                      )
                    else
                      const PopupMenuItem(
                        value: 'block',
                        child: Text(
                          AppStrings.safetyActionBlock,
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(socialProfileProvider(userId));
            ref.invalidate(publicProfileDetailProvider(userId));
            ref.invalidate(userPostsProvider(userId));
            ref.invalidate(userPostsPagedNotifierProvider(userId));
            ref.invalidate(followCountsProvider(userId));
            ref.invalidate(socialProfilePostCountProvider(userId));
            ref.invalidate(publicRecipesByOwnerProvider(userId));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              // ── ÜST PROFİL ALANI (vitrin) ──
              // Header (avatar + name + effective profession_badge + city + bio).
              ProfileHeader(
                profileAsync: profileAsync,
                detailAsync: detailAsync,
                isSelf: isSelf,
              ),
              // Bot: yanıltıcı account rozeti (Bireysel) gizli.
              if (!isBot) _AccountTypeBadge(detailAsync: detailAsync),
              if (!isBot)
                _StatusChip(
                  detailAsync: detailAsync,
                  jobSeekAsync: jobSeekAsync,
                ),
              if (isBot) _BotInfoSection(bot: bot),
              const SizedBox(height: AppSpacing.s),
              ProfileStatistics(
                userId: userId,
                postCountAsync: postCountAsync,
                countsAsync: countsAsync,
                onTapFollowers: () => context.push(
                  '${AppRoutes.userPublicProfile}/$userId/followers',
                ),
                onTapFollowing: () => context.push(
                  '${AppRoutes.userPublicProfile}/$userId/following',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  AppSpacing.m,
                  AppSpacing.pageH,
                  0,
                ),
                child: isSelf
                    ? _SelfEditCta(onTap: () => ProfileEditSheet.show(context))
                    // Bot: takip/mesaj gibi kullanıcı aksiyonları yok.
                    : isBot
                    ? const _BotProfileNote()
                    : Row(
                        children: [
                          Expanded(child: FollowButton(userId: userId)),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: _ProfileMessageCta(
                              onTap: () =>
                                  _openProfileChat(context, ref, userId),
                            ),
                          ),
                        ],
                      ),
              ),

              // ── HAKKIMDA ──
              // Bio header'dan ayrıldı; şehir/meslek header'da kalır, burada
              // tekrarlanmaz. Boş + başkası → gizli; boş + self → hafif CTA.
              ProfileAboutSection(
                bio: detailAsync.asData?.value?.worker?.bio,
                isSelf: isSelf,
                onAddBio: () => context.push(AppRoutes.professionalCv),
              ),

              // ── YAN YANA YATAY KATEGORİLER ──
              // Gönderiler | Reçeteler | Mesleki Bilgi (tek satır, alt alta DEĞİL).
              ProfileCategoryTabs(
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),

              // ── SEÇİLİ TAB İÇERİĞİ ──
              ..._tabContent(
                context: context,
                userId: userId,
                isSelf: isSelf,
                detailAsync: detailAsync,
                jobSeekAsync: jobSeekAsync,
                recipesAsync: recipesAsync,
                pagedAsync: pagedAsync,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Seçili kategorinin içeriği (tek ListView içinde; pagination korunur).
  List<Widget> _tabContent({
    required BuildContext context,
    required String userId,
    required bool isSelf,
    required AsyncValue<PublicProfileDetail?> detailAsync,
    required AsyncValue<JobSeekPost?> jobSeekAsync,
    required AsyncValue<List<Recipe>> recipesAsync,
    required AsyncValue<FeedPagedState> pagedAsync,
  }) {
    switch (_tab) {
      case 1:
        return [
          _PublicRecipesSection(
            async: recipesAsync,
            isSelf: isSelf,
            full: true,
          ),
        ];
      case 2:
        // Visitor + hiç public mesleki içerik yok → sade empty state.
        if (!isSelf) {
          final d = detailAsync.asData?.value;
          final hasAny =
              (d != null &&
                  (d.hasWorkerInfo || d.hasExperiences || d.hasBakery)) ||
              jobSeekAsync.asData?.value != null;
          if (!hasAny) {
            return const [
              EmptyState(
                compact: true,
                icon: Icons.badge_outlined,
                title: AppStrings.profileCvVisitorEmpty,
              ),
            ];
          }
        }
        return [
          _AboutBakerySection(detailAsync: detailAsync, isSelf: isSelf),
          _CvHeader(
            detailAsync: detailAsync,
            jobSeekAsync: jobSeekAsync,
            isSelf: isSelf,
            onEdit: () => context.push(AppRoutes.professionalCv),
          ),
          _ProfessionalSection(
            detailAsync: detailAsync,
            isSelf: isSelf,
            onEdit: () => context.push(AppRoutes.professionalCv),
          ),
          _ExperienceSection(
            detailAsync: detailAsync,
            isSelf: isSelf,
            onAdd: () => context.push(AppRoutes.professionalCv),
          ),
          _JobSeekCard(
            jobSeekAsync: jobSeekAsync,
            isSelf: isSelf,
            onView: () => context.push(AppRoutes.jobs),
            onManage: () => context.push(AppRoutes.professionalCv),
          ),
        ];
      case 0:
      default:
        return [_postsTab(userId, pagedAsync)];
    }
  }

  Widget _postsTab(String userId, AsyncValue<FeedPagedState> pagedAsync) {
    return pagedAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(AppSpacing.l),
        child: Center(
          child: Text(
            AppStrings.publicProfileLoadError,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ),
      data: (paged) {
        if (paged.posts.isEmpty) {
          return const EmptyState(
            compact: true,
            icon: Icons.article_outlined,
            title: AppStrings.publicProfilePostsEmpty,
          );
        }
        return Column(
          children: [
            for (final p in paged.posts)
              SocialPostCard(key: ValueKey(p.feedEntryKey), post: p),
            if (paged.hasMore)
              _LoadMoreCta(
                isLoading: paged.isLoadingMore,
                onTap: () => ref
                    .read(userPostsPagedNotifierProvider(userId).notifier)
                    .loadMore(),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openProfileChat(
    BuildContext context,
    WidgetRef ref,
    String otherUserId,
  ) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    // UGC Safety V1 — engellediğin kullanıcıya mesaj başlatamazsın.
    if (ref.read(blockedUserIdsSyncProvider).contains(otherUserId)) {
      PremiumTopBannerController.show(
        context,
        message: AppStrings.blockedMessageStartBanner,
        tone: PremiumTopBannerTone.warning,
      );
      return;
    }
    try {
      final convId = await ref
          .read(messagingRepositoryProvider)
          .findOrCreateDirectConversation(
            otherUserId: otherUserId,
            contextType: 'profile_direct',
          );
      if (!context.mounted) return;
      context.push('/messages/$convId');
    } on GuestActionRequiredException {
      if (context.mounted) await showAuthRequiredSheet(context, ref);
    } on BlockedConversationException {
      if (context.mounted) {
        PremiumTopBannerController.show(
          context,
          message: AppStrings.blockedMessageStartBanner,
          tone: PremiumTopBannerTone.warning,
        );
      }
    } catch (e) {
      debugPrint('[FirinNet][Profile] open chat error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.messagingStartError)),
        );
      }
    }
  }
}

// ── CTA widgets ───────────────────────────────────────────────────

class _SelfEditCta extends StatelessWidget {
  const _SelfEditCta({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text(
          AppStrings.profileEditCta,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderHairline, width: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
        ),
      ),
    );
  }
}

class _ProfileMessageCta extends StatelessWidget {
  const _ProfileMessageCta({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
        label: const Text(
          AppStrings.messagingMessageCtaProfile,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderHairline, width: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
        ),
      ),
    );
  }
}

class _AccountTypeBadge extends StatelessWidget {
  const _AccountTypeBadge({required this.detailAsync});
  final AsyncValue<PublicProfileDetail?> detailAsync;
  @override
  Widget build(BuildContext context) {
    return detailAsync.maybeWhen(
      data: (d) {
        final code = d?.header.accountType;
        if (code == null || code.isEmpty) return const SizedBox.shrink();
        final label = AppStrings.profileAccountTypeLabels[code] ?? code;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.softGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: AppColors.softGold.withValues(alpha: 0.36),
                  width: 0.6,
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.softGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ── FırınNet Akademi bot profili ──────────────────────────────────

/// Bot profilinde takip/mesaj yerine sade AI içerik notu.
class _BotProfileNote extends StatelessWidget {
  const _BotProfileNote();
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('profile_bot_note'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.softGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: AppColors.softGold.withValues(alpha: 0.34),
          width: 0.7,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 16, color: AppColors.softGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.academyBotProfileNote,
              style: const TextStyle(
                color: AppColors.softGold,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bot profilinde konu etiketi + bio (academy_bot_profiles).
class _BotInfoSection extends StatelessWidget {
  const _BotInfoSection({required this.bot});
  final AcademyBotProfile bot;
  @override
  Widget build(BuildContext context) {
    final hasBio = bot.bio.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.xs,
        AppSpacing.pageH,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const ValueKey('profile_bot_topic'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.copper.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: AppColors.copper.withValues(alpha: 0.34),
                  width: 0.6,
                ),
              ),
              child: Text(
                bot.topic.label,
                style: const TextStyle(
                  color: AppColors.copper,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
          if (hasBio) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              bot.bio,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────

// ── Mesleki CV çatı başlığı ───────────────────────────────────────

class _CvHeader extends StatelessWidget {
  const _CvHeader({
    required this.detailAsync,
    required this.jobSeekAsync,
    required this.isSelf,
    required this.onEdit,
  });
  final AsyncValue<PublicProfileDetail?> detailAsync;
  final AsyncValue<JobSeekPost?> jobSeekAsync;
  final bool isSelf;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final d = detailAsync.asData?.value;
    final hasContent =
        (d != null && (d.hasWorkerInfo || d.hasExperiences)) ||
        (jobSeekAsync.asData?.value != null);
    // Başkası bakıyor + hiç CV içeriği yok → çatı başlığını gizle.
    if (!isSelf && !hasContent) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          // Visitor: sade okunur başlık "Mesleki Bilgi"; self: yönetim "Mesleki CV".
          label: isSelf ? AppStrings.profileSectionCv : AppStrings.profileTabCv,
          trailing: isSelf
              ? TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text(
                    AppStrings.profileCvEditCta,
                    style: TextStyle(
                      color: AppColors.softGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.softGold,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              : null,
        ),
        // Owner'a hitap eden açıklama yalnız self'te — visitor'da gösterilmez.
        if (isSelf)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              0,
              AppSpacing.pageH,
              0,
            ),
            child: Text(
              AppStrings.profileCvSectionSubtitle,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        if (isSelf && !hasContent)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.s,
              AppSpacing.pageH,
              0,
            ),
            child: Text(
              AppStrings.profileCvEmptySelf,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

// ── Son mesleki durum (türetilmiş) ────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.detailAsync, required this.jobSeekAsync});
  final AsyncValue<PublicProfileDetail?> detailAsync;
  final AsyncValue<JobSeekPost?> jobSeekAsync;

  /// Dedicated `current_status` alanı yok — mevcut veriden türetilir:
  /// aktif iş arama → "İş arıyor"; ticari → "Fırın işletmesi"; toptancı →
  /// "Toptancı"; worker profili dolu → "Çalışıyor". Yoksa gizli.
  String? _status() {
    if (jobSeekAsync.asData?.value != null) {
      return AppStrings.profileStatusSeeking;
    }
    final d = detailAsync.asData?.value;
    final acct = d?.header.accountType;
    if (acct == 'commercial') return AppStrings.profileStatusBakery;
    if (acct == 'wholesaler') return AppStrings.profileStatusWholesaler;
    if (d != null && d.hasWorkerInfo) return AppStrings.profileStatusWorking;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status();
    if (status == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.xs,
        AppSpacing.pageH,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          key: const ValueKey('profile_status_chip'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.copper.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: AppColors.copper.withValues(alpha: 0.34),
              width: 0.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.circle, size: 8, color: AppColors.copper),
              const SizedBox(width: 6),
              Text(
                status,
                style: const TextStyle(
                  color: AppColors.copper,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Çalışma Geçmişi ───────────────────────────────────────────────

class _ExperienceSection extends StatelessWidget {
  const _ExperienceSection({
    required this.detailAsync,
    required this.isSelf,
    required this.onAdd,
  });
  final AsyncValue<PublicProfileDetail?> detailAsync;
  final bool isSelf;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return detailAsync.maybeWhen(
      data: (d) {
        if (d == null) return const SizedBox.shrink();
        final items = d.experiences;
        final hasContent = items.isNotEmpty;
        // Başkası bakıyor + boş → bölümü gizle.
        if (!hasContent && !isSelf) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              label: AppStrings.profileSectionExperience,
              trailing: isSelf
                  ? TextButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text(
                        AppStrings.profileExperienceAddCta,
                        style: TextStyle(
                          color: AppColors.softGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.softGold,
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  : null,
            ),
            if (!hasContent)
              const _SectionEmptyHint(
                message: AppStrings.profileEmptyExperience,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                  vertical: AppSpacing.s,
                ),
                child: Column(
                  // _ExperienceRow PremiumCard'ı (width:infinity yok) tam
                  // genişlikte kalsın diye satırları stretch'le.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s),
                        child: _ExperienceRow(exp: e),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ExperienceRow extends StatelessWidget {
  const _ExperienceRow({required this.exp});
  final PublicWorkerExperience exp;

  String _dateRange() {
    final s = exp.startDate?.year.toString();
    final e = exp.isCurrent
        ? AppStrings.profileExperienceCurrent
        : exp.endDate?.year.toString();
    return <String>[if (s != null) s, if (e != null) e].join(' – ');
  }

  @override
  Widget build(BuildContext context) {
    final city = exp.effectiveCity;
    final range = _dateRange();
    final meta = <String>[
      if (city != null && city.isNotEmpty) city,
      if (range.isNotEmpty) range,
    ].join(' · ');
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exp.title, style: AppTypography.cardTitle),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              meta,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if ((exp.description ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              exp.description!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── İş Arıyor kartı ───────────────────────────────────────────────

class _JobSeekCard extends StatelessWidget {
  const _JobSeekCard({
    required this.jobSeekAsync,
    required this.isSelf,
    required this.onView,
    required this.onManage,
  });
  final AsyncValue<JobSeekPost?> jobSeekAsync;
  final bool isSelf;
  final VoidCallback onView;
  final VoidCallback onManage;

  static String? _professionLabel(JobSeekPost p) {
    final code = p.professionBadgeCode;
    if (code != null && code.isNotEmpty) {
      final lbl = FirinnetTaxonomy.professionLabel(code);
      if (lbl != null) return lbl;
    }
    return p.professionBadge;
  }

  static String? _cityLabel(JobSeekPost p) {
    final code = p.cityCode;
    if (code != null && code.isNotEmpty) {
      final prov = TurkeyLocations.findProvinceByCode(code);
      if (prov != null) return prov.name;
    }
    return p.city;
  }

  /// Görsel temizlik — kullanıcı metninin ilk harfini büyüt (örn.
  /// "manisa civarı" → "Manisa civarı"). Geri kalanı olduğu gibi bırakır.
  static String _capitalizeFirst(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final post = jobSeekAsync.asData?.value;
    if (post == null) {
      // Aktif ilan yok. Self'te yine de iş arama durumunu yönetme girişi
      // sun (panel sadeleşmesi sonrası tek giriş profil vitrini).
      if (!isSelf) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          AppSpacing.s,
          AppSpacing.pageH,
          0,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('profile_job_seek_manage_cta'),
            onPressed: onManage,
            icon: const Icon(Icons.campaign_outlined, size: 16),
            label: const Text(
              AppStrings.profileJobSeekManageCta,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.softGold,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      );
    }
    final prof = _professionLabel(post);
    final city = _cityLabel(post);
    final meta = <String>[
      if (prof != null && prof.isNotEmpty) prof,
      if (city != null && city.isNotEmpty) city,
      if (post.experienceYears != null)
        '${post.experienceYears} ${AppStrings.profileExperienceYearsLabel}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageH,
        vertical: AppSpacing.s,
      ),
      child: Container(
        key: const ValueKey('profile_job_seek_card'),
        padding: const EdgeInsets.all(AppSpacing.m),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.l),
          // Aktif ilan vurgusu — softGold accent border korunur; üzerine
          // sakin kart gölgesi ile premium yükseliş.
          border: Border.all(
            color: AppColors.softGold.withValues(alpha: 0.4),
            width: 0.8,
          ),
          boxShadow: AppShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.campaign_outlined,
                  size: 16,
                  color: AppColors.softGold,
                ),
                const SizedBox(width: 6),
                Text(
                  AppStrings.profileJobSeekTitle,
                  style: const TextStyle(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _capitalizeFirst(post.title),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                meta,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if ((post.description ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                post.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isSelf ? onManage : onView,
                icon: Icon(
                  isSelf ? Icons.campaign_outlined : Icons.open_in_new_rounded,
                  size: 16,
                ),
                label: Text(
                  isSelf
                      ? AppStrings.profileJobSeekManageCta
                      : AppStrings.profileJobSeekViewCta,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.softGold,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.trailing});
  final String label;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.l,
        AppSpacing.pageH,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.sectionTitle)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Hakkında / İşletme ────────────────────────────────────────────

class _AboutBakerySection extends StatelessWidget {
  const _AboutBakerySection({required this.detailAsync, required this.isSelf});
  final AsyncValue<PublicProfileDetail?> detailAsync;
  final bool isSelf;
  @override
  Widget build(BuildContext context) {
    return detailAsync.maybeWhen(
      data: (d) {
        if (d == null) return const SizedBox.shrink();
        final bakery = d.bakery;
        final hasContent = bakery != null && !bakery.isEmpty;
        if (!hasContent && !isSelf) {
          // Başkası bakıyor ve boş ise gizle.
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(label: AppStrings.profileSectionBakery),
            if (!hasContent)
              const _SectionEmptyHint(message: AppStrings.profileEmptyBakery)
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                  vertical: AppSpacing.s,
                ),
                child: PremiumCard(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bakery.name, style: AppTypography.sectionTitle),
                      if ((bakery.city ?? '').isNotEmpty ||
                          (bakery.district ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                [
                                  if ((bakery.city ?? '').isNotEmpty)
                                    bakery.city,
                                  if ((bakery.district ?? '').isNotEmpty)
                                    bakery.district,
                                ].whereType<String>().join(' · '),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if ((bakery.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s),
                        Text(
                          bakery.description!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ── Mesleki Profil ve Deneyim ──────────────────────────────────────

class _ProfessionalSection extends StatelessWidget {
  const _ProfessionalSection({
    required this.detailAsync,
    required this.isSelf,
    required this.onEdit,
  });
  final AsyncValue<PublicProfileDetail?> detailAsync;
  final bool isSelf;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    return detailAsync.maybeWhen(
      data: (d) {
        if (d == null) return const SizedBox.shrink();
        final w = d.worker;
        final hasContent = d.hasWorkerInfo;
        if (!hasContent && !isSelf) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              label: AppStrings.profileSectionProfessional,
              trailing: isSelf
                  ? TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text(
                        'Düzenle',
                        style: TextStyle(
                          color: AppColors.softGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.softGold,
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  : null,
            ),
            if (!hasContent)
              const _SectionEmptyHint(
                message: AppStrings.profileEmptyProfessional,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                  vertical: AppSpacing.s,
                ),
                child: PremiumCard(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bio artık ayrı "Hakkımda" bölümünde (ProfileAboutSection)
                      // — burada tekrarlanmaz.
                      // Uzmanlık özeti — tek alan: yıl + skills + cities + shift.
                      // Profile Social Sprint: ayrı "Deneyimler" timeline'ı
                      // kaldırıldı; tek sade card profili Twitter/Facebook
                      // hissinde tutar.
                      if (w != null) _WorkerSnapshot(worker: w),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _WorkerSnapshot extends StatelessWidget {
  const _WorkerSnapshot({required this.worker});
  final PublicWorkerInfo worker;
  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (worker.experienceYears != null) {
      chips.add(
        _MiniChip(
          label:
              '${worker.experienceYears} ${AppStrings.profileExperienceYearsLabel}',
        ),
      );
    }
    if ((worker.shiftPreference ?? '').isNotEmpty) {
      chips.add(_MiniChip(label: worker.shiftPreference!));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: chips),
        if (worker.effectiveSkills.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s),
          Text(
            AppStrings.profileWorkerSkillsLabel,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // M7 — code → label (effectiveSkills); yoksa eski text.
              for (final s in worker.effectiveSkills) _MiniChip(label: s),
            ],
          ),
        ],
        if (worker.effectiveCities.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s),
          Text(
            AppStrings.profileWorkerCitiesLabel,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // M6A — code → label çevirim (effectiveCities); yoksa eski text.
              for (final c in worker.effectiveCities) _MiniChip(label: c),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Açık Reçeteler ────────────────────────────────────────────────

/// Profile Social Sprint — public reçeteler küçük preview (max 4).
/// Feed'in görsel ağırlığını ezmemek için kısa liste, tap → RecipeDetail.
/// 4'ten fazla varsa alta küçük "+N daha" pasif satırı.
class _PublicRecipesSection extends StatelessWidget {
  const _PublicRecipesSection({
    required this.async,
    required this.isSelf,
    this.full = false,
  });
  final AsyncValue<List<Recipe>> async;
  final bool isSelf;

  /// Reçeteler tab'ında tam liste; vitrin preview'inde ilk 4.
  final bool full;

  static const int _previewLimit = 4;

  @override
  Widget build(BuildContext context) {
    return async.maybeWhen(
      data: (list) {
        if (list.isEmpty && !isSelf) return const SizedBox.shrink();
        final preview = full
            ? list
            : list.take(_previewLimit).toList(growable: false);
        final overflow = full ? 0 : list.length - preview.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(label: AppStrings.profileSectionPublicRecipes),
            if (list.isEmpty)
              const _SectionEmptyHint(message: AppStrings.profileEmptyRecipes)
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                ),
                child: Column(
                  children: [
                    for (final r in preview)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s),
                        child: _PublicRecipeRow(recipe: r),
                      ),
                    if (overflow > 0)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 2,
                          bottom: AppSpacing.s,
                        ),
                        child: Text(
                          '+$overflow ${AppStrings.profileRecipesMoreSuffix}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _PublicRecipeRow extends StatelessWidget {
  const _PublicRecipeRow({required this.recipe});
  final Recipe recipe;
  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.m,
      ),
      onTap: () => context.push('${AppRoutes.recipes}/${recipe.id}'),
      child: Row(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 18,
            color: AppColors.softGold,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              recipe.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium,
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

// ── Yardımcılar ───────────────────────────────────────────────────

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _SectionEmptyHint extends StatelessWidget {
  const _SectionEmptyHint({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageH,
        vertical: AppSpacing.s,
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
      ),
    );
  }
}

/// M4 Polish — profile posts paged "Daha fazla göster" CTA.
class _LoadMoreCta extends StatelessWidget {
  const _LoadMoreCta({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.l,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton(
          onPressed: isLoading ? null : onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.borderHairline, width: 0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                )
              : const Text(
                  AppStrings.profilePostsLoadMore,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
        ),
      ),
    );
  }
}
