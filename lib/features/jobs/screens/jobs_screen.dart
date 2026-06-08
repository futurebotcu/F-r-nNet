import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/firinnet_taxonomy.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/listing_phone_cta.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/job_opportunity_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../messages/widgets/start_job_conversation_sheet.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../../worker/models/job_seek_post.dart';
import '../../worker/providers/worker_providers.dart';
import '../models/job_offer_post.dart';
import '../providers/job_offer_providers.dart';

/// V1 İlanlar — gerçek `job_seek_posts` + `job_offer_posts` verilerine bağlı.
///
/// "Usta Arıyor" segmenti `activeJobOffersProvider` üzerinden ticari/toptancı
/// işletmelerin yayınladığı aktif ilanları listeler.
/// "İş Arıyor" segmenti `activeJobSeekPostsProvider` üzerinden bireysel
/// kullanıcıların yayınladığı aktif ilanları listeler.
/// "+" CTA segmente göre yönlendirir; role-aware (commercial/wholesaler ↔
/// individual).
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  int _segmentIndex = 0;

  Future<void> _onAddPressed() async {
    // Segment'e göre doğru ilan formuna yönlendir.
    // 0: Usta Arıyor (ticari/toptancı yayını) → /jobs/offers/new
    // 1: İş Arıyor (bireysel yayını) → /worker/job-seek/new
    final canWrite = AuthRequiredGuard.canWriteWithRef(ref);
    if (!canWrite) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    // M8 Cleanup P1-1: bireysel kullanıcı "Usta Arıyor" ilanı veremez —
    // bu segment yalnız ticari ve toptancı içindir. Snackbar + early return.
    if (_segmentIndex == 0) {
      final profile = ref.read(profileControllerProvider);
      final isCommercial =
          profile?.accountType == AccountType.commercial ||
          profile?.accountType == AccountType.wholesaler;
      if (!isCommercial) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.jobOfferCommercialOnly)),
        );
        return;
      }
    }
    final route = _segmentIndex == 0
        ? AppRoutes.jobOfferNew
        : AppRoutes.jobSeekNew;
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            FirinNetHeader(
              title: AppStrings.jobsTitle,
              subtitle: AppStrings.jobsSubtitle,
              actions: [
                HeaderActionButton(
                  icon: Icons.add_rounded,
                  onTap: _onAddPressed,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: _Segment(
                index: _segmentIndex,
                onChange: (i) => setState(() => _segmentIndex = i),
              ),
            ),
            if (_segmentIndex == 0)
              const _HiringList()
            else
              const _LookingList(),
          ],
        ),
      ),
    );
  }
}

class _LookingList extends ConsumerWidget {
  const _LookingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeJobSeekPostsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(title: AppStrings.jobsListLooking),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const EmptyState(
            compact: true,
            icon: Icons.cloud_off_outlined,
            title: AppStrings.jobsErrorGeneric,
          ),
          data: (posts) {
            if (posts.isEmpty) {
              final user = ref.watch(currentAuthUserProvider);
              return EmptyState(
                compact: true,
                icon: Icons.inbox_outlined,
                title: user == null
                    ? AppStrings.jobsLookingEmptyGuest
                    : AppStrings.jobsLookingEmpty,
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: Column(
                children: [
                  for (var i = 0; i < posts.length; i++) ...[
                    _JobSeekCard(post: posts[i]),
                    if (i != posts.length - 1)
                      const SizedBox(height: AppSpacing.m),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _JobSeekCard extends ConsumerWidget {
  const _JobSeekCard({required this.post});
  final JobSeekPost post;

  String _formatSalary() {
    final v = post.salaryExpectation;
    if (v == null || v <= 0) return AppStrings.jobsCardSalaryUnset;
    return 'Beklenti ₺ ${v.toStringAsFixed(0)}';
  }

  String _formatExperience() {
    final y = post.experienceYears;
    if (y == null || y < 0) return AppStrings.jobsCardExperienceUnset;
    if (y == 0) return 'Deneyimsiz olabilir';
    return '$y yıl';
  }

  String _formatBusiness() {
    final badge = post.professionBadge;
    if (badge == null || badge.trim().isEmpty) {
      return AppStrings.jobsCardBusinessFallback;
    }
    return badge.trim();
  }

  String _formatCity() {
    final c = post.city;
    if (c == null || c.trim().isEmpty) return AppStrings.jobsCardCityUnset;
    return c.trim();
  }

  Future<void> _onContact(BuildContext context, WidgetRef ref) async {
    final canWrite = AuthRequiredGuard.canWriteWithRef(ref);
    if (!canWrite) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    await StartJobConversationSheet.showForSeek(context, post);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Job seek kartı: ticari/toptancı kullanıcı iş arayanla iletişime
    // geçebilir. Bireysel kullanıcı veya kendi ilanı için CTA gizlenir
    // (onApply=null → JobOpportunityCard CTA'yı hiç render etmez).
    final profile = ref.watch(profileControllerProvider);
    final user = ref.watch(currentAuthUserProvider);
    final isOwn = user != null && post.ownerId == user.id;
    final isCommercial =
        profile?.accountType == AccountType.commercial ||
        profile?.accountType == AccountType.wholesaler;
    final showCta = !isOwn && (isCommercial || profile == null);
    final card = JobOpportunityCard(
      position: post.title,
      business: _formatBusiness(),
      city: _formatCity(),
      salary: _formatSalary(),
      experience: _formatExperience(),
      badge: AppStrings.jobsCardBadgeActive,
      shift: null,
      onApply: showCta ? () => _onContact(context, ref) : null,
      applyLabel: AppStrings.jobsContact,
      applyIcon: Icons.chat_bubble_outline_rounded,
    );
    // Listing Contact Phone Sprint — sahibi telefon paylaştıysa Ara CTA.
    if (!ListingPhoneCta.hasPhone(post.contactPhone) || isOwn) {
      return card;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        card,
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.s,
          ),
          child: ListingPhoneCta(phone: post.contactPhone, compact: true),
        ),
      ],
    );
  }
}

/// V1 — "Usta Arıyor" segmenti: ticari/toptancı işletmelerin yayınladığı
/// aktif `job_offer_posts` listesi. Empty state dürüst; ticari rol kullanıcı
/// için CTA "Usta Arıyorum İlanı Ver".
class _HiringList extends ConsumerWidget {
  const _HiringList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeJobOffersProvider);
    final profile = ref.watch(profileControllerProvider);
    final canPostOffer =
        profile?.accountType == AccountType.commercial ||
        profile?.accountType == AccountType.wholesaler;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(title: AppStrings.jobsListHiring),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const EmptyState(
            compact: true,
            icon: Icons.cloud_off_outlined,
            title: AppStrings.jobOfferErrorGeneric,
          ),
          data: (offers) {
            if (offers.isEmpty) {
              final user = ref.watch(currentAuthUserProvider);
              return Column(
                children: [
                  EmptyState(
                    compact: true,
                    icon: Icons.inbox_outlined,
                    title: user == null
                        ? AppStrings.jobOfferEmptyGuest
                        : AppStrings.jobOfferEmpty,
                  ),
                  if (canPostOffer)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageH,
                        0,
                        AppSpacing.pageH,
                        AppSpacing.l,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text(
                            AppStrings.jobOfferAddCta,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: () => context.push(AppRoutes.jobOfferNew),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.copper,
                            foregroundColor: AppColors.brandInk,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.m),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: Column(
                children: [
                  for (var i = 0; i < offers.length; i++) ...[
                    _JobOfferCard(offer: offers[i]),
                    if (i != offers.length - 1)
                      const SizedBox(height: AppSpacing.m),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _JobOfferCard extends ConsumerWidget {
  const _JobOfferCard({required this.offer});
  final JobOfferPost offer;

  String _formatSalary() {
    final min = offer.salaryMin;
    final max = offer.salaryMax;
    if (min == null && max == null) return AppStrings.jobsCardSalaryUnset;
    if (min != null && max != null && max > min) {
      return '₺ ${min.toStringAsFixed(0)} – ${max.toStringAsFixed(0)}';
    }
    final v = (max ?? min)!;
    return '₺ ${v.toStringAsFixed(0)}';
  }

  String _formatCity() {
    final c = offer.city?.trim() ?? '';
    final d = offer.district?.trim() ?? '';
    if (c.isEmpty && d.isEmpty) return AppStrings.jobsCardCityUnset;
    if (d.isEmpty) return c;
    if (c.isEmpty) return d;
    return '$c · $d';
  }

  String _formatExperience() {
    // M8 — code öncelikli (taxonomy label); yoksa eski text fallback.
    final code = offer.experienceCode;
    if (code != null) {
      final lbl = FirinnetTaxonomy.experienceLabel(code);
      if (lbl != null) return lbl;
    }
    final e = offer.experienceRequired?.trim();
    if (e == null || e.isEmpty) return AppStrings.jobsCardExperienceUnset;
    return e;
  }

  /// M8 — vardiya görüntüsü: shift_code → taxonomy label; yoksa eski text.
  String? _formatShift() {
    final code = offer.shiftCode;
    if (code != null) {
      final lbl = FirinnetTaxonomy.shiftLabel(code);
      if (lbl != null) return lbl;
    }
    return offer.shiftType;
  }

  String _formatBusiness() {
    final n = offer.authorName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return AppStrings.jobsCardBusinessFallback;
  }

  Future<void> _onApply(BuildContext context, WidgetRef ref) async {
    final canWrite = AuthRequiredGuard.canWriteWithRef(ref);
    if (!canWrite) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    await StartJobConversationSheet.showForOffer(context, offer);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Usta Arıyor kartı: bireysel kullanıcı başvurabilir; kendi ilanı için
    // CTA gizlenir.
    final user = ref.watch(currentAuthUserProvider);
    final isOwn = user != null && offer.ownerId == user.id;
    final card = JobOpportunityCard(
      position: offer.title,
      business: _formatBusiness(),
      city: _formatCity(),
      salary: _formatSalary(),
      experience: _formatExperience(),
      badge: AppStrings.jobsCardBadgeActive,
      shift: _formatShift(),
      onApply: isOwn ? null : () => _onApply(context, ref),
      applyLabel: AppStrings.jobsApply,
      applyIcon: Icons.send_rounded,
    );
    // Listing Contact Phone Sprint — sahibi telefon paylaştıysa Ara CTA.
    if (!ListingPhoneCta.hasPhone(offer.contactPhone) || isOwn) {
      return card;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        card,
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.s,
          ),
          child: ListingPhoneCta(phone: offer.contactPhone, compact: true),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.index, required this.onChange});

  final int index;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    // İş İlanları Polish V1 — feed'deki premium segmented control diliyle
    // hizalı: surface track + pill, seçili = card pill + yumuşak gölge +
    // softGold label. Davranış aynı (index/onChange).
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
      ),
      child: Row(
        children: [
          _SegmentTab(
            label: AppStrings.jobsSegHiring,
            selected: index == 0,
            onTap: () => onChange(0),
          ),
          _SegmentTab(
            label: AppStrings.jobsSegLooking,
            selected: index == 1,
            onTap: () => onChange(1),
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          curve: Curves.easeOut,
          alignment: Alignment.center,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: selected ? AppShadow.subtle : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.softGold : AppColors.textMuted,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              fontSize: 13,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}
