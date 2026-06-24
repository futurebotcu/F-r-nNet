import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/premium/premium_scaffold.dart';
import '../../../../core/widgets/premium/quick_action_tile.dart';
import '../../../profile/models/bakery_profile.dart';
import '../../../profile/providers/profile_provider.dart';
import '../registry/calculator_tools_registry.dart';

/// Hesaplama merkezi — `/calculator` route'unun yeni kök ekranı.
///
/// Kullanıcının hesap türünü okur ve [CalculatorToolsRegistry] üzerinden
/// role görünür araçları listeler. Araç listesi tek noktadan (registry)
/// yönetilir; ekran rolü hard-code etmez. Kritik veri olmadığı için route
/// ayrı bir DB guard'ı gerektirmez — rolün aracı yoksa sade boş durum.
class CalculatorsHubScreen extends ConsumerWidget {
  const CalculatorsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final account = profile?.accountType ?? AccountType.individual;
    final tools = CalculatorToolsRegistry.forAccount(account);

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.calcHubTitle)),
      body: SafeArea(
        child: tools.isEmpty
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  AppSpacing.m,
                  AppSpacing.pageH,
                  AppSpacing.xxl,
                ),
                children: [
                  for (var i = 0; i < tools.length; i++) ...[
                    QuickActionTile(
                      label: tools[i].title,
                      subtitle: tools[i].description,
                      icon: tools[i].icon,
                      featured: i == 0,
                      onTap: () => context.push(tools[i].route),
                    ),
                    if (i != tools.length - 1)
                      const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.calculate_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
            SizedBox(height: AppSpacing.m),
            Text(
              AppStrings.calcHubEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
