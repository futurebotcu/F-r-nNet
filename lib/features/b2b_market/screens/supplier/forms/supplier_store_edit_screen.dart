// B2B Pazar — Tedarikçi > mağaza (vitrin) düzenleme formu.
//
// Mağazam veya Panel'den açılır. Bu B2B mağaza AYRI ticari vitrindir
// (b2b_supplier_shops, owner başına 1 satır, upsert); mevcut FırınNet profili /
// AccountType / auth DEĞİŞTİRİLMEZ. Kaydet → repo upsert, Mağazam yansır.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/widgets/dirty_form_guard.dart';
import '../../../../../core/widgets/premium/premium_scaffold.dart';
import '../../../providers/b2b_providers.dart';
import '../../../services/b2b_media_upload_service.dart';
import '../../../widgets/b2b_form_field.dart';
import '../../../widgets/b2b_image_upload_field.dart';
import '../../../../../core/widgets/app_feedback.dart';
import '../../../../../core/constants/app_strings.dart';

class SupplierStoreEditScreen extends ConsumerStatefulWidget {
  const SupplierStoreEditScreen({super.key});

  @override
  ConsumerState<SupplierStoreEditScreen> createState() =>
      _SupplierStoreEditScreenState();
}

class _SupplierStoreEditScreenState
    extends ConsumerState<SupplierStoreEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  // S3 — iletişim alanları (opsiyonel; sunucuda uzunluk CHECK, RLS owner).
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  final Set<String> _regions = <String>{};
  final Set<String> _categories = <String>{};
  String? _logoUrl;
  String? _coverUrl;
  bool _saving = false; // çift-submit guard (ürün/kampanya formlarıyla aynı)
  bool _dirty = false;
  bool _hydrating = true;
  void _markDirty() {
    if (_hydrating || _dirty) return;
    setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final store = await ref.read(b2bRepositoryProvider).myStore();
    if (!mounted) return;
    setState(() {
      _name.text = store.name;
      _description.text = store.description;
      _regions
        ..clear()
        ..addAll(store.serviceRegions);
      _categories
        ..clear()
        ..addAll(store.categories);
      _logoUrl = store.logoUrl;
      _coverUrl = store.coverUrl;
      _phone.text = store.phone ?? '';
      _whatsapp.text = store.whatsapp ?? '';
      _website.text = store.website ?? '';
      _address.text = store.address ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hydrating = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _website.dispose();
    _address.dispose();
    super.dispose();
  }

  static String? validatePhone(String? v) =>
      SupplierStoreEditScreenValidators.phone(v);
  static String? validateWebsite(String? v) =>
      SupplierStoreEditScreenValidators.website(v);

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(b2bMarketControllerProvider.notifier)
          .updateStore(
            name: _name.text.trim(),
            description: _description.text.trim(),
            serviceRegions: _regions.toList(),
            categories: _categories.toList(),
            logoUrl: _logoUrl,
            coverUrl: _coverUrl,
            phone: _phone.text.trim(),
            whatsapp: _whatsapp.text.trim(),
            website: _website.text.trim(),
            address: _address.text.trim(),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.error(context, AppStrings.polishB2bStoreError);
      return;
    }

    if (!mounted) return;
    _dirty = false;
    AppFeedback.success(context, AppStrings.polishB2bStoreUpdated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final regionOptions = ref.read(b2bRepositoryProvider).serviceRegions();
    final categoryOptions = ref.read(b2bRepositoryProvider).productCategories();

    final scaffold = PremiumScaffold(
      appBar: AppBar(title: const Text('Mağazanı düzenle')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          onChanged: _markDirty,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.l,
              AppSpacing.pageH,
              AppSpacing.xxl,
            ),
            children: [
              B2bTextField(
                label: 'Mağaza adı',
                controller: _name,
                hint: 'Ör. Anadolu Un & Maya',
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Mağaza adı gerekli'
                    : null,
              ),
              const SizedBox(height: AppSpacing.l),
              B2bTextField(
                label: 'Kısa açıklama',
                controller: _description,
                hint: 'Mağaza hakkında kısa tanıtım',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.l),
              B2bMultiSelectChips(
                label: 'Hizmet bölgeleri',
                options: regionOptions,
                selected: _regions,
                onToggle: (r) => setState(() {
                  _regions.contains(r) ? _regions.remove(r) : _regions.add(r);
                }),
              ),
              const SizedBox(height: AppSpacing.l),
              B2bMultiSelectChips(
                label: 'Kategoriler',
                options: categoryOptions,
                selected: _categories,
                onToggle: (c) => setState(() {
                  _categories.contains(c)
                      ? _categories.remove(c)
                      : _categories.add(c);
                }),
              ),
              const SizedBox(height: AppSpacing.l),
              // S3 — İletişim (opsiyonel). Yalnız oturum açmış kullanıcılara
              // mağaza sayfasında gösterilir (RLS).
              Text(
                AppStrings.b2bStoreContactSection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.s),
              B2bTextField(
                key: const ValueKey('b2b_store_phone'),
                label: AppStrings.b2bStorePhoneLabel,
                controller: _phone,
                hint: AppStrings.b2bStorePhoneHint,
                validator: validatePhone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.l),
              B2bTextField(
                key: const ValueKey('b2b_store_whatsapp'),
                label: AppStrings.b2bStoreWhatsappLabel,
                controller: _whatsapp,
                hint: AppStrings.b2bStoreWhatsappHint,
                validator: validatePhone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.l),
              B2bTextField(
                key: const ValueKey('b2b_store_website'),
                label: AppStrings.b2bStoreWebsiteLabel,
                controller: _website,
                hint: AppStrings.b2bStoreWebsiteHint,
                validator: validateWebsite,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.l),
              B2bTextField(
                key: const ValueKey('b2b_store_address'),
                label: AppStrings.b2bStoreAddressLabel,
                controller: _address,
                hint: AppStrings.b2bStoreAddressHint,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.b2bStoreContactPrivacy,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.l),
              B2bImageUploadField(
                kind: B2bMediaKind.shopLogo,
                label: 'Logo',
                currentUrl: _logoUrl,
                height: 120,
                onChanged: (u) => setState(() => _logoUrl = u),
              ),
              const SizedBox(height: AppSpacing.l),
              B2bImageUploadField(
                kind: B2bMediaKind.shopCover,
                label: 'Kapak görseli',
                currentUrl: _coverUrl,
                onChanged: (u) => setState(() => _coverUrl = u),
              ),
              const SizedBox(height: AppSpacing.xl),
              B2bSaveButton(
                label: _saving ? 'Kaydediliyor…' : 'Mağazayı kaydet',
                onTap: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
    return DirtyFormGuard(isDirty: _dirty, child: scaffold);
  }
}

/// S3 — mağaza formu doğrulayıcıları (test edilebilir, saf).
class SupplierStoreEditScreenValidators {
  const SupplierStoreEditScreenValidators._();

  /// Opsiyonel telefon: boş geçerli; doluysa en az 10 rakam.
  static String? phone(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length < 10 ? AppStrings.b2bPhoneInvalid : null;
  }

  /// Opsiyonel web: boş geçerli; doluysa nokta içeren host olmalı.
  static String? website(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final withScheme = t.startsWith('http://') || t.startsWith('https://')
        ? t
        : 'https://$t';
    final u = Uri.tryParse(withScheme);
    return (u == null || u.host.isEmpty || !u.host.contains('.'))
        ? AppStrings.b2bWebsiteInvalid
        : null;
  }
}
