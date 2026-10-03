// FırınNet Profile Self-Edit M3 — temel profil düzenleme bottom sheet.
// M5 — meslek chip section eklendi (taxonomy-driven).
//
// Kullanıcı kendi profilinde "Profili düzenle" CTA'sına basınca açılır.
// Düşük teknoloji kullanıcı için sade tek ekran: avatar değiştir + ad +
// şehir + meslek + hesap tipi. Ustalık bilgileri için sheet altında ayrı
// satır /worker/profile'a yönlendirir (mevcut zengin form).
//
// Save flow:
//   1) Guest guard → showAuthRequiredSheet
//   2) (opsiyonel) Avatar upload — başarısız ise snackbar, sheet açık kalır
//   3) profiles UPDATE display_name + city + account_type + avatar_url
//   4) ProfileController + publicProfileDetailProvider invalidate
//   5) Sheet kapat + başarı snackbar

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/firinnet_taxonomy.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/firinnet_avatar.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/location_picker.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../dealers/widgets/role_data_lock.dart';
import '../models/bakery_profile.dart';
import '../providers/profile_provider.dart';
import '../providers/public_profile_detail_provider.dart';
import '../services/avatar_upload_service.dart';

/// Sheet içi hata satırı (danger ikon + kısa metin).
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('profile_edit_inline_error'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const ProfileEditSheet(),
    );
  }

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  final _name = TextEditingController();
  AccountType _accountType = AccountType.individual;

  /// M5 — meslek taxonomy code; UI label çevirimle render eder.
  String? _professionCode;

  /// M6A — şehir plaka kodu; UI label `TurkeyLocations`'tan gelir.
  TurkeyProvince? _selectedProvince;

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  /// Sheet içi hata metni: snackbar modal'ın arkasında kalıp görünmüyordu.
  String? _inlineError;

  String? _avatarUrl;
  BakeryProfile? _initial;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(profileControllerProvider);
    if (initial != null) {
      _hydrate(initial);
      _loading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromRepo());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _hydrate(BakeryProfile p) {
    _initial = p;
    _name.text = p.displayName;
    _accountType = p.accountType;
    _avatarUrl = p.avatarUrl;
    // M5 — code öncelikli; yoksa legacy label'dan çevir.
    _professionCode =
        p.roleBadgeCode ??
        FirinnetTaxonomy.professionCodeFromLabel(p.roleBadge);
    // M6A — city code öncelikli; yoksa legacy label'dan plaka çıkarmayı dene.
    _selectedProvince =
        TurkeyLocations.findProvinceByCode(p.cityCode) ??
        TurkeyLocations.findProvinceByName(p.city);
  }

  Future<void> _loadFromRepo() async {
    final user = ref.read(currentAuthUserProvider);
    final repo = ref.read(profileRepositoryProvider);
    if (user == null || repo == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final p = await repo.fetchProfile(user.id);
      if (!mounted) return;
      if (p != null) _hydrate(p);
    } catch (_) {
      // Sessiz — sheet boş textfield ile açılır, kullanıcı yine yazabilir.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final service = ref.read(avatarUploadServiceProvider);
    final user = ref.read(currentAuthUserProvider);
    if (service == null || user == null) return;

    XFile? picked;
    try {
      picked = await service.pickFromGallery();
    } catch (e) {
      debugPrint('[FirinNet][ProfileEdit] avatar pick error: $e');
      if (!mounted) return;
      setState(() => _inlineError = AppStrings.profileEditAvatarErrorPick);
      return;
    }
    if (picked == null) return;

    setState(() {
      _uploading = true;
      _inlineError = null;
    });
    try {
      final result = await service.upload(userId: user.id, file: picked);
      if (!mounted) return;
      setState(() => _avatarUrl = result.publicUrl);
      AppFeedback.success(context, AppStrings.profileAvatarAddedSnack);
    } catch (e) {
      debugPrint('[FirinNet][ProfileEdit] avatar upload error: $e');
      if (!mounted) return;
      setState(() => _inlineError = AppStrings.profileEditAvatarErrorUpload);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _inlineError = AppStrings.profileEditNameRequired);
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() {
      _saving = true;
      _inlineError = null;
    });
    final previousAvatarUrl = _initial?.avatarUrl;
    try {
      // M5 — meslek dual-write: code (taxonomy) + label (backward compat).
      final pCode = _professionCode;
      final pLabel = pCode == null
          ? null
          : FirinnetTaxonomy.professionLabel(pCode);
      // M6A — şehir dual-write: city_code (taxonomy) + city (eski text).
      final province = _selectedProvince;
      final draft =
          (_initial ??
                  const BakeryProfile(
                    displayName: '',
                    accountType: AccountType.individual,
                    city: '',
                    roleBadge: '',
                    email: '',
                  ))
              .copyWith(
                displayName: name,
                city: province?.name ?? '',
                cityCode: province?.code,
                accountType: _accountType,
                avatarUrl: _avatarUrl,
                roleBadge: pLabel ?? '',
                roleBadgeCode: pCode,
              );
      await ref.read(profileControllerProvider.notifier).save(draft);
      // M4 Polish — kaydet başarılı + yeni avatar gerçekten değiştiyse
      // eski avatar dosyasını best-effort sil. Save fail olursa cleanup
      // çalışmaz (eski URL hâlâ profilin canlı avatarı).
      final user = ref.read(currentAuthUserProvider);
      if (user != null &&
          previousAvatarUrl != null &&
          previousAvatarUrl.isNotEmpty &&
          previousAvatarUrl != _avatarUrl) {
        final service = ref.read(avatarUploadServiceProvider);
        await service?.deleteIfOwned(
          userId: user.id,
          oldUrl: previousAvatarUrl,
        );
      }
      // Public profile detay + snapshot cache'leri yenilensin.
      if (user != null) {
        ref.invalidate(publicProfileDetailProvider(user.id));
      }
      if (!mounted) return;
      // Başarı geri bildirimi sheet kapandıktan sonra görünür.
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          AppFeedback.build(
            AppStrings.profileEditSaveSuccess,
            kind: AppFeedbackKind.success,
          ),
        );
    } catch (e) {
      debugPrint('[FirinNet][ProfileEdit] save error: $e');
      if (!mounted) return;
      // ROL/SCOPE VERİ KİLİDİ: rol-kilitli verisi (bayi/defter/borç-gider) olan
      // kullanıcı account_type değiştiremez (DB trigger engeller) → açıklama.
      if (isRoleDataLockError(e)) {
        await showRoleDataLockDialog(context, forInvite: false);
      } else {
        setState(() => _inlineError = AppStrings.profileEditSaveError);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            AppSpacing.l,
          ),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.m),
                        decoration: BoxDecoration(
                          color: AppColors.borderHairline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      AppStrings.profileEditSheetTitle,
                      style: AppTypography.sectionTitle,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    _AvatarTile(
                      avatarUrl: _avatarUrl,
                      name: _name.text.trim(),
                      uploading: _uploading,
                      onTap: _uploading || _saving
                          ? null
                          : _pickAndUploadAvatar,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: AppStrings.profileEditNameLabel,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    LocationPickerField(
                      label: AppStrings.profileEditCityLabel,
                      value: _selectedProvince?.name,
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
                    const SizedBox(height: AppSpacing.l),
                    const Text(
                      AppStrings.profileEditProfessionLabel,
                      style: AppTypography.infoLabel,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in FirinnetTaxonomy.professionEntries)
                          ChoiceChip(
                            label: Text(e.value),
                            selected: _professionCode == e.key,
                            onSelected: _saving
                                ? null
                                : (v) {
                                    setState(() {
                                      _professionCode = v ? e.key : null;
                                    });
                                  },
                            selectedColor: AppColors.brandLemonSoft.withValues(
                              alpha: 0.28,
                            ),
                            backgroundColor: Colors.transparent,
                            labelStyle: AppTypography.chipLabel.copyWith(
                              color: _professionCode == e.key
                                  ? AppColors.brandInk
                                  : AppColors.textSecondary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              side: BorderSide(
                                color: _professionCode == e.key
                                    ? AppColors.brandLemonSoft
                                    : AppColors.surfaceVariant,
                                width: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                    const Text(
                      AppStrings.profileEditAccountTypeLabel,
                      style: AppTypography.infoLabel,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in AccountType.values)
                          ChoiceChip(
                            label: Text(t.label),
                            selected: _accountType == t,
                            onSelected: _saving
                                ? null
                                : (v) {
                                    if (v) {
                                      setState(() => _accountType = t);
                                    }
                                  },
                            selectedColor: AppColors.brandLemonSoft.withValues(
                              alpha: 0.28,
                            ),
                            backgroundColor: Colors.transparent,
                            labelStyle: AppTypography.chipLabel.copyWith(
                              color: _accountType == t
                                  ? AppColors.brandInk
                                  : AppColors.textSecondary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              side: BorderSide(
                                color: _accountType == t
                                    ? AppColors.brandLemonSoft
                                    : AppColors.surfaceVariant,
                                width: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_inlineError != null) ...[
                      _InlineError(message: _inlineError!),
                      const SizedBox(height: AppSpacing.s),
                    ],
                    AppPrimaryButton(
                      label: _saving
                          ? AppStrings.profileEditSaving
                          : AppStrings.profileEditSaveCta,
                      icon: Icons.check_rounded,
                      onPressed: (_saving || _uploading) ? null : _save,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _WorkerLinkRow(
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(AppRoutes.workerProfile);
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.avatarUrl,
    required this.name,
    required this.uploading,
    required this.onTap,
  });

  final String? avatarUrl;
  final String name;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Ortak avatar: fotoğraf (memCacheWidth ile ekran boyutunda decode)
        // → yüklenirken/bozuksa baş harfler; kırık resim ikonu yok.
        FirinNetAvatar(
          key: const ValueKey('profile_edit_avatar'),
          name: name,
          imageUrl: avatarUrl,
          size: FirinNetAvatarSize.l,
        ),
        const SizedBox(width: AppSpacing.l),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: uploading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  )
                : const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(
              uploading
                  ? AppStrings.profileEditAvatarUploading
                  : AppStrings.profileEditAvatarChange,
              style: AppTypography.buttonLabel.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(
                color: AppColors.borderHairline,
                width: 0.8,
              ),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkerLinkRow extends StatelessWidget {
  const _WorkerLinkRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.m),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s,
            horizontal: AppSpacing.s,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.badge_outlined,
                size: 18,
                color: AppColors.brandInk,
              ),
              const SizedBox(width: AppSpacing.s),
              const Expanded(
                child: Text(
                  AppStrings.profileEditWorkerLink,
                  style: AppTypography.smallAction,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.brandInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
