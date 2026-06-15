import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_products.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/firinnet_taxonomy.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/guest_mode_provider.dart';
import '../../auth/utils/email_validator.dart';
import '../models/bakery_profile.dart';
import '../providers/profile_provider.dart';

/// Form'da kullanıcı bir şey yazmışsa true. CreateProfileScreen'in escape
/// confirm dialog'unda kontrol edilir.
bool _hasDirtyInput({
  required String name,
  required String city,
  required String email,
  required String password,
}) {
  return name.trim().isNotEmpty ||
      city.trim().isNotEmpty ||
      email.trim().isNotEmpty ||
      password.isNotEmpty;
}

/// Profil oluşturma / tamamlama ekranı.
///
/// V1.3:
/// - `initialAccountType` parametresi verilirse (Role Select Screen'den
///   gelen `?role=` query'si), o rol önceden seçili olarak gelir.
/// - Mevcut profil null değilse (incomplete completion senaryosu) varolan
///   alanlar form'da doldurulur.
/// - Form completion contract: display_name + city + role_badge zorunlu.
///   account_type chip'inden daima bir seçim olur.
class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key, this.initialAccountType});

  /// Signup öncesi rol seçildiyse buradan geçer.
  final AccountType? initialAccountType;

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late AccountType _accountType;
  String _badge = RoleBadges.commercial.first;

  /// M6A — il seçimi (controlled). Eski şehir TextField controller'ı
  /// kaldırıldı; LocationPickerField üzerinden TurkeyProvince seçilir.
  TurkeyProvince? _selectedProvince;
  bool _submitting = false;
  bool _isCompletion = false;
  // V1.3.5 — Yasal kabul checkbox.
  // Yeni signup'ta zorunlu; completion akışında (zaten signed-in profilini
  // tamamlıyor) gösterilmez — kabul kayıt anında alınmıştı.
  bool _legalAccepted = false;
  bool _legalShowError = false;
  // V1.4 — ProfileController async hydrate olduğunda formu bir kez pre-fill
  // etmek için (kullanıcı yazdığı değerleri sonradan ezmeyelim).
  bool _profileHydrated = false;

  @override
  void initState() {
    super.initState();
    _accountType = widget.initialAccountType ?? AccountType.commercial;
    _badge = _badgesForRole(_accountType).first;

    // Mode kararı — kontrat:
    //   1) profileController hydrate (BakeryProfile != null) → completion
    //      + profile alanlarıyla pre-fill.
    //   2) profile hydrate değil ama auth user var (Google/OAuth veya email
    //      confirm sonrası) → completion. Email auth user'dan; diğer alanlar
    //      profileController hydrate olunca [`ref.listen`]'da doldurulur.
    //   3) Hiçbiri yok → klasik email/şifre signup mode.
    //
    // V1.4 fix — Önceki sürümde yalnız (1) kontrol ediliyordu; ProfileController
    // async olduğu için (`_loadFor`) Google login dönüşünde state null olur,
    // ekran signup mode'a düşerdi.
    final existing = ref.read(profileControllerProvider);
    final authUser = ref.read(currentAuthUserProvider);

    if (existing != null) {
      _isCompletion = true;
      _profileHydrated = true;
      _accountType = existing.accountType;
      _nameCtrl.text = existing.displayName;
      _selectedProvince =
          TurkeyLocations.findProvinceByCode(existing.cityCode) ??
          TurkeyLocations.findProvinceByName(existing.city);
      _emailCtrl.text = existing.email;
      final preset = _badgesForRole(_accountType);
      _badge =
          preset.contains(existing.roleBadge) && existing.roleBadge.isNotEmpty
          ? existing.roleBadge
          : preset.first;
    } else if (authUser != null) {
      _isCompletion = true;
      _emailCtrl.text = authUser.email ?? '';
      // displayName / city / badge / accountType profileController hydrate
      // olunca [`build`] içindeki ref.listen ile doldurulur.
    }
  }

  /// V1.4 — ProfileController async hydrate olunca completion mode formunu
  /// bir kez pre-fill et. `_profileHydrated` flag'i sonsuz setState ve user
  /// input ezme riskini engeller.
  void _hydrateFromProfile(BakeryProfile profile) {
    if (_profileHydrated) return;
    _profileHydrated = true;
    if (_nameCtrl.text.isEmpty) _nameCtrl.text = profile.displayName;
    _selectedProvince ??=
        TurkeyLocations.findProvinceByCode(profile.cityCode) ??
        TurkeyLocations.findProvinceByName(profile.city);
    if (_emailCtrl.text.isEmpty) _emailCtrl.text = profile.email;
    _accountType = profile.accountType;
    final preset = _badgesForRole(_accountType);
    _badge = preset.contains(profile.roleBadge) && profile.roleBadge.isNotEmpty
        ? profile.roleBadge
        : preset.first;
    if (mounted) setState(() {});
  }

  List<String> _badgesForRole(AccountType type) {
    switch (type) {
      case AccountType.commercial:
        return RoleBadges.commercial;
      case AccountType.individual:
        return RoleBadges.individual;
      case AccountType.wholesaler:
        return RoleBadges.wholesaler;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return AppStrings.authEmailRequired;
    if (!value.contains('@') || !value.contains('.')) {
      return AppStrings.authEmailInvalid;
    }
    // V1.4 — RFC 6761'de reserved test TLD'leri Supabase Auth tarafında
    // `email_address_invalid` ile reddediliyor. Kullanıcıyı baştan uyar.
    if (isReservedTestTldEmail(value)) {
      return AppStrings.authEmailTestTldNotAllowed;
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return AppStrings.authPasswordRequired;
    if (value.length < 6) return AppStrings.authPasswordTooShort;
    return null;
  }

  String? _validateRequired(String? v, String labelMissing) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return labelMissing;
    return null;
  }

  /// V1.3.1 — "Üye olmadan gezmeye devam et" escape hatch.
  ///
  /// 3 senaryo:
  /// 1. currentUser null → guest flag set + /feed
  /// 2. currentUser var ama profile incomplete → signOut + guest set + /feed
  /// 3. Form'da yazılı veri varsa → confirm dialog
  Future<void> _continueAsGuest() async {
    final dirty = _hasDirtyInput(
      name: _nameCtrl.text,
      city: _selectedProvince?.name ?? '',
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (dirty) {
      final keep = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(AppStrings.profileCreateDiscardTitle),
          content: const Text(AppStrings.profileCreateDiscardBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(AppStrings.profileCreateDiscardKeep),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.copper),
              child: const Text(AppStrings.profileCreateDiscardLeave),
            ),
          ],
        ),
      );
      if (keep != true) return;
    }

    final auth = ref.read(authRepositoryProvider);
    final currentUser = auth?.currentUser;

    // Senaryo 2: incomplete authenticated session → signOut + temizlik.
    if (currentUser != null) {
      try {
        await auth!.signOut();
      } catch (_) {
        // Ağ kopuk olsa bile local state temizle.
      }
      ref.read(profileControllerProvider.notifier).clear();
    }

    // Senaryo 1 + 2: guest flag set, feed'e geç.
    await ref.read(guestModeProvider.notifier).setGuest(true);
    ref.read(profileControllerProvider.notifier).useGuest();
    if (!mounted) return;
    context.go(AppRoutes.feed);
  }

  /// Profil tamamlandığında rol bazlı, sıcak bir karşılama üst banner'ı.
  /// Büyük onboarding değil; tek seferlik (bu akış zaten bir kez çalışır)
  /// kısa hoş geldin. Mesaj kullanıcının seçtiği hesap türüne göre değişir.
  void _showRoleWelcome() {
    final String message;
    switch (_accountType) {
      case AccountType.commercial:
        message = AppStrings.roleWelcomeCommercial;
      case AccountType.individual:
        message = AppStrings.roleWelcomeIndividual;
      case AccountType.wholesaler:
        message = AppStrings.roleWelcomeWholesaler;
    }
    PremiumTopBannerController.show(
      context,
      title: AppStrings.roleWelcomeTitle,
      message: message,
      tone: PremiumTopBannerTone.success,
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    // V1.4 P1.5 — Erken submit guard.
    //
    // Completion mode'da `_hydrateFromProfile` async tetiklenir ve mevcut
    // profilden `_accountType` + `_badge` değerlerini koşulsuz overwrite
    // eder (display_name/city/email yalnız boşken doldurulur, ama
    // accountType/badge her zaman). Hydrate tamamlanmadan kullanıcı
    // Kaydet'e basarsa default `commercial`/`first-badge` Supabase'e yazılır.
    // Guard kullanıcıyı bilgilendirip submit'i bloke eder; hydrate tamamlanır
    // tamamlanmaz `_profileHydrated = true` olur ve tekrar Kaydet çalışır.
    if (_isCompletion && !_profileHydrated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.profileStillLoadingError)),
      );
      return;
    }

    // V1.3.5 — Yeni signup'ta yasal kabul zorunlu.
    if (!_isCompletion && !_legalAccepted) {
      setState(() => _legalShowError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.legalAcceptRequired)),
      );
      return;
    }

    final displayName = _nameCtrl.text.trim();
    // M6A — il seçimi zorunlu (controlled).
    final province = _selectedProvince;
    if (province == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Şehir seçilmedi.')));
      return;
    }
    final city = province.name;
    final cityCode = province.code;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final auth = ref.read(authRepositoryProvider);

    // M5 — dual-write: label (eski form) + code (yeni taxonomy).
    final badgeCode = FirinnetTaxonomy.professionCodeFromLabel(_badge);

    // Supabase yok → local-only profile state.
    if (auth == null) {
      ref
          .read(profileControllerProvider.notifier)
          .save(
            BakeryProfile(
              displayName: displayName,
              accountType: _accountType,
              city: city,
              cityCode: cityCode,
              roleBadge: _badge,
              roleBadgeCode: badgeCode,
              email: email,
            ),
          );
      if (!mounted) return;
      _showRoleWelcome();
      // Splash redirect mantığını yeniden tetikle (rol bazlı panel).
      context.go(AppRoutes.splash);
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_isCompletion) {
        // Zaten signed-in, eksik profile completion: mevcut profile satırını
        // güncelle (Supabase trigger zaten signUp sırasında insert etmişti).
        await ref
            .read(profileControllerProvider.notifier)
            .save(
              BakeryProfile(
                displayName: displayName,
                accountType: _accountType,
                city: city,
                cityCode: cityCode,
                roleBadge: _badge,
                roleBadgeCode: badgeCode,
                email: email,
              ),
            );
        if (!mounted) return;
        _showRoleWelcome();
        context.go(AppRoutes.splash);
        return;
      }

      // Yeni signup — handle_new_user triggerı profile'ı oluşturur.
      final result = await auth.signUp(
        email: email,
        password: password,
        metadata: <String, dynamic>{
          'display_name': displayName,
          'account_type': _accountType.name,
          'profession_badge': _badge,
          if (badgeCode != null) 'profession_badge_code': badgeCode,
          'city': city,
          'city_code': cityCode,
        },
      );
      // Signup başarılıysa guest flag temizlenir (her iki durumda da).
      await ref.read(guestModeProvider.notifier).setGuest(false);
      if (!mounted) return;

      // mailer_autoconfirm OFF: Supabase user oluşturdu ama session
      // vermedi. Splash/Feed'e yönlendirmek yanıltıcı — `currentUser` hâlâ
      // null. Kullanıcıyı bilgilendir + Login ekranına gönder.
      if (result.needsEmailConfirmation) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            title: const Text(AppStrings.authEmailConfirmTitle),
            content: const Text(AppStrings.authEmailConfirmBody),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text(AppStrings.authEmailConfirmOk),
              ),
            ],
          ),
        );
        if (!mounted) return;
        context.go(AppRoutes.login);
        return;
      }

      // Auto-confirm AÇIK ya da provider doğrudan session verdi: normal akış.
      _showRoleWelcome();
      context.go(AppRoutes.splash);
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      // V1.4 — Default 4 sn snackbar kullanıcı tarafından kaçırılıyordu.
      // 7 sn göster + "Tamam" action ile dismiss edebilsin.
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          duration: const Duration(seconds: 7),
          action: SnackBarAction(
            label: AppStrings.commonOk,
            onPressed: messenger.hideCurrentSnackBar,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabaseOn = ref.watch(authRepositoryProvider) != null;
    final badges = _badgesForRole(_accountType);
    final title = _isCompletion ? 'Profili Tamamla' : AppStrings.createProfile;

    // V1.4 — Google/OAuth completion akışında profileController hydrate'i
    // initState'ten sonra gelir. İlk non-null transition'da formu pre-fill et.
    ref.listen<BakeryProfile?>(profileControllerProvider, (prev, next) {
      if (next == null) return;
      if (!_isCompletion) return;
      _hydrateFromProfile(next);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.s,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Hangi tür hesap kullanıyorsun?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rolünü seç — panel ve araçlar buna göre düzenlenir.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _AccountTypePicker(
              selected: _accountType,
              onChanged: (t) => setState(() {
                _accountType = t;
                final list = _badgesForRole(t);
                if (!list.contains(_badge)) _badge = list.first;
              }),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: AppStrings.displayName,
                hintText: 'Örn. Hasan Usta',
              ),
              validator: (v) => _validateRequired(v, 'Profil adı gerekli'),
            ),
            const SizedBox(height: 14),
            LocationPickerField(
              label: AppStrings.city,
              value: _selectedProvince?.name,
              hint: 'İl seç',
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
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              enabled:
                  !_isCompletion, // signed-in iken email değişimi auth update gerektirir
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: AppStrings.email,
                hintText: AppStrings.authEmailHint,
                helperText: _isCompletion
                    ? AppStrings.profileEmailLockedHelper
                    : null,
                suffixIcon: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.textMuted,
                ),
              ),
              validator: supabaseOn && !_isCompletion ? _validateEmail : null,
            ),
            if (supabaseOn && !_isCompletion) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.password,
                  hintText: AppStrings.authPasswordHint,
                  suffixIcon: Icon(
                    Icons.lock_outline,
                    color: AppColors.textMuted,
                  ),
                ),
                validator: _validatePassword,
              ),
            ],
            const SizedBox(height: 22),
            Text(AppStrings.roleBadge, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: badges.map((b) {
                final selected = _badge == b;
                return ChoiceChip(
                  label: Text(b),
                  selected: selected,
                  onSelected: (_) => setState(() => _badge = b),
                );
              }).toList(),
            ),
            if (!_isCompletion) ...[
              const SizedBox(height: 24),
              _LegalAcceptCheckbox(
                value: _legalAccepted,
                showError: _legalShowError && !_legalAccepted,
                onChanged: (v) => setState(() {
                  _legalAccepted = v ?? false;
                  if (_legalAccepted) _legalShowError = false;
                }),
              ),
            ],
            const SizedBox(height: 32),
            AppPrimaryButton(
              label: _submitting ? '…' : AppStrings.save,
              icon: Icons.check_rounded,
              onPressed: _submitting ? null : _save,
            ),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: _submitting ? null : _continueAsGuest,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                ),
                child: const Text(
                  AppStrings.profileCreateGuestEscape,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: Text(
                AppStrings.profileCreateGuestHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Üçlü hesap türü seçici — Ticari / Bireysel / Toptancı.
class _AccountTypePicker extends StatelessWidget {
  const _AccountTypePicker({required this.selected, required this.onChanged});

  final AccountType selected;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AccountTypeCard(
          icon: Icons.storefront_rounded,
          title: AppStrings.accountCommercial,
          subtitle: AppStrings.roleCommercialSub,
          isSelected: selected == AccountType.commercial,
          onTap: () => onChanged(AccountType.commercial),
        ),
        const SizedBox(height: 8),
        _AccountTypeCard(
          icon: Icons.person_rounded,
          title: AppStrings.accountIndividual,
          subtitle: AppStrings.roleIndividualSub,
          isSelected: selected == AccountType.individual,
          onTap: () => onChanged(AccountType.individual),
        ),
        const SizedBox(height: 8),
        _AccountTypeCard(
          icon: Icons.local_shipping_rounded,
          title: AppStrings.accountWholesaler,
          subtitle: AppStrings.roleWholesalerSub,
          isSelected: selected == AccountType.wholesaler,
          onTap: () => onChanged(AccountType.wholesaler),
        ),
      ],
    );
  }
}

/// V1.3.5 — Yasal metin kabul checkbox'ı (zorunlu, yeni signup için).
///
/// Tıklanabilir Kullanım Şartları + Gizlilik Politikası link'leri içerir.
/// Kabul edilmediğinde [showError] true olur ve kırmızı border + uyarı yazısı
/// gösterilir.
class _LegalAcceptCheckbox extends StatelessWidget {
  const _LegalAcceptCheckbox({
    required this.value,
    required this.onChanged,
    required this.showError,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final borderColor = showError
        ? AppColors.danger.withValues(alpha: 0.55)
        : AppColors.borderHairline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(
              color: borderColor,
              width: showError ? 1.0 : 0.6,
            ),
            color: AppColors.card,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.copper,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 12, right: 4),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                      children: [
                        TextSpan(
                          text: AppStrings.legalTermsTitle,
                          style: const TextStyle(
                            color: AppColors.softGold,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => context.push(AppRoutes.legalTerms),
                        ),
                        const TextSpan(text: ' ve '),
                        TextSpan(
                          text: AppStrings.legalPrivacyTitle,
                          style: const TextStyle(
                            color: AppColors.softGold,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                context.push(AppRoutes.legalPrivacy),
                        ),
                        const TextSpan(text: '\'nı okudum, kabul ediyorum.'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: AppSpacing.s),
            child: Text(
              AppStrings.legalAcceptRequired,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}

/// Profil oluşturma rol seçimi — dikey, açıklamalı, belirgin seçili durum.
/// Varsayılan yanlılığı azaltmak için seçim büyük ve net görünür.
class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.brandLemonPale : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(
              color: isSelected
                  ? AppColors.brandLemonPressed
                  : AppColors.borderHairline,
              width: isSelected ? 1.2 : 0.6,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brandLemon.withValues(alpha: 0.35)
                      : AppColors.surfaceLine,
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.textPrimary, size: 24),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? AppColors.brandLemonPressed
                    : AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
