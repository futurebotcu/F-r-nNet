import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/firinnet_taxonomy.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/interactions.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../dealers/widgets/dealer_filter_chip.dart';
import '../../listings/utils/listing_format.dart';
import '../../listings/widgets/listing_ui.dart';
import '../models/job_seek_post.dart';
import '../providers/worker_providers.dart';

/// Unified Professional CV Center — profil → "İş Arıyorum ilanı aç" için
/// mesleki CV verilerinden prefill paketi. Sadece kolaylık/prefill amaçlı;
/// menüden manuel ilan açma akışını DEĞİŞTİRMEZ (prefill null → boş form).
class JobSeekPrefill {
  const JobSeekPrefill({
    this.professionCode,
    this.cityCode,
    this.cityName,
    this.experienceYears,
    this.description,
  });

  final String? professionCode;
  final String? cityCode;
  final String? cityName;
  final int? experienceYears;
  final String? description;
}

/// İş Arıyorum İlanı oluştur/düzenle ekranı.
class JobSeekPostFormScreen extends ConsumerStatefulWidget {
  const JobSeekPostFormScreen({super.key, this.postId, this.prefill});
  final String? postId;

  /// CV Center prefill (yalnız yeni ilanda, postId null iken uygulanır).
  final JobSeekPrefill? prefill;

  @override
  ConsumerState<JobSeekPostFormScreen> createState() =>
      _JobSeekPostFormScreenState();
}

class _JobSeekPostFormScreenState extends ConsumerState<JobSeekPostFormScreen> {
  // M5 — meslek listesi ortak taxonomy'den.
  static List<String> get _professionCodes => FirinnetTaxonomy.professionCodes;

  final _title = TextEditingController();
  final _experience = TextEditingController();
  final _salary = TextEditingController();
  final _description = TextEditingController();

  /// Listing Contact Phone Sprint — opsiyonel.
  final _contactPhone = TextEditingController();

  /// M5 — taxonomy code.
  String? _professionCode;

  /// M6A — il seçimi (controlled).
  TurkeyProvince? _selectedProvince;

  bool _isActive = true;

  bool _loading = false;
  bool _loadFailed = false;
  bool _saving = false;
  JobSeekPost? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.postId != null) {
      _load();
    } else if (widget.prefill != null) {
      _applyPrefill(widget.prefill!);
    }
  }

  /// CV Center'dan gelen prefill — yalnız yeni ilan açılışında. İlana özel
  /// alanlar (maaş, iletişim, yayın durumu) kullanıcıya bırakılır.
  void _applyPrefill(JobSeekPrefill p) {
    _professionCode = p.professionCode ?? _professionCode;
    _selectedProvince =
        TurkeyLocations.findProvinceByCode(p.cityCode) ??
        TurkeyLocations.findProvinceByName(p.cityName);
    if (p.experienceYears != null) {
      _experience.text = '${p.experienceYears}';
    }
    if ((p.description ?? '').isNotEmpty) {
      _description.text = p.description!;
    }
    // Başlık boşsa meslek+şehirden makul bir öneri üret (kullanıcı düzenler).
    if (_title.text.trim().isEmpty) {
      final prof = p.professionCode == null
          ? null
          : FirinnetTaxonomy.professionLabel(p.professionCode!);
      final city = _selectedProvince?.name;
      final parts = <String>[
        if (city != null && city.isNotEmpty) city,
        if (prof != null && prof.isNotEmpty) prof,
      ];
      if (parts.isNotEmpty) _title.text = '${parts.join(' ')} arıyor';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final repo = ref.read(workerRepositoryProvider);
    final JobSeekPost? p;
    try {
      p = await repo.getJobSeekPost(widget.postId!);
    } catch (_) {
      // Ağ hatası: sonsuz yükleme yerine hata durumu + Tekrar dene / Geri.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
      return;
    }
    if (!mounted) return;
    if (p == null) {
      AppFeedback.error(context, AppStrings.listingsNotFound);
      Navigator.of(context).pop();
      return;
    }
    _existing = p;
    _title.text = p.title;
    // M6A — city_code öncelikli; yoksa legacy text label'dan çevir.
    _selectedProvince =
        TurkeyLocations.findProvinceByCode(p.cityCode) ??
        TurkeyLocations.findProvinceByName(p.city);
    _experience.text = p.experienceYears != null ? '${p.experienceYears}' : '';
    _salary.text = p.salaryExpectation != null
        ? p.salaryExpectation!.toStringAsFixed(0)
        : '';
    _description.text = p.description ?? '';
    _contactPhone.text = p.contactPhone ?? '';
    // M5 — code öncelikli; yoksa legacy label'dan çevir.
    _professionCode =
        p.professionBadgeCode ??
        FirinnetTaxonomy.professionCodeFromLabel(p.professionBadge);
    _isActive = p.isActive;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _title.dispose();
    _experience.dispose();
    _salary.dispose();
    _description.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  /// Telefon normalize — boşluk/tire/parantez temizle. Boş → null.
  static String? _normalizePhone(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\s\-()]+'), '');
    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      AppFeedback.warning(context, AppStrings.listingsTitleRequired);
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() => _saving = true);
    try {
      // M5 — dual-write: code + label (backward compat).
      final code = _professionCode;
      final label = code == null
          ? null
          : FirinnetTaxonomy.professionLabel(code);
      // M6A — şehir dual-write.
      final province = _selectedProvince;
      final draft = JobSeekPost(
        id: _existing?.id,
        ownerId: _existing?.ownerId,
        title: _title.text.trim(),
        professionBadge: label,
        professionBadgeCode: code,
        city: province?.name,
        cityCode: province?.code,
        experienceYears: _experience.text.trim().isEmpty
            ? null
            : int.tryParse(_experience.text.trim()),
        salaryExpectation: _salary.text.trim().isEmpty
            ? null
            : NumberFormatter.parseLoose(_salary.text),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        contactPhone: _normalizePhone(_contactPhone.text),
        isActive: _isActive,
      );
      await ref.read(workerRepositoryProvider).upsertJobSeekPost(draft);
      if (!mounted) return;
      AppHaptics.success();
      // İş arama ilanı ücretsiz → ödeme bekleme durumu yok.
      AppFeedback.success(
        context,
        listingSavedMessage(isEdit: _existing != null, isPendingPayment: false),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(context, AppStrings.listingsSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _previewShare() {
    final code = _professionCode;
    final label = code == null ? null : FirinnetTaxonomy.professionLabel(code);
    final province = _selectedProvince;
    final p = JobSeekPost(
      title: _title.text.trim().isEmpty ? 'İş ilanı' : _title.text.trim(),
      professionBadge: label,
      professionBadgeCode: code,
      city: province?.name,
      cityCode: province?.code,
      experienceYears: _experience.text.trim().isEmpty
          ? null
          : int.tryParse(_experience.text.trim()),
      salaryExpectation: _salary.text.trim().isEmpty
          ? null
          : NumberFormatter.parseLoose(_salary.text),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      isActive: _isActive,
    );
    Share.share(p.toShareText(), subject: AppStrings.finalSeekShareSubject);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PremiumScaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
      );
    }
    if (_loadFailed) {
      return PremiumScaffold(
        appBar: AppBar(title: const Text(AppStrings.listingsSeekEditTitle)),
        body: Center(
          child: ErrorRetryState(
            key: const ValueKey('job_seek_form_load_error'),
            title: AppStrings.listingsDetailLoadError,
            onRetry: _load,
          ),
        ),
      );
    }
    final isEditing = _existing != null;
    // Polish 2 — bölümlü form (Temel bilgi / Konum / Ücret / Detaylar /
    // İletişim / Yayın durumu) + klavye üstünde kalan sabit CTA.
    return PremiumScaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? AppStrings.listingsSeekEditTitle
              : AppStrings.listingsJobSeekFormTitleNew,
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.listingsShareTooltip,
            onPressed: _previewShare,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      bottomNavigationBar: ListingStickyBar(
        child: AppPrimaryButton(
          key: const ValueKey('job_seek_form_submit'),
          label: _saving
              ? AppStrings.listingsSavingCta
              : (isEditing
                    ? AppStrings.listingsUpdateCta
                    : AppStrings.listingsSeekPublishCta),
          icon: Icons.check_rounded,
          onPressed: _saving ? null : _save,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xl,
          ),
          children: [
            const _Hint(text: AppStrings.listingsJobSeekFormHint),
            // ── Temel bilgi ──
            const ListingSectionHeader(AppStrings.listingsSectionBasics),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: AppStrings.listingsSeekTitleLabel,
                hintText: AppStrings.listingsSeekTitleHint,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              AppStrings.listingsDetailProfession,
              style: AppTypography.infoLabel,
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final code in _professionCodes)
                  DealerFilterChip(
                    label: FirinnetTaxonomy.professionLabel(code) ?? code,
                    selected: _professionCode == code,
                    onSelected: _saving
                        ? null
                        : (v) =>
                              setState(() => _professionCode = v ? code : null),
                  ),
              ],
            ),
            // ── Konum ──
            const ListingSectionHeader(AppStrings.listingsSectionLocation),
            LocationPickerField(
              label: AppStrings.listingsSeekCity,
              value: _selectedProvince?.name,
              hint: AppStrings.listingsSeekCityHint,
              enabled: !_saving,
              onTap: () async {
                final picked = await LocationPicker.showProvincePicker(
                  context,
                  initialCode: _selectedProvince?.code,
                );
                if (picked != null) {
                  setState(() => _selectedProvince = picked);
                }
              },
              onClear: _selectedProvince == null
                  ? null
                  : () => setState(() => _selectedProvince = null),
            ),
            // ── Ücret ──
            const ListingSectionHeader(AppStrings.listingsSectionSalary),
            AppNumberField(
              label: AppStrings.listingsSeekSalary,
              controller: _salary,
              suffix: 'TL',
              // Yalnız rakam: "25.000" yazılıp 25 okunması engellenir.
              allowDecimal: false,
            ),
            // ── Detaylar ──
            const ListingSectionHeader(AppStrings.listingsSectionDetails),
            AppNumberField(
              label: AppStrings.listingsSeekExperience,
              controller: _experience,
              suffix: 'yıl',
              allowDecimal: false,
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: AppStrings.listingsSeekDescription,
                hintText: AppStrings.listingsSeekDescriptionHint,
                alignLabelWithHint: true,
              ),
            ),
            // ── İletişim ──
            const ListingSectionHeader(AppStrings.listingsSectionContact),
            TextField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: AppStrings.listingContactPhoneLabel,
                hintText: AppStrings.listingContactPhoneHint,
                helperText: AppStrings.listingContactPhoneHelper,
                helperMaxLines: 2,
              ),
            ),
            // ── Yayın durumu ──
            const ListingSectionHeader(AppStrings.listingsSectionPublish),
            PremiumCard(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color:
                          (_isActive ? AppColors.success : AppColors.textMuted)
                              .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.s),
                    ),
                    child: Icon(
                      _isActive
                          ? Icons.public_rounded
                          : Icons.lock_outline_rounded,
                      color: _isActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isActive
                              ? AppStrings.listingsPublishOpen
                              : AppStrings.listingsPublishClosed,
                          style: AppTypography.cardTitle.copyWith(
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isActive
                              ? AppStrings.listingsPublishOpenHint
                              : AppStrings.listingsPublishClosedHint,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    activeThumbColor: AppColors.success,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: [
          const Icon(
            Icons.tips_and_updates_outlined,
            color: AppColors.brandInk,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(child: Text(text, style: AppTypography.body)),
        ],
      ),
    );
  }
}
