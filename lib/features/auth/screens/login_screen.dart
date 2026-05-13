import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../providers/auth_providers.dart';
import '../providers/guest_mode_provider.dart';

/// Sade giriş ekranı (V1.3).
///
/// Auth Entry'den push edilir; iki aksiyon:
/// - **Giriş Yap** (`signInWithPassword`) → başarılıysa splash redirect mantığı
///   profili kontrol edip `/panel` veya `/profile/create`'e götürür.
/// - **Hesabın yok mu? Üye ol** → `/auth/role-select`.
///
/// "Kayıtsız Devam Et" buradan kaldırıldı — boot landing'inde (AuthEntry).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
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
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return AppStrings.authPasswordRequired;
    return null;
  }

  Future<void> _signIn() async {
    final auth = ref.read(authRepositoryProvider);
    if (auth == null) return;
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await auth.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // Başarılı giriş → guest flag temizlenir (auth varsa guest olmamalı).
      await ref.read(guestModeProvider.notifier).setGuest(false);
      if (!mounted) return;
      // Splash, profile completeness'i yeniden değerlendirip rotalayacak.
      context.go(AppRoutes.splash);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabaseOn = ref.watch(authRepositoryProvider) != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.authEntry);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.s,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.copper, AppColors.copperMuted],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                AppStrings.authLoginTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.appPitch,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!supabaseOn)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  margin: const EdgeInsets.only(bottom: AppSpacing.l),
                  decoration: BoxDecoration(
                    color: AppColors.softGold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(
                      color: AppColors.softGold.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.softGold, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.authBackendDisabled,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: _emailCtrl,
                enabled: supabaseOn && !_submitting,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: AppStrings.email,
                  hintText: AppStrings.authEmailHint,
                  prefixIcon: Icon(Icons.mail_outline,
                      color: AppColors.textMuted),
                ),
                validator: supabaseOn ? _validateEmail : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                enabled: supabaseOn && !_submitting,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.password,
                  prefixIcon: Icon(Icons.lock_outline,
                      color: AppColors.textMuted),
                ),
                validator: supabaseOn ? _validatePassword : null,
              ),
              const SizedBox(height: AppSpacing.l),
              AppPrimaryButton(
                label: _submitting ? '…' : AppStrings.authSignInButton,
                icon: Icons.login_rounded,
                onPressed: (supabaseOn && !_submitting) ? _signIn : null,
              ),
              const SizedBox(height: AppSpacing.s),
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => context.push(AppRoutes.roleSelect),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.softGold,
                  ),
                  child: const Text(
                    AppStrings.authLoginNoAccountQ,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
