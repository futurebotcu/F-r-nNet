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
import '../models/calculator_tool.dart';
import '../registry/calculator_tools_registry.dart';
import '../widgets/calculator_mini_card.dart';

/// Hesaplama merkezi — `/calculator` route'unun kök ekranı.
///
/// Kullanıcının hesap türünü okur ve araçları [CalculatorToolsRegistry]
/// üzerinden çizer: üstte rol-bazlı "Bugün lazım olur" kısayolları, altında
/// role-sıralı kategori bölümleri (2 kolonlu kompakt ızgara). Sıralama,
/// kısayol ve kategori kararları registry'de tek noktada yönetilir; ekran
/// rolü hard-code etmez. Rolün aracı yoksa sade boş durum gösterilir.
class CalculatorsHubScreen extends ConsumerWidget {
  const CalculatorsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final account = profile?.accountType ?? AccountType.individual;
    final groups = CalculatorToolsRegistry.groupedForAccount(account);
    final featured = CalculatorToolsRegistry.featuredForAccount(account);

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
                  if (featured.isNotEmpty) ...[
                    const _SectionHeader(
                      icon: Icons.bolt_rounded,
                      title: AppStrings.calcHubFeaturedTitle,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _ToolGrid(tools: featured, keyPrefix: 'featured'),
                  ],
                  for (var g = 0; g < groups.length; g++) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _SectionHeader(
                      icon: groups[g].category.icon,
                      title: groups[g].category.title,
                      count: groups[g].tools.length,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _ToolGrid(tools: groups[g].tools, keyPrefix: 'tool'),
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

/// Bölüm başlığı: limon zeminli küçük ikon + kalın başlık + opsiyonel
/// araç sayacı ("6 araç"). Kısayol ve kategori bölümleri aynı dili konuşur.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, this.count});

  final IconData icon;
  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.brandLemonPale,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: AppColors.brandLemonPressed.withValues(alpha: 0.28),
              width: 0.7,
            ),
          ),
          child: Icon(icon, size: 15, color: AppColors.brandInk),
        ),
        const SizedBox(width: AppSpacing.s),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: -0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.s),
          Text(
            '$count ${AppStrings.calcHubToolCountSuffix}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

/// 2 kolonlu kompakt araç ızgarası. Sabit satır yüksekliği + kart içinde
/// Flexible metinler 320dp dar ekranda taşmayı engeller. Kart dokunuşu
/// aracın mevcut route'una gider (route registry'de tanımlı, değişmez).
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.tools, required this.keyPrefix});

  final List<CalculatorTool> tools;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 142,
      ),
      itemCount: tools.length,
      itemBuilder: (context, i) {
        final tool = tools[i];
        return CalculatorMiniCard(
          key: ValueKey('${keyPrefix}_${tool.id}'),
          title: tool.title,
          subtitle: tool.description,
          icon: tool.icon,
          onTap: () => context.push(tool.route),
        );
      },
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
