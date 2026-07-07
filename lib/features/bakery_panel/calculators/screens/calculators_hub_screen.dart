import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/premium/premium_scaffold.dart';
import '../../../profile/models/bakery_profile.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../subscriptions/models/business_entitlements.dart';
import '../../../subscriptions/providers/subscription_providers.dart';
import '../../../subscriptions/widgets/paywall_sheet.dart';
import '../models/calculator_category.dart';
import '../models/calculator_tool.dart';
import '../registry/calculator_entitlements.dart';
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
    // Ticari kullanıcı için plan kilidi; bireysel/toptancıda kilit yok.
    final isCommercial = account == AccountType.commercial;
    final entitlements = isCommercial
        ? ref.watch(myEntitlementProvider).valueOrNull
        : null;

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
                    _ToolGrid(
                      tools: featured,
                      keyPrefix: 'featured',
                      entitlements: entitlements,
                      isCommercial: isCommercial,
                    ),
                  ],
                  for (var g = 0; g < groups.length; g++) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _SectionHeader(
                      icon: groups[g].category.icon,
                      title: groups[g].category.title,
                      count: groups[g].tools.length,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _ToolGrid(
                      tools: groups[g].tools,
                      keyPrefix: 'tool',
                      entitlements: entitlements,
                      isCommercial: isCommercial,
                    ),
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

/// 2 kolonlu kompakt araç ızgarası. Satır yüksekliği kullanıcının yazı
/// ölçeğiyle kontrollü büyür (aşağıda [_mainAxisExtent]); kart içindeki
/// Flexible metinler dar ekranda taşmaya karşı yedek korumadır. Kart
/// dokunuşu aracın mevcut route'una gider (registry'de tanımlı, değişmez).
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({
    required this.tools,
    required this.keyPrefix,
    required this.entitlements,
    required this.isCommercial,
  });

  final List<CalculatorTool> tools;
  final String keyPrefix;
  final BusinessEntitlements? entitlements;
  final bool isCommercial;

  /// Izgara satır yüksekliği. 1.0x yazı ölçeğinde birebir eski değer (142);
  /// büyük yazı ölçeğinde yalnız kartın metin alanı büyür, ikon şeridi ve
  /// boşluklar sabit kalır. Böylece 1.3x'te başlığın ikinci satırı alttan
  /// kırpılmaz; erişilebilirlik ölçeği korunur, aşırı büyümede tavan var.
  ///
  /// Önemli: ölçekleme blok yüksekliğiyle DEĞİL, karttaki gerçek font
  /// boyutlarıyla (başlık 13.5 / açıklama 11.5) yapılır — Android 14+
  /// non-linear font scaling büyük değerleri neredeyse hiç büyütmediği
  /// için `scale(<blok yüksekliği>)` cihazda yanlış (küçük) sonuç verir.
  static double _mainAxisExtent(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // CalculatorMiniCard metin stilleriyle birebir: 2 satır başlık
    // (13.5, height 1.2) + 2 satır açıklama (11.5, height 1.25).
    final titleBlock = scaler.scale(13.5) * 1.2 * 2;
    final descBlock = scaler.scale(11.5) * 1.25 * 2;
    // 1.0x'te metin bloğu ≈ 61.2 → sabit kısım 142 - 61.2 = 80.8
    // (padding + ikon şeridi + aralıklar + nefes payı).
    const fixedPart = 80.8;
    return (fixedPart + titleBlock + descBlock).clamp(142.0, 220.0);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: _mainAxisExtent(context),
      ),
      itemCount: tools.length,
      itemBuilder: (context, i) {
        final tool = tools[i];
        // Kilit yalnız ticari + entitlement yüklü + araç plan üstündeyse.
        final lock = entitlements == null
            ? null
            : CalculatorEntitlements.lockFor(
                toolId: tool.id,
                entitlements: entitlements!,
                isCommercial: isCommercial,
              );
        return CalculatorMiniCard(
          key: ValueKey('${keyPrefix}_${tool.id}'),
          title: tool.title,
          subtitle: tool.description,
          icon: tool.icon,
          lockedTag: lock?.requiredPlanTag,
          onTap: lock != null
              ? () => showPaywallSheet(context, lock)
              : () => context.push(tool.route),
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
