import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/firinnet_taxonomy.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/firinnet_avatar.dart';
import '../../../core/widgets/listing_phone_cta.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/job_opportunity_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../listings/utils/listing_format.dart';
import '../../listings/widgets/listing_ui.dart';
import '../../messages/widgets/start_job_conversation_sheet.dart';
import '../../payments/widgets/listing_payment_button.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../../safety/models/report_models.dart';
import '../../safety/widgets/block_user_dialog.dart';
import '../../safety/widgets/report_sheet.dart';
import '../../subscriptions/widgets/listing_fee_notice.dart';
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
///
/// İlanlar tasarım geçişi: kart dokunulabilir → tam bilgi sayfası (alt
/// sheet); tür rozeti, göreli tarih, kart içi "Ara", ⋮ şikayet/engelle,
/// owner'ın ödeme bekleyen ilanında ödeme butonu, çekerek yenileme.
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key, this.embedded = false});

  /// İlanlar sekmesi altında "Eleman" segmenti olarak gömüldüğünde true:
  /// kendi FırınNetHeader'ını çizmez (üst kapsayıcı "İlanlar" başlığı + segmente
  /// duyarlı "+" sağlar). İç "Usta Arıyor / İş Arıyor" alt-segmenti korunur.
  /// Standalone /jobs → false, davranış aynen korunur.
  final bool embedded;

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
    // bu segment yalnız ticari ve toptancı içindir. Bilgi + early return.
    if (_segmentIndex == 0) {
      final profile = ref.read(profileControllerProvider);
      final isCommercial =
          profile?.accountType == AccountType.commercial ||
          profile?.accountType == AccountType.wholesaler;
      if (!isCommercial) {
        AppFeedback.info(context, AppStrings.jobOfferCommercialOnly);
        return;
      }
    }
    final route = _segmentIndex == 0
        ? AppRoutes.jobOfferNew
        : AppRoutes.jobSeekNew;
    context.push(route);
  }

  Future<void> _onRefresh() async {
    if (_segmentIndex == 0) {
      ref.invalidate(activeJobOffersProvider);
      await ref
          .read(activeJobOffersProvider.future)
          .catchError((_) => const <JobOfferPost>[]);
    } else {
      ref.invalidate(activeJobSeekPostsProvider);
      await ref
          .read(activeJobSeekPostsProvider.future)
          .catchError((_) => const <JobSeekPost>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.brandInk,
          onRefresh: _onRefresh,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              if (!widget.embedded) ...[
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
              ] else
                const SizedBox(height: AppSpacing.s),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                ),
                child: _Segment(
                  index: _segmentIndex,
                  onChange: (i) => setState(() => _segmentIndex = i),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              if (_segmentIndex == 0)
                const _HiringList()
              else
                const _LookingList(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste gövdesi: kartlar arası ritim + sayfa kenar boşluğu.
Widget _cardColumn(List<Widget> cards) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
    child: Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i != cards.length - 1) const SizedBox(height: AppSpacing.m),
        ],
      ],
    ),
  );
}

class _LookingList extends ConsumerWidget {
  const _LookingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeJobSeekPostsProvider);
    return async.when(
      // Perf: ilan oluşturma/güncelleme sonrası liste eski içeriğini
      // korur, spinner flash yok.
      skipLoadingOnReload: true,
      // Polish 2 — ilk yüklemede tek spinner yerine hafif kart iskeleti.
      loading: () => const ListingSkeletonList(),
      error: (_, __) => ErrorRetryState(
        compact: true,
        title: AppStrings.listingsLoadError,
        subtitle: AppStrings.listingsLoadErrorHint,
        onRetry: () => ref.invalidate(activeJobSeekPostsProvider),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          final user = ref.watch(currentAuthUserProvider);
          return EmptyState(
            compact: true,
            icon: Icons.person_search_outlined,
            title: AppStrings.jobsLookingEmptyTitle,
            subtitle: user == null
                ? AppStrings.jobsLookingEmptyGuest
                : AppStrings.jobsLookingEmpty,
          );
        }
        return _cardColumn([for (final p in posts) _JobSeekCard(post: p)]);
      },
    );
  }
}

/// UGC Safety V1 — şikayet et / sahibini engelle sheet'i (⋮ ve uzun basma).
Future<void> _showJobSafetySheet(
  BuildContext context,
  WidgetRef ref, {
  required String targetId,
  required String ownerId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.flag_outlined,
              color: AppColors.textPrimary,
            ),
            title: const Text(
              AppStrings.safetyActionReport,
              style: AppTypography.bodyLarge,
            ),
            onTap: () {
              Navigator.of(ctx).pop();
              showReportSheet(
                context,
                ref,
                targetType: ReportTargetType.jobListing,
                targetId: targetId,
                reportedUserId: ownerId,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded, color: AppColors.danger),
            title: Text(
              AppStrings.safetyActionBlock,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.danger),
            ),
            onTap: () {
              Navigator.of(ctx).pop();
              confirmAndBlockUser(context, ref, userId: ownerId);
            },
          ),
        ],
      ),
    ),
  );
}

bool _canReport({
  required bool isOwn,
  required String? targetId,
  required String? ownerId,
}) =>
    !isOwn &&
    targetId != null &&
    targetId.isNotEmpty &&
    ownerId != null &&
    ownerId.isNotEmpty;

/// UGC Safety V1 — ilan kartına uzun basma: şikayet et / sahibini engelle.
/// Kendi ilanında veya id/owner bilinmiyorsa sarmalamaz. (Aynı aksiyonlar
/// kartın ⋮ menüsünde de görünür.)
Widget _withJobSafetyActions(
  BuildContext context,
  WidgetRef ref, {
  required Widget child,
  required bool isOwn,
  required String? targetId,
  required String? ownerId,
}) {
  if (!_canReport(isOwn: isOwn, targetId: targetId, ownerId: ownerId)) {
    return child;
  }
  return GestureDetector(
    onLongPress: () => _showJobSafetySheet(
      context,
      ref,
      targetId: targetId!,
      ownerId: ownerId!,
    ),
    child: child,
  );
}

/// Polish 2 — tür başına TEK birincil eylem etiketi; kart ve detay aynı
/// sabiti kullanır (personel ilanı → "Başvur", iş arayan → "Mesaj gönder").
const String offerPrimaryCtaLabel = AppStrings.jobsApply;
const String seekPrimaryCtaLabel = AppStrings.listingsCtaMessage;

/// Göreli tarih (yoksa null).
String? _timeLabel(DateTime? createdAt) =>
    createdAt == null ? null : ListingFormat.relative(createdAt);

/// Başlık boşsa veriden sunum başlığı üretir: "Rol aranıyor · Şehir".
String _presentationTitle(
  String raw, {
  required String? role,
  required String? city,
  required String suffix,
}) {
  final t = raw.trim();
  if (t.isNotEmpty) return t;
  final r = (role ?? '').trim();
  final c = (city ?? '').trim();
  if (r.isEmpty) {
    return c.isEmpty
        ? AppStrings.listingsTitleFallback
        : '${AppStrings.listingsTitleFallback} · $c';
  }
  return c.isEmpty ? '$r $suffix' : '$r $suffix · $c';
}

class _JobSeekCard extends ConsumerWidget {
  const _JobSeekCard({required this.post});
  final JobSeekPost post;

  String _formatSalary() {
    final v = post.salaryExpectation;
    if (v == null || v <= 0) return AppStrings.listingsSalaryNegotiable;
    return '${AppStrings.listingsSalaryExpectation} ${ListingFormat.price(v)}';
  }

  String? _formatExperience() {
    final y = post.experienceYears;
    if (y == null || y < 0) return null;
    if (y == 0) return AppStrings.listingsExperienceNone;
    return '$y ${AppStrings.listingsExperienceYearsSuffix}';
  }

  String? _formatProfession() {
    final code = post.professionBadgeCode;
    final fromCode = code == null
        ? null
        : FirinnetTaxonomy.professionLabel(code);
    final label = (fromCode ?? post.professionBadge)?.trim();
    return (label == null || label.isEmpty) ? null : label;
  }

  String? _formatCity() {
    final c = post.city?.trim();
    return (c == null || c.isEmpty) ? null : c;
  }

  String _title() => _presentationTitle(
    post.title,
    role: _formatProfession(),
    city: _formatCity(),
    suffix: AppStrings.listingsTitleSeekingSuffix,
  );

  Future<void> _onContact(BuildContext context, WidgetRef ref) async {
    final canWrite = AuthRequiredGuard.canWriteWithRef(ref);
    if (!canWrite) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    await StartJobConversationSheet.showForSeek(context, post);
  }

  void _openDetail(
    BuildContext context,
    WidgetRef ref, {
    required bool showCta,
    required bool showPhone,
  }) {
    // Ücret ve konum detayda kendi satırlarında; burada yalnız şartlar.
    final rows = <MapEntry<String, String>>[
      if (_formatProfession() != null)
        MapEntry(AppStrings.listingsDetailProfession, _formatProfession()!),
      if (_formatExperience() != null)
        MapEntry(AppStrings.listingsDetailExperience, _formatExperience()!),
    ];
    final salary = post.salaryExpectation;
    showJobListingDetailSheet(
      context,
      kind: JobListingKind.seeking,
      title: _title(),
      keyFact: _formatSalary(),
      keyFactIsFallback: salary == null || salary <= 0,
      location: _formatCity(),
      rows: rows,
      description: post.description,
      createdAt: post.createdAt,
      // Kart ve detayda aynı birincil eylem etiketi.
      primaryLabel: showCta ? seekPrimaryCtaLabel : null,
      primaryIcon: Icons.chat_bubble_outline_rounded,
      onPrimary: showCta ? () => _onContact(context, ref) : null,
      phone: showPhone ? post.contactPhone : null,
    );
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
    // Listing Contact Phone Sprint — sahibi telefon paylaştıysa Ara CTA
    // (artık kartın içinde, ikincil aksiyon olarak).
    final showPhone = !isOwn && ListingPhoneCta.hasPhone(post.contactPhone);
    final canReport = _canReport(
      isOwn: isOwn,
      targetId: post.id,
      ownerId: post.ownerId,
    );
    final card = JobOpportunityCard(
      kind: JobListingKind.seeking,
      title: _title(),
      keyFact: _formatSalary(),
      location: _formatCity(),
      timeLabel: _timeLabel(post.createdAt),
      tags: [?_formatProfession(), ?_formatExperience()],
      onTap: () =>
          _openDetail(context, ref, showCta: showCta, showPhone: showPhone),
      onMore: canReport
          ? () => _showJobSafetySheet(
              context,
              ref,
              targetId: post.id!,
              ownerId: post.ownerId!,
            )
          : null,
      onApply: showCta ? () => _onContact(context, ref) : null,
      applyLabel: seekPrimaryCtaLabel,
      applyIcon: Icons.chat_bubble_outline_rounded,
      secondaryAction: showPhone
          ? ListingPhoneCta(phone: post.contactPhone, compact: true)
          : null,
    );
    return _withJobSafetyActions(
      context,
      ref,
      child: card,
      isOwn: isOwn,
      targetId: post.id,
      ownerId: post.ownerId,
    );
  }
}

/// V1 — "Usta Arıyor" segmenti: ticari/toptancı işletmelerin yayınladığı
/// aktif `job_offer_posts` listesi. Empty state dürüst; ticari rol kullanıcı
/// için CTA "Personel İlanı Ver".
class _HiringList extends ConsumerWidget {
  const _HiringList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeJobOffersProvider);
    final profile = ref.watch(profileControllerProvider);
    final canPostOffer =
        profile?.accountType == AccountType.commercial ||
        profile?.accountType == AccountType.wholesaler;
    return async.when(
      // Perf: ilan oluşturma/güncelleme sonrası liste eski içeriğini
      // korur, spinner flash yok.
      skipLoadingOnReload: true,
      // Polish 2 — ilk yüklemede tek spinner yerine hafif kart iskeleti.
      loading: () => const ListingSkeletonList(),
      error: (_, __) => ErrorRetryState(
        compact: true,
        title: AppStrings.listingsLoadError,
        subtitle: AppStrings.listingsLoadErrorHint,
        onRetry: () => ref.invalidate(activeJobOffersProvider),
      ),
      data: (offers) {
        if (offers.isEmpty) {
          final user = ref.watch(currentAuthUserProvider);
          return Column(
            children: [
              EmptyState(
                compact: true,
                icon: Icons.work_outline_rounded,
                title: AppStrings.jobOfferEmptyTitle,
                subtitle: user == null
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
                    height: 48,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text(AppStrings.jobOfferAddCta),
                      onPressed: () => context.push(AppRoutes.jobOfferNew),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandLemon,
                        textStyle: AppTypography.buttonLabel,
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
        return _cardColumn([for (final o in offers) _JobOfferCard(offer: o)]);
      },
    );
  }
}

class _JobOfferCard extends ConsumerWidget {
  const _JobOfferCard({required this.offer});
  final JobOfferPost offer;

  String _formatSalary() {
    return ListingFormat.priceRange(offer.salaryMin, offer.salaryMax) ??
        AppStrings.listingsSalaryNegotiable;
  }

  String? _formatCity() {
    final c = offer.city?.trim() ?? '';
    final d = offer.district?.trim() ?? '';
    if (c.isEmpty && d.isEmpty) return null;
    if (d.isEmpty) return c;
    if (c.isEmpty) return d;
    return '$c · $d';
  }

  String? _formatRole() {
    final code = offer.roleCode;
    final fromCode = code == null
        ? null
        : FirinnetTaxonomy.professionLabel(code);
    final label = (fromCode ?? offer.roleTitle).trim();
    return label.isEmpty ? null : label;
  }

  String? _formatExperience() {
    // M8 — code öncelikli (taxonomy label); yoksa eski text fallback.
    final code = offer.experienceCode;
    if (code != null) {
      final lbl = FirinnetTaxonomy.experienceLabel(code);
      if (lbl != null) return lbl;
    }
    final e = offer.experienceRequired?.trim();
    if (e == null || e.isEmpty) return null;
    return e;
  }

  /// M8 — vardiya görüntüsü: shift_code → taxonomy label; yoksa eski text.
  String? _formatShift() {
    final code = offer.shiftCode;
    if (code != null) {
      final lbl = FirinnetTaxonomy.shiftLabel(code);
      if (lbl != null) return lbl;
    }
    final s = offer.shiftType?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  String _formatBusiness() {
    final n = offer.authorName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return AppStrings.listingsOwnerFallback;
  }

  String _title() => _presentationTitle(
    offer.title,
    role: _formatRole(),
    city: offer.city,
    suffix: AppStrings.listingsTitleHiringSuffix,
  );

  Future<void> _onApply(BuildContext context, WidgetRef ref) async {
    final canWrite = AuthRequiredGuard.canWriteWithRef(ref);
    if (!canWrite) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    await StartJobConversationSheet.showForOffer(context, offer);
  }

  void _openDetail(
    BuildContext context,
    WidgetRef ref, {
    required bool isOwn,
    required bool showPhone,
  }) {
    // Ücret, konum ve ilan sahibi detayda kendi bloklarında.
    final rows = <MapEntry<String, String>>[
      if (_formatRole() != null)
        MapEntry(AppStrings.listingsDetailRole, _formatRole()!),
      if (_formatShift() != null)
        MapEntry(AppStrings.listingsDetailShift, _formatShift()!),
      if (_formatExperience() != null)
        MapEntry(AppStrings.listingsDetailExperience, _formatExperience()!),
    ];
    showJobListingDetailSheet(
      context,
      kind: JobListingKind.hiring,
      title: _title(),
      keyFact: _formatSalary(),
      keyFactIsFallback:
          ListingFormat.priceRange(offer.salaryMin, offer.salaryMax) == null,
      location: _formatCity(),
      ownerName: _formatBusiness(),
      rows: rows,
      description: offer.description,
      createdAt: offer.createdAt,
      expiresAt: offer.expiresAt,
      primaryLabel: isOwn ? null : offerPrimaryCtaLabel,
      primaryIcon: Icons.send_rounded,
      onPrimary: isOwn ? null : () => _onApply(context, ref),
      phone: showPhone ? offer.contactPhone : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Usta Arıyor kartı: bireysel kullanıcı başvurabilir; kendi ilanı için
    // CTA gizlenir.
    final user = ref.watch(currentAuthUserProvider);
    final isOwn = user != null && offer.ownerId == user.id;
    // İlan Ücretlendirme V1 — owner kendi ücretli-bekleyen ilanında "Ödeme
    // bekliyor" rozeti + ödeme butonu görür (public zaten pending görmez).
    final pendingOwn = isOwn && offer.isPendingPayment;
    // Listing Contact Phone Sprint — sahibi telefon paylaştıysa Ara CTA.
    final showPhone = !isOwn && ListingPhoneCta.hasPhone(offer.contactPhone);
    final canReport = _canReport(
      isOwn: isOwn,
      targetId: offer.id,
      ownerId: offer.ownerId,
    );
    final card = JobOpportunityCard(
      kind: JobListingKind.hiring,
      title: _title(),
      keyFact: _formatSalary(),
      location: _formatCity(),
      owner: _formatBusiness(),
      timeLabel: _timeLabel(offer.createdAt),
      tags: [?_formatExperience(), ?_formatShift()],
      statusBadge: pendingOwn ? const ListingPendingBadge() : null,
      onTap: () =>
          _openDetail(context, ref, isOwn: isOwn, showPhone: showPhone),
      onMore: canReport
          ? () => _showJobSafetySheet(
              context,
              ref,
              targetId: offer.id!,
              ownerId: offer.ownerId!,
            )
          : null,
      onApply: isOwn ? null : () => _onApply(context, ref),
      applyLabel: offerPrimaryCtaLabel,
      applyIcon: Icons.send_rounded,
      secondaryAction: showPhone
          ? ListingPhoneCta(phone: offer.contactPhone, compact: true)
          : null,
      footer: pendingOwn && (offer.id ?? '').isNotEmpty
          ? _PendingPaymentFooter(offerId: offer.id!)
          : null,
    );
    return _withJobSafetyActions(
      context,
      ref,
      child: card,
      isOwn: isOwn,
      targetId: offer.id,
      ownerId: offer.ownerId,
    );
  }
}

/// Owner'ın ödeme bekleyen iş ilanı: kısa açıklama + mevcut ödeme butonu
/// (ödeme mantığı değişmedi; market detayındaki aynı bileşen).
class _PendingPaymentFooter extends ConsumerWidget {
  const _PendingPaymentFooter({required this.offerId});
  final String offerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.listingsPendingPayHint,
          style: AppTypography.meta.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s),
        ListingPaymentButton(
          listingKind: 'job_offer',
          listingId: offerId,
          onPaid: () {
            ref.invalidate(activeJobOffersProvider);
            ref.invalidate(myJobOffersProvider);
          },
        ),
      ],
    );
  }
}

/// İş ilanı tam bilgi sayfası (alt sheet).
///
/// Polish 2 sırası: tür rozeti → başlık → ücret (priceLarge) → konum →
/// açıklama → şartlar (etiket/değer) → ilan sahibi → tarihler → sabit CTA.
/// Boş alanlar hiç çizilmez ("—" / "Belirtilmedi" yok).
Future<void> showJobListingDetailSheet(
  BuildContext context, {
  required JobListingKind kind,
  required String title,
  required String keyFact,
  bool keyFactIsFallback = false,
  String? location,
  String? ownerName,
  required List<MapEntry<String, String>> rows,
  String? description,
  DateTime? createdAt,
  DateTime? expiresAt,
  String? primaryLabel,
  IconData? primaryIcon,
  VoidCallback? onPrimary,
  String? phone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => JobListingDetailView(
      kind: kind,
      title: title,
      keyFact: keyFact,
      keyFactIsFallback: keyFactIsFallback,
      location: location,
      ownerName: ownerName,
      rows: rows,
      description: description,
      createdAt: createdAt,
      expiresAt: expiresAt,
      primaryLabel: primaryLabel,
      primaryIcon: primaryIcon,
      onPrimary: onPrimary,
      phone: phone,
    ),
  );
}

/// [showJobListingDetailSheet] gövdesi (test edilebilir olması için ayrı).
class JobListingDetailView extends StatelessWidget {
  const JobListingDetailView({
    super.key,
    required this.kind,
    required this.title,
    required this.keyFact,
    this.keyFactIsFallback = false,
    this.location,
    this.ownerName,
    required this.rows,
    this.description,
    this.createdAt,
    this.expiresAt,
    this.primaryLabel,
    this.primaryIcon,
    this.onPrimary,
    this.phone,
  });

  final JobListingKind kind;
  final String title;
  final String keyFact;
  final bool keyFactIsFallback;
  final String? location;
  final String? ownerName;
  final List<MapEntry<String, String>> rows;
  final String? description;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    final desc = (description ?? '').trim();
    final loc = (location ?? '').trim();
    final owner = (ownerName ?? '').trim();
    final terms = rows
        .where((r) => ListingInfoRow.isMeaningful(r.value))
        .toList(growable: false);
    final dates = [
      if (createdAt != null)
        '${AppStrings.listingsPublishedOn}: ${ListingFormat.date(createdAt!)}',
      if (expiresAt != null)
        '${AppStrings.listingsExpiresOn}: ${ListingFormat.date(expiresAt!)}',
    ].join(' · ');
    final hasPhone = ListingPhoneCta.hasPhone(phone);
    final primary = onPrimary;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.s),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.xs,
                AppSpacing.xs,
                0,
              ),
              child: Row(
                children: [
                  Flexible(child: JobKindBadge(kind: kind)),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('job_detail_close'),
                    tooltip: AppStrings.listingsCloseTooltip,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('job_detail_sheet'),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  0,
                  AppSpacing.pageH,
                  AppSpacing.m,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.detailTitle),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      keyFact,
                      key: const ValueKey('job_detail_key_fact'),
                      style: keyFactIsFallback
                          ? AppTypography.price.copyWith(
                              color: AppColors.textSecondary,
                            )
                          : AppTypography.priceLarge,
                    ),
                    if (loc.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              loc,
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (desc.isNotEmpty) ...[
                      const ListingSectionHeader(
                        AppStrings.listingsDetailDescription,
                      ),
                      Text(
                        desc,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                    if (terms.isNotEmpty) ...[
                      const ListingSectionHeader(
                        AppStrings.listingsSectionDetails,
                      ),
                      for (final r in terms)
                        ListingInfoRow(label: r.key, value: r.value),
                    ],
                    if (owner.isNotEmpty) ...[
                      const ListingSectionHeader(
                        AppStrings.listingsDetailOwner,
                      ),
                      Row(
                        key: const ValueKey('job_detail_owner'),
                        children: [
                          FirinNetAvatar(
                            name: owner,
                            kind: kind == JobListingKind.hiring
                                ? FirinNetAvatarKind.business
                                : FirinNetAvatarKind.person,
                          ),
                          const SizedBox(width: AppSpacing.m),
                          Expanded(
                            child: Text(
                              owner,
                              style: AppTypography.authorName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (dates.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.l),
                      Text(dates, style: AppTypography.caption),
                    ],
                  ],
                ),
              ),
            ),
            if (primary != null || hasPhone)
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  AppSpacing.s,
                  AppSpacing.pageH,
                  AppSpacing.m,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.borderHairline,
                      width: 0.6,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (primary != null)
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            key: const ValueKey('job_detail_primary'),
                            onPressed: () {
                              Navigator.of(context).maybePop();
                              primary();
                            },
                            icon: Icon(
                              primaryIcon ?? Icons.send_rounded,
                              size: 16,
                            ),
                            label: Text(
                              primaryLabel ?? offerPrimaryCtaLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brandLemon,
                              foregroundColor: AppColors.brandInk,
                              textStyle: AppTypography.buttonLabel,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.m,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (primary != null && hasPhone)
                      const SizedBox(width: AppSpacing.s),
                    if (hasPhone) ListingPhoneCta(phone: phone),
                  ],
                ),
              ),
          ],
        ),
      ),
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
    // koyu label. Davranış aynı (index/onChange).
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.chipLabel.copyWith(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
