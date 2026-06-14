import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../providers/auth_providers.dart';

/// V1.3.5 — Şifre sıfırlama linki talep ekranı.
///
/// `auth.resetPasswordForEmail(email)` çağrısını başlatır; Supabase
/// kullanıcının e-postasına şifre yenileme linki gönderir. Link tıklanınca
/// Supabase varsayılan web sayfasına gider; kullanıcı orada yeni şifresini
/// belirler. Mobile in-app yeni şifre belirleme akışı sonraki faza bırakıldı.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _submitting = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
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

  Future<void> _submit() async {
    final auth = ref.read(authRepositoryProvider);
    if (auth == null) return;
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await auth.resetPasswordForEmail(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _sent = true;
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.authForgotPasswordSent)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.authForgotPasswordFail)),
      );
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
              // Google-only: email login yerine auth giriş ekranına dön.
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
                    Icons.lock_reset_rounded,
                    color: AppColors.surface,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                AppStrings.authForgotPasswordTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                AppStrings.authForgotPasswordHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
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
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.softGold,
                        size: 18,
                      ),
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
                enabled: supabaseOn && !_submitting && !_sent,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: AppStrings.email,
                  hintText: AppStrings.authEmailHint,
                  prefixIcon: Icon(
                    Icons.mail_outline,
                    color: AppColors.textMuted,
                  ),
                ),
                validator: supabaseOn ? _validateEmail : null,
              ),
              const SizedBox(height: AppSpacing.l),
              if (_sent)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.mark_email_read_outlined,
                        color: AppColors.success,
                        size: 22,
                      ),
                      SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Text(
                          AppStrings.authForgotPasswordSent,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                AppPrimaryButton(
                  label: _submitting
                      ? '…'
                      : AppStrings.authForgotPasswordSubmit,
                  icon: Icons.send_rounded,
                  onPressed: (supabaseOn && !_submitting) ? _submit : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
