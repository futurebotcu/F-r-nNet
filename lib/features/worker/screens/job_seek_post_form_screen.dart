import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/firinnet_taxonomy.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/job_seek_post.dart';
import '../providers/worker_providers.dart';

/// İş Arıyorum İlanı oluştur/düzenle ekranı.
class JobSeekPostFormScreen extends ConsumerStatefulWidget {
  const JobSeekPostFormScreen({super.key, this.postId});
  final String? postId;

  @override
  ConsumerState<JobSeekPostFormScreen> createState() =>
      _JobSeekPostFormScreenState();
}

class _JobSeekPostFormScreenState extends ConsumerState<JobSeekPostFormScreen> {
  // M5 — meslek listesi ortak taxonomy'den.
  static List<String> get _professionCodes =>
      FirinnetTaxonomy.professionCodes;

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
  bool _saving = false;
  JobSeekPost? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.postId != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(workerRepositoryProvider);
    final p = await repo.getJobSeekPost(widget.postId!);
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İlan bulunamadı.')),
      );
      Navigator.of(context).pop();
      return;
    }
    _existing = p;
    _title.text = p.title;
    // M6A — city_code öncelikli; yoksa legacy text label'dan çevir.
    _selectedProvince = TurkeyLocations.findProvinceByCode(p.cityCode) ??
        TurkeyLocations.findProvinceByName(p.city);
    _experience.text =
        p.experienceYears != null ? '${p.experienceYears}' : '';
    _salary.text = p.salaryExpectation != null
        ? p.salaryExpectation!.toStringAsFixed(0)
        : '';
    _description.text = p.description ?? '';
    _contactPhone.text = p.contactPhone ?? '';
    // M5 — code öncelikli; yoksa legacy label'dan çevir.
    _professionCode = p.professionBadgeCode ??
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
    final cleaned =
        raw.trim().replaceAll(RegExp(r'[\s\-()]+'), '');
    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık boş olamaz.')),
      );
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
      final label =
          code == null ? null : FirinnetTaxonomy.professionLabel(code);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _existing == null ? 'İlan yayınlandı.' : 'İlan güncellendi.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _previewShare() {
    final code = _professionCode;
    final label =
        code == null ? null : FirinnetTaxonomy.professionLabel(code);
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
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      isActive: _isActive,
    );
    Share.share(p.toShareText(), subject: 'FırınNet — İş Arıyorum');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PremiumScaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
      );
    }
    final isEditing = _existing != null;
    return PremiumScaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'İlanı Düzenle' : 'Yeni İş İlanı'),
        actions: [
          IconButton(
            tooltip: 'Paylaş',
            onPressed: _previewShare,
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            const _Hint(
              text:
                  'Kısa, net ve dürüst yaz — şehir, tecrübe ve maaş beklentin '
                  'işverenin ilk filtrelediği şey.',
            ),
            const SizedBox(height: AppSpacing.l),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Başlık',
                hintText: 'Manisa civarı taş fırın ustası',
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            const _Section('MESLEK'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final code in _professionCodes)
                  ChoiceChip(
                    label: Text(
                      FirinnetTaxonomy.professionLabel(code) ?? code,
                    ),
                    selected: _professionCode == code,
                    onSelected: (v) =>
                        setState(() => _professionCode = v ? code : null),
                    selectedColor: AppColors.copper.withValues(alpha: 0.22),
                    backgroundColor: AppColors.card,
                    labelStyle: TextStyle(
                      color: _professionCode == code
                          ? AppColors.softGold
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      side: BorderSide(
                        color: _professionCode == code
                            ? AppColors.copper.withValues(alpha: 0.55)
                            : AppColors.borderHairline,
                        width: 0.6,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            LocationPickerField(
              label: 'Şehir',
              value: _selectedProvince?.name,
              hint: 'İl seç',
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
            const SizedBox(height: AppSpacing.s),
            Row(
              children: [
                Expanded(
                  child: AppNumberField(
                    label: 'Tecrübe yılı',
                    controller: _experience,
                    suffix: 'yıl',
                    allowDecimal: false,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: AppNumberField(
                    label: 'Maaş beklentisi',
                    controller: _salary,
                    suffix: 'TL',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: AppStrings.listingContactPhoneLabel,
                hintText: AppStrings.listingContactPhoneHint,
                helperText: AppStrings.listingContactPhoneHelper,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Açıklama (opsiyonel)',
                hintText: 'Vardiya tercihi, ulaşım durumu, özel beceriler…',
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            PremiumCard(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (_isActive ? AppColors.success : AppColors.textMuted)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.s),
                    ),
                    child: Icon(
                      _isActive ? Icons.public_rounded : Icons.lock_outline_rounded,
                      color: _isActive ? AppColors.success : AppColors.textMuted,
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
                          _isActive ? 'Yayında' : 'Kapalı',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isActive
                              ? 'Sektördeki diğer kullanıcılar görür.'
                              : 'Sadece sen görürsün. Sonra açabilirsin.',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
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
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: _saving
                  ? 'Kaydediliyor…'
                  : (isEditing ? 'Güncelle' : 'İlanı Yayınla'),
              icon: Icons.check_rounded,
              onPressed: _saving ? null : _save,
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
          const Icon(Icons.tips_and_updates_outlined,
              color: AppColors.softGold, size: 18),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s, left: 2),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.softGold,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
