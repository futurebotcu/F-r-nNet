import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/metric_pill.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/guest_mode_provider.dart';
import '../../bakery_panel/models/recipe_record.dart';
import '../../bakery_panel/providers/bakery_providers.dart';
import '../../bakery_panel/screens/recipe_visibility_badge.dart';
import '../models/bakery_profile.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);

    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: profile == null
            ? EmptyState(
                title: 'Profil yok',
                subtitle:
                    'Onboarding üzerinden profil oluştur veya misafir olarak devam et.',
                icon: Icons.person_outline_rounded,
                actionLabel: 'Profil oluştur',
                onAction: () => context.push(AppRoutes.createProfile),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  const FirinNetHeader(title: 'Profil', showLogo: false),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageH,
                    ),
                    child: _ProfileHero(profile: profile),
                  ),
                  const SectionLabel(title: 'İstatistikler'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageH,
                    ),
                    child: const _Stats(),
                  ),
                  SectionLabel(
                    title: 'Açık Reçeteler',
                    trailingLabel: 'Tüm reçetelerim',
                    onTrailingTap: () => context.push(AppRoutes.recipes),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageH,
                    ),
                    child: _PublicRecipesSection(),
                  ),
                  const SectionLabel(title: 'Hesap'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageH,
                    ),
                    child: _AccountList(profile: profile),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageH,
                    ),
                    child: SizedBox(
                      height: 50,
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.textMuted,
                        ),
                        label: const Text(
                          'Profilden Çık',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        onPressed: () async {
                          // V1.3 logout flow:
                          // 1. Supabase oturumu varsa server-side signOut
                          // 2. Guest flag temizle (persistent)
                          // 3. Profile Riverpod state'i temizle
                          // 4. Auth Entry ekranına dön
                          final auth = ref.read(authRepositoryProvider);
                          if (auth != null) {
                            try {
                              await auth.signOut();
                            } catch (_) {
                              // Ağ kopuksa bile local state'i temizleyelim.
                            }
                          }
                          await ref
                              .read(guestModeProvider.notifier)
                              .setGuest(false);
                          if (!context.mounted) return;
                          ref
                              .read(profileControllerProvider.notifier)
                              .clear();
                          context.go(AppRoutes.authEntry);
                        },
                      ),
                    ),
                  ),
                  // V1 P0 — KVKK / Play account-deletion compliance.
                  // 2-aşamalı confirmation arkasında çalışan kalıcı hesap
                  // silme butonu. service_role kullanılmaz; çağrı
                  // `delete-account` Edge Function üzerinden gider.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      AppSpacing.s,
                      AppSpacing.pageH,
                      AppSpacing.l,
                    ),
                    child: SizedBox(
                      height: 50,
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          color: AppColors.danger,
                        ),
                        label: const Text(
                          AppStrings.accountDeleteCta,
                          style: TextStyle(color: AppColors.danger),
                        ),
                        onPressed: () =>
                            _onDeleteAccountPressed(context, ref),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _onDeleteAccountPressed(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (!AppConfig.supabaseEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.accountDeleteUnsupportedOffline),
        ),
      );
      return;
    }
    final auth = ref.read(authRepositoryProvider);
    final user = ref.read(currentAuthUserProvider);
    if (auth == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.accountDeleteRequireAuth)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountConfirmDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    // Loading dialog (dismissable değil).
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountLoading(),
    );

    try {
      await auth.deleteAccount();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      await ref.read(guestModeProvider.notifier).setGuest(false);
      if (!context.mounted) return;
      ref.read(profileControllerProvider.notifier).clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.accountDeleteSuccessSnack)),
      );
      context.go(AppRoutes.authEntry);
    } catch (_) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.accountDeleteErrorGeneric),
          ),
        );
      }
    }
  }
}

/// 2-step confirmation: "HESABIMI SİL" yazılana kadar kalıcı sil butonu
/// disabled. Body'de net data-loss açıklaması.
class _DeleteAccountConfirmDialog extends StatefulWidget {
  const _DeleteAccountConfirmDialog();

  @override
  State<_DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends State<_DeleteAccountConfirmDialog> {
  final _ctrl = TextEditingController();
  bool _enabled = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final ok = value.trim().toUpperCase() ==
        AppStrings.accountDeleteConfirmKeyword;
    if (ok != _enabled) {
      setState(() => _enabled = ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.elevatedCard,
      title: const Text(AppStrings.accountDeleteConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.accountDeleteConfirmBody,
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            AppStrings.accountDeleteConfirmFieldLabel,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              hintText: AppStrings.accountDeleteConfirmFieldHint,
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.accountDeleteCancel),
        ),
        FilledButton(
          onPressed:
              _enabled ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text(AppStrings.accountDeleteConfirmButton),
        ),
      ],
    );
  }
}

class _DeleteAccountLoading extends StatelessWidget {
  const _DeleteAccountLoading();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.elevatedCard,
      content: Row(
        children: const [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.m),
          Expanded(child: Text(AppStrings.accountDeleteLoading)),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});
  final BakeryProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountLabel = profile.accountType.label;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroFrom, AppColors.heroTo],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.copper.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: AppShadow.heroGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.softGold, AppColors.copperMuted],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.copper.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  profile.displayName.isNotEmpty
                      ? profile.displayName[0].toUpperCase()
                      : 'F',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 21,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.roleBadge,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.softGold,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MetricPill(
                label: 'Hesap',
                value: accountLabel,
              ),
              if (profile.city.isNotEmpty)
                MetricPill(
                  label: 'Şehir',
                  value: profile.city,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.l,
      ),
      child: Row(
        children: const [
          _StatCol(value: '12', label: 'Paylaşım'),
          _Divider(),
          _StatCol(value: '186', label: 'Bağlantı'),
          _Divider(),
          _StatCol(value: '4', label: 'Yıl'),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: AppColors.surfaceLine);
}

class _AccountList extends StatelessWidget {
  const _AccountList({required this.profile});
  final BakeryProfile profile;

  @override
  Widget build(BuildContext context) {
    final items = <_Item>[
      _Item(
        Icons.business_outlined,
        'İşletme Bilgileri',
        '${profile.accountType.label} hesap',
      ),
      _Item(
        Icons.bakery_dining_outlined,
        'Ürünlerim',
        'Vitrin & paylaşımlar',
      ),
      _Item(
        Icons.summarize_outlined,
        'Raporlarım',
        'Geçmiş gün sonu özetleri',
      ),
      _Item(
        Icons.mail_outline_rounded,
        'E-posta',
        profile.email.isEmpty ? 'Belirtilmemiş' : profile.email,
      ),
      _Item(
        Icons.settings_outlined,
        'Ayarlar',
        'Bildirim, dil, gizlilik',
      ),
    ];
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _AccountTile(item: items[i]),
            if (i != items.length - 1)
              const Divider(
                height: 0,
                indent: 60,
                endIndent: AppSpacing.l,
              ),
          ],
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.item});
  final _Item item;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.softGold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
        child: Icon(item.icon, color: AppColors.softGold, size: 18),
      ),
      title: Text(
        item.title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        item.subtitle,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12.5,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
      onTap: () {},
    );
  }
}

class _Item {
  const _Item(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

/// Profilde "Açık Reçeteler" bölümü — yalnız `is_public = true` reçeteler.
///
/// Sahip kendi profilini görüyor; başka kullanıcının profili ekranı şu an
/// uygulamada yok. Bu yüzden listelenen ownerId daima current user.
class _PublicRecipesSection extends ConsumerWidget {
  const _PublicRecipesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAuthUserProvider);
    final ownerKey = user?.id ?? 'local';
    final async = ref.watch(publicRecipesByOwnerProvider(ownerKey));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
        child: Center(child: CircularProgressIndicator(strokeWidth: 1.4)),
      ),
      error: (e, _) => PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Text(
          'Açık reçeteler okunamadı: $e',
          style: const TextStyle(color: AppColors.danger, fontSize: 13),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return PremiumCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            onTap: () => context.push(AppRoutes.recipes),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.softGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  child: const Icon(
                    Icons.public_off_outlined,
                    color: AppColors.softGold,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                const Expanded(
                  child: Text(
                    'Henüz profilinde açık reçete yok. '
                    'Bir reçeteyi düzenleyip "Profilimde görünsün" seç.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          );
        }
        return PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _PublicRecipeRow(recipe: items[i]),
                if (i != items.length - 1)
                  const Divider(
                    height: 0,
                    indent: AppSpacing.l,
                    endIndent: AppSpacing.l,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PublicRecipeRow extends StatelessWidget {
  const _PublicRecipeRow({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 4),
      onTap: () => context.push('${AppRoutes.recipes}/${recipe.id}'),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.copper.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
        child: const Icon(
          Icons.menu_book_rounded,
          color: AppColors.softGold,
          size: 18,
        ),
      ),
      title: Text(
        recipe.displayTitle,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            const VisibilityBadge(visibility: RecipeVisibility.public),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${recipe.quantities.flourKg.toStringAsFixed(0)} kg un · '
                '${recipe.result.estimatedPieces} adet',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
    );
  }
}
