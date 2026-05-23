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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/firinnet_taxonomy.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/bakery_profile.dart';
import '../providers/profile_provider.dart';
import '../providers/public_profile_detail_provider.dart';
import '../services/avatar_upload_service.dart';

class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const ProfileEditSheet(),
    );
  }

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  AccountType _accountType = AccountType.individual;

  /// M5 — meslek taxonomy code; UI label çevirimle render eder.
  String? _professionCode;

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

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
    _city.dispose();
    super.dispose();
  }

  void _hydrate(BakeryProfile p) {
    _initial = p;
    _name.text = p.displayName;
    _city.text = p.city;
    _accountType = p.accountType;
    _avatarUrl = p.avatarUrl;
    // M5 — code öncelikli; yoksa legacy label'dan çevir.
    _professionCode = p.roleBadgeCode ??
        FirinnetTaxonomy.professionCodeFromLabel(p.roleBadge);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.profileEditAvatarErrorPick),
        ),
      );
      return;
    }
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final result = await service.upload(userId: user.id, file: picked);
      if (!mounted) return;
      setState(() => _avatarUrl = result.publicUrl);
    } catch (e) {
      debugPrint('[FirinNet][ProfileEdit] avatar upload error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.profileEditAvatarErrorUpload),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.profileEditNameRequired)),
      );
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() => _saving = true);
    final previousAvatarUrl = _initial?.avatarUrl;
    try {
      // M5 — meslek dual-write: code (taxonomy) + label (backward compat).
      final pCode = _professionCode;
      final pLabel =
          pCode == null ? null : FirinnetTaxonomy.professionLabel(pCode);
      final draft = (_initial ??
              const BakeryProfile(
                displayName: '',
                accountType: AccountType.individual,
                city: '',
                roleBadge: '',
                email: '',
              ))
          .copyWith(
        displayName: name,
        city: _city.text.trim(),
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
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.profileEditSaveSuccess)),
      );
    } catch (e) {
      debugPrint('[FirinNet][ProfileEdit] save error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.profileEditSaveError)),
      );
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
                        margin:
                            const EdgeInsets.only(bottom: AppSpacing.m),
                        decoration: BoxDecoration(
                          color: AppColors.borderHairline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      AppStrings.profileEditSheetTitle,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    _AvatarTile(
                      avatarUrl: _avatarUrl,
                      initial: _name.text.trim().isNotEmpty
                          ? _name.text.trim()[0].toUpperCase()
                          : '?',
                      uploading: _uploading,
                      onTap:
                          _uploading || _saving ? null : _pickAndUploadAvatar,
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
                    TextField(
                      controller: _city,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: AppStrings.profileEditCityLabel,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    const Text(
                      AppStrings.profileEditProfessionLabel,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e
                            in FirinnetTaxonomy.professionEntries)
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
                            selectedColor:
                                AppColors.copper.withValues(alpha: 0.22),
                            backgroundColor: AppColors.card,
                            labelStyle: TextStyle(
                              color: _professionCode == e.key
                                  ? AppColors.softGold
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              side: BorderSide(
                                color: _professionCode == e.key
                                    ? AppColors.copper
                                        .withValues(alpha: 0.55)
                                    : AppColors.borderHairline,
                                width: 0.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                    const Text(
                      AppStrings.profileEditAccountTypeLabel,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
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
                            selectedColor:
                                AppColors.copper.withValues(alpha: 0.22),
                            backgroundColor: AppColors.card,
                            labelStyle: TextStyle(
                              color: _accountType == t
                                  ? AppColors.softGold
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              side: BorderSide(
                                color: _accountType == t
                                    ? AppColors.copper
                                        .withValues(alpha: 0.55)
                                    : AppColors.borderHairline,
                                width: 0.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
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
    required this.initial,
    required this.uploading,
    required this.onTap,
  });

  final String? avatarUrl;
  final String initial;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const double size = 72;
    final radius = BorderRadius.circular(AppRadius.l);
    final hasUrl = avatarUrl != null && avatarUrl!.isNotEmpty;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.softGold, AppColors.copperMuted],
        ),
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 30,
        ),
      ),
    );
    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: hasUrl
              ? ClipRRect(
                  borderRadius: radius,
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => fallback,
                    errorWidget: (_, __, ___) => fallback,
                  ),
                )
              : fallback,
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
              style: const TextStyle(fontWeight: FontWeight.w700),
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
                color: AppColors.softGold,
              ),
              const SizedBox(width: AppSpacing.s),
              const Expanded(
                child: Text(
                  AppStrings.profileEditWorkerLink,
                  style: TextStyle(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.softGold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
