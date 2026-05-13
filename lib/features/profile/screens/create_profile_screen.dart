import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_products.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/bakery_profile.dart';
import '../providers/profile_provider.dart';

class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  AccountType _accountType = AccountType.commercial;
  String _badge = RoleBadges.all.first;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    final displayName = _nameCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final auth = ref.read(authRepositoryProvider);

    // Local/mock mode — Supabase yapılandırılmadıysa eski davranış.
    if (auth == null) {
      ref.read(profileControllerProvider.notifier).save(
            BakeryProfile(
              displayName: displayName,
              accountType: _accountType,
              city: city,
              roleBadge: _badge,
              email: email,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.authProfileSavedSnack)),
      );
      context.go(AppRoutes.panel);
      return;
    }

    setState(() => _submitting = true);
    try {
      // Supabase signUp — handle_new_user triggerı profile satırını
      // otomatik oluşturur. Client `profiles` tablosuna INSERT etmez.
      await auth.signUp(
        email: email,
        password: password,
        metadata: <String, dynamic>{
          'display_name': displayName,
          'account_type': _accountType.name,
          'profession_badge': _badge,
          'city': city,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.authProfileCreatedSnack)),
      );
      context.go(AppRoutes.panel);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return AppStrings.authEmailRequired;
    if (!value.contains('@') || !value.contains('.')) {
      return AppStrings.authEmailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return AppStrings.authPasswordRequired;
    if (value.length < 6) return AppStrings.authPasswordTooShort;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabaseOn = ref.watch(authRepositoryProvider) != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.createProfile),
      ),
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
            Text(AppStrings.accountType, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _AccountTypePicker(
              selected: _accountType,
              onChanged: (t) => setState(() => _accountType = t),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: AppStrings.displayName,
                hintText: 'Örn. Hasan Usta',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Profil adı gerekli' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cityCtrl,
              decoration: const InputDecoration(
                labelText: AppStrings.city,
                hintText: 'Örn. Konya',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: AppStrings.email,
                hintText: AppStrings.authEmailHint,
                suffixIcon: Icon(Icons.mark_email_unread_outlined,
                    color: AppColors.textMuted),
              ),
              validator: supabaseOn ? _validateEmail : null,
            ),
            if (supabaseOn) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.password,
                  hintText: AppStrings.authPasswordHint,
                  suffixIcon: Icon(Icons.lock_outline,
                      color: AppColors.textMuted),
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
              children: RoleBadges.all.map((b) {
                final selected = _badge == b;
                return ChoiceChip(
                  label: Text(b),
                  selected: selected,
                  onSelected: (_) => setState(() => _badge = b),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            AppPrimaryButton(
              label: _submitting ? '…' : AppStrings.save,
              icon: Icons.check_rounded,
              onPressed: _submitting ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Üçlü hesap türü seçici — Ticari / Bireysel / Toptancı.
/// SegmentedButton 3 etiketle dar ekranlarda taşıyordu; tıklanabilir
/// kart grid'i kullanıcıya rolü daha net hissettiriyor.
class _AccountTypePicker extends StatelessWidget {
  const _AccountTypePicker({
    required this.selected,
    required this.onChanged,
  });

  final AccountType selected;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AccountTypeChip(
            icon: Icons.storefront_rounded,
            label: AppStrings.accountCommercial,
            isSelected: selected == AccountType.commercial,
            onTap: () => onChanged(AccountType.commercial),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AccountTypeChip(
            icon: Icons.person_rounded,
            label: AppStrings.accountIndividual,
            isSelected: selected == AccountType.individual,
            onTap: () => onChanged(AccountType.individual),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AccountTypeChip(
            icon: Icons.local_shipping_rounded,
            label: AppStrings.accountWholesaler,
            isSelected: selected == AccountType.wholesaler,
            onTap: () => onChanged(AccountType.wholesaler),
          ),
        ),
      ],
    );
  }
}

class _AccountTypeChip extends StatelessWidget {
  const _AccountTypeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.softGold;
    return Material(
      color: isSelected
          ? accent.withValues(alpha: 0.12)
          : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: AppSpacing.m,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(
              color: isSelected
                  ? accent.withValues(alpha: 0.55)
                  : AppColors.borderHairline,
              width: isSelected ? 1.0 : 0.6,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? accent : AppColors.textMuted,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
