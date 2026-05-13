import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/interactions.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/metric_pill.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/quick_action_tile.dart'
    show QuickActionTile, QuickActionMini;
import '../../../core/widgets/premium/section_label.dart';
import '../../dealers/providers/dealer_providers.dart';
import '../models/daily_summary.dart';
import '../providers/bakery_providers.dart';

class BakeryPanelScreen extends ConsumerWidget {
  const BakeryPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySummaryProvider);
    final df = DateFormat('d MMMM, EEEE', 'tr_TR');

    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            FirinNetHeader(
              title: AppStrings.panelTitle,
              subtitle: df.format(DateTime.now()),
              actions: [
                HeaderActionButton(
                  icon: Icons.calendar_month_outlined,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
              ),
              child: FadeSlideIn(child: _TodayHero(summary: summary)),
            ),
            // ───── Üretim Yönetimi
            const SectionLabel(title: 'Üretim Yönetimi'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: _ProductionActions(),
            ),
            // ───── Bayi Yönetimi
            const SectionLabel(title: 'Bayi Yönetimi'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
              ),
              child: _DealerSummaryCard(),
            ),
            // ───── Üretim son hareketleri
            const SectionLabel(
              title: AppStrings.panelSectionRecent,
              trailingLabel: AppStrings.panelTrailingDayEnd,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
              ),
              child: _RecentList(summary: summary),
            ),
            // ───── Topluluk
            const SectionLabel(title: AppStrings.panelSectionTips),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: _CommunityTips(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bugünün özeti kartı (üretim + bayi + fire net özet).
class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.summary});

  final AsyncValue<DailySummary> summary;

  @override
  Widget build(BuildContext context) {
    final data = summary.maybeWhen(data: (d) => d, orElse: () => null);
    final theme = Theme.of(context);

    final production = data?.totalProduction ?? 0;
    final delivered = data?.totalDelivered ?? 0;
    final waste = data?.totalWaste ?? 0;
    final net = data?.netAmount ?? 0;

    return Container(
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.copper.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  border: Border.all(
                    color: AppColors.copper.withValues(alpha: 0.32),
                    width: 0.6,
                  ),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.softGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  AppStrings.panelHeroLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.copper.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.copper.withValues(alpha: 0.32),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.softGold,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      AppStrings.panelHeroLive,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.softGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          AnimatedNumber(
            value: net,
            duration: const Duration(milliseconds: 720),
            builder: (context, v) => Text(
              NumberFormatter.currency(v),
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColors.softGold,
                fontWeight: FontWeight.w800,
                fontSize: 38,
                letterSpacing: -1.2,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.panelHeroSub,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MetricPill(
                label: 'Üretim',
                value: NumberFormatter.integer(production),
                color: AppColors.softGold,
              ),
              MetricPill(
                label: 'Bayi',
                value: NumberFormatter.integer(delivered),
                color: AppColors.success,
              ),
              MetricPill(
                label: 'Fire',
                value: NumberFormatter.integer(waste),
                color: AppColors.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Üretim Yönetimi: Reçete (featured) + 4 mini (Üretim, Fire, Gün Sonu, Rapor).
class _ProductionActions extends StatelessWidget {
  const _ProductionActions();

  static const _featured = _QuickItem(
    label: 'Reçeteler',
    subtitle: 'Hesap + malzeme + yapılış kütüphanen',
    icon: Icons.menu_book_outlined,
    route: AppRoutes.recipes,
  );

  static const _grid = <_QuickItem>[
    _QuickItem(
      label: 'Üretim Gir',
      subtitle: 'Günlük üretim kaydı',
      icon: Icons.bakery_dining_outlined,
      route: AppRoutes.production,
    ),
    _QuickItem(
      label: 'Fire Gir',
      subtitle: 'Kalan, iade, atık',
      icon: Icons.delete_sweep_outlined,
      route: AppRoutes.waste,
    ),
    _QuickItem(
      label: 'Gün Sonu',
      subtitle: 'Toplam üretim, bayi, fire',
      icon: Icons.nightlight_outlined,
      route: AppRoutes.endOfDay,
    ),
    _QuickItem(
      label: 'Rapor Al',
      subtitle: 'Paylaş veya kopyala',
      icon: Icons.share_outlined,
      route: AppRoutes.report,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        QuickActionTile(
          label: _featured.label,
          subtitle: _featured.subtitle,
          icon: _featured.icon,
          featured: true,
          onTap: () => GoRouter.of(context).push(_featured.route),
        ),
        const SizedBox(height: AppSpacing.m),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.s,
          crossAxisSpacing: AppSpacing.s,
          childAspectRatio: 1.55,
          children: [
            for (final item in _grid)
              QuickActionMini(
                label: item.label,
                icon: item.icon,
                onTap: () => GoRouter.of(context).push(item.route),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickItem {
  const _QuickItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final String route;
}

/// Bayi Yönetimi özet kartı: 4 metrik + büyük CTA.
class _DealerSummaryCard extends ConsumerWidget {
  const _DealerSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(dealersOverviewProvider);
    final theme = Theme.of(context);

    return PressScale(
      onTap: () => context.push(AppRoutes.dealers),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.elevatedCard,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.copper.withValues(alpha: 0.32),
            width: 0.8,
          ),
          boxShadow: AppShadow.copper,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: InkWell(
            onTap: () => context.push(AppRoutes.dealers),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            splashColor: AppColors.softGold.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color:
                              AppColors.copper.withValues(alpha: 0.18),
                          borderRadius:
                              BorderRadius.circular(AppRadius.s),
                          border: Border.all(
                            color: AppColors.copper
                                .withValues(alpha: 0.32),
                            width: 0.6,
                          ),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.softGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Text(
                          'Bayi defteri',
                          style:
                              theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.softGold,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.l),
                  overviewAsync.when(
                    loading: () => const SizedBox(
                      height: 80,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      ),
                    ),
                    error: (e, _) => Text(
                      'Özet okunamadı: $e',
                      style: const TextStyle(color: AppColors.danger),
                    ),
                    data: (o) => Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _DealerMetric(
                                label: 'Bayi',
                                value: '${o.activeDealers} / ${o.totalDealers}',
                                color: AppColors.softGold,
                              ),
                            ),
                            Expanded(
                              child: _DealerMetric(
                                label: 'Açık bakiye',
                                value:
                                    NumberFormatter.currency(o.openBalance),
                                color: AppColors.softGold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.m),
                        Row(
                          children: [
                            Expanded(
                              child: _DealerMetric(
                                label: 'Bugün teslim',
                                value: NumberFormatter.currency(
                                    o.todayDelivered),
                                color: AppColors.softGold,
                              ),
                            ),
                            Expanded(
                              child: _DealerMetric(
                                label: 'Bugün tahsilat',
                                value: NumberFormatter.currency(
                                    o.todayCollected),
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.dealers),
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                      label: const Text('Bayi Yönetimine Git'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.copper,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.m),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DealerMetric extends StatelessWidget {
  const _DealerMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 10.5,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.summary});

  final AsyncValue<DailySummary> summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = summary.maybeWhen(data: (d) => d, orElse: () => null);
    if (data == null || data.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.l,
          AppSpacing.l,
          AppSpacing.m,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.softGold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: AppColors.softGold,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.panelEmptyTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.panelEmptySub,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    GoRouter.of(context).push(AppRoutes.production),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(AppStrings.panelEmptyCta),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.softGold,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final p in data.production.take(2))
            _RecentRow(
              icon: Icons.bakery_dining_outlined,
              title: '${p.product} · ${p.quantity} adet',
              meta: 'Üretim',
              accent: AppColors.softGold,
            ),
          for (final d in data.deliveries.take(2))
            _RecentRow(
              icon: Icons.local_shipping_outlined,
              title: '${d.dealerName} · ${d.quantity} ${d.product}',
              meta: 'Bayi',
              accent: AppColors.success,
            ),
          for (final w in data.wastes.take(2))
            _RecentRow(
              icon: Icons.delete_sweep_outlined,
              title: '${w.product} · ${w.quantity} adet',
              meta: 'Fire',
              accent: AppColors.danger,
            ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.icon,
    required this.title,
    required this.meta,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String meta;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.m,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            meta,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sektörel mikro içerik kartları — veriden bağımsız, panel'e dolu his katar.
class _CommunityTips extends StatelessWidget {
  const _CommunityTips();

  static const _tips = <_TipCard>[
    _TipCard(
      icon: Icons.local_fire_department_rounded,
      accent: AppColors.softGold,
      label: 'Bugünün ipucu',
      title: 'Yaz aylarında maya %0.2 düşür',
      body:
          'Sıcakta hızlanan fermantasyon için maya oranını azaltıp '
          'fermantasyon süresini uzatmak hamur kontrolünü artırır.',
    ),
    _TipCard(
      icon: Icons.trending_up_rounded,
      accent: AppColors.success,
      label: 'Topluluktan',
      title: 'Bu hafta öne çıkan tedarikçi',
      body:
          'Konya Değirmen yeni hasat ekstra unu için 25 kg paketlerde '
          'avantajlı toplu alım açtı — Market\'ten inceleyebilirsin.',
    ),
    _TipCard(
      icon: Icons.event_note_outlined,
      accent: AppColors.info,
      label: 'Hatırlatma',
      title: 'Gün sonu kapanışı yapmadın',
      body:
          'Bugünün üretim, bayi ve fire toplamlarını kapatıp '
          'WhatsApp\'a gönderebileceğin tek raporu hazırla.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _tips.length; i++) ...[
          _tips[i],
          if (i != _tips.length - 1) const SizedBox(height: AppSpacing.s),
        ],
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.icon,
    required this.accent,
    required this.label,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
