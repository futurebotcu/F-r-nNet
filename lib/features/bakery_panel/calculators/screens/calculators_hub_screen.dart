import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/premium/premium_scaffold.dart';
import '../../../profile/models/bakery_profile.dart';
import '../../../profile/providers/profile_provider.dart';
import '../models/calculator_category.dart';
import '../registry/calculator_tools_registry.dart';
import '../widgets/calculator_tool_card.dart';

/// Hesaplama merkezi — `/calculator` route'unun kök ekranı.
///
/// Kullanıcının hesap türünü okur ve araçları [CalculatorToolsRegistry]
/// üzerinden kategori bölümlerine ayırıp role-sıralı listeler (en sık
/// kullanılan grup üstte). Sıralama/kategori kararları registry'de tek
/// noktada yönetilir; ekran rolü hard-code etmez. Rolün aracı yoksa sade
/// boş durum gösterilir.
class CalculatorsHubScreen extends ConsumerWidget {
  const CalculatorsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final account = profile?.accountType ?? AccountType.individual;
    final groups = CalculatorToolsRegistry.groupedForAccount(account);

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.calcHubTitle)),
      body: SafeArea(
        child: groups.isEmpty
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  AppSpacing.m,
                  AppSpacing.pageH,
                  AppSpacing.xxl,
                ),
                children: [
                  const _OfflineNote(),
                  const SizedBox(height: AppSpacing.l),
                  for (var g = 0; g < groups.length; g++) ...[
                    if (g != 0) const SizedBox(height: AppSpacing.xl),
                    _SectionHeader(title: groups[g].category.title),
                    const SizedBox(height: AppSpacing.s),
                    for (var i = 0; i < groups[g].tools.length; i++) ...[
                      CalculatorToolCard(
                        title: groups[g].tools[i].title,
                        subtitle: groups[g].tools[i].description,
                        icon: groups[g].tools[i].icon,
                        onTap: () => context.push(groups[g].tools[i].route),
                      ),
                      if (i != groups[g].tools.length - 1)
                        const SizedBox(height: AppSpacing.s),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

/// Üstte tek satırlık "tüm hesaplar internetsiz çalışır" notu.
class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.cloud_off_rounded, size: 15, color: AppColors.textMuted),
        SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            AppStrings.calcHubOfflineNote,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    // Daha okunur bölüm başlığı: solda ince softGold ayırıcı + daha büyük
    // koyu metin. Kategori hızlı taramada net ayrışır; tasarım sistemine
    // sadık (QuickActionTile'ın featured accent bar diliyle aynı).
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 0),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.softGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              letterSpacing: -0.1,
            ),
          ),
        ],
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
