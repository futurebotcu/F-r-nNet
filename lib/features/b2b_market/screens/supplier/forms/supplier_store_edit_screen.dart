// B2B Pazar — Tedarikçi > mağaza (vitrin) düzenleme formu (mock).
//
// Mağazam içinden "Mağazanı düzenle" ile açılır. Bu B2B mağaza AYRI ticari
// vitrindir; mevcut FırınNet profili / AccountType / auth / Supabase
// DEĞİŞTİRİLMEZ. Kaydet → in-memory mock store güncellenir, Mağazam yansır.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/widgets/premium/premium_scaffold.dart';
import '../../../../../core/widgets/premium/premium_top_banner.dart';
import '../../../providers/b2b_providers.dart';
import '../../../widgets/b2b_form_field.dart';
import '../../../widgets/b2b_media_picker_field.dart';

class SupplierStoreEditScreen extends ConsumerStatefulWidget {
  const SupplierStoreEditScreen({super.key});

  @override
  ConsumerState<SupplierStoreEditScreen> createState() =>
      _SupplierStoreEditScreenState();
}

class _SupplierStoreEditScreenState
    extends ConsumerState<SupplierStoreEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final Set<String> _regions;
  late final Set<String> _categories;
  String? _coverKey;

  @override
  void initState() {
    super.initState();
    final store = ref.read(b2bRepositoryProvider).myStore();
    _name = TextEditingController(text: store.name);
    _description = TextEditingController(text: store.description);
    _regions = <String>{...store.serviceRegions};
    _categories = <String>{...store.categories};
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(b2bMarketControllerProvider.notifier).updateStore(
          name: _name.text.trim(),
          description: _description.text.trim(),
          serviceRegions: _regions.toList(),
          categories: _categories.toList(),
        );

    Navigator.of(context).pop();
    PremiumTopBannerController.show(
      context,
      title: 'Mağaza güncellendi',
      message: 'Vitrin bilgilerin Mağazam\'da güncellendi.',
      tone: PremiumTopBannerTone.success,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regionOptions = ref.read(b2bRepositoryProvider).serviceRegions();
    final categoryOptions = ref.read(b2bRepositoryProvider).productCategories();

    return PremiumScaffold(
      appBar: AppBar(title: const Text('Mağazanı düzenle')),
      body: SafeArea(
        child: Form(
          key: _formKey,
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
              B2bMediaPickerField(
                label: 'Kapak / logo',
                selectedKey: _coverKey,
                onSelect: (k) => setState(() => _coverKey = k),
              ),
              const SizedBox(height: AppSpacing.xl),
              B2bSaveButton(label: 'Mağazayı kaydet', onTap: _save),
            ],
          ),
        ),
      ),
    );
  }
}
