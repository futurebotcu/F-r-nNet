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
    show QuickActionMini;
import '../../../core/widgets/premium/section_label.dart';
import '../models/bakery_day_book.dart';
import '../models/bakery_task.dart';
import '../models/daily_summary.dart';
import '../models/waste_entry.dart';
import '../providers/bakery_providers.dart';
import '../widgets/ledger_revenue_sheet.dart';

/// Fırın Defteri — fırıncının günlük operasyon mini app'i.
///
/// "Bugün ne ürettim, ne kadar fire verdim, ne kadar ciro yazdım, bugün
/// hangi işlerim var, günü kapattım mı?" tek ekranda. GİDER/FİNANS BURADA
/// DEĞİLDİR — Borç & Gider ve Bayi Defteri kendi menülerinde kalır; buradan
/// yalnız yönlendirme linki verilir.
class BakeryPanelScreen extends ConsumerWidget {
  const BakeryPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySummaryProvider);
    final dayBook = ref.watch(todayDayBookProvider);
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
              title: AppStrings.ledgerTitle,
              subtitle: df.format(DateTime.now()),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: FadeSlideIn(
                child: _TodayHero(
                  summary: summary,
                  dayBook: dayBook.valueOrNull,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: _SmartChips(
                summary: summary.valueOrNull,
                dayBook: dayBook.valueOrNull,
              ),
            ),
            // ───── Hızlı girişler
            const SectionLabel(title: AppStrings.ledgerQuickSection),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: _QuickEntries(),
            ),
            // ───── Bugün ne yapacağım?
            const SectionLabel(title: AppStrings.ledgerTasksSection),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: _TasksCard(),
            ),
            // ───── Son kayıtlar
            const SectionLabel(title: AppStrings.ledgerRecentSection),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: _RecentList(
                summary: summary,
                dayBook: dayBook.valueOrNull,
              ),
            ),
            // ───── Gider/bayi ayrımı: yalnız yönlendirme (form YOK).
            const SizedBox(height: AppSpacing.m),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: _OtherBooksLinks(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bugün kartı: ciro + üretim/fire/fire oranı + gün durumu + not önizleme.
class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.summary, required this.dayBook});

  final AsyncValue<DailySummary> summary;
  final BakeryDayBook? dayBook;

  @override
  Widget build(BuildContext context) {
    // Perf sözleşmesi (Instant UX): mutasyon sonrası reload'da spinner/sıfır
    // flash'ı atılmaz — önceki değer korunur.
    final data = summary.when(
      skipLoadingOnReload: true,
      data: (d) => d,
      loading: () => null,
      error: (_, __) => null,
    );
    final theme = Theme.of(context);

    final production = data?.totalProduction ?? 0;
    final waste = data?.totalWaste ?? 0;
    final ratio = data?.wasteRatio;
    final revenue = dayBook?.revenueAmount;
    final closed = dayBook?.isClosed ?? false;
    final note = dayBook?.dayNote ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.card,
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  boxShadow: AppShadow.card,
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
              _DayStatusBadge(closed: closed),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            revenue == null ? '₺ —' : NumberFormatter.currency(revenue),
            style: theme.textTheme.displaySmall?.copyWith(
              color: AppColors.softGold,
              fontWeight: FontWeight.w800,
              fontSize: 38,
              letterSpacing: -1.2,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.ledgerEodRevenue,
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
                label: AppStrings.ledgerEodProduction,
                value: NumberFormatter.integer(production),
                color: AppColors.primary,
              ),
              MetricPill(
                label: AppStrings.ledgerEodWaste,
                value: NumberFormatter.integer(waste),
                color: const Color(0xFFEF4444),
              ),
              MetricPill(
                label: AppStrings.ledgerEodWasteRatio,
                value: ratio == null
                    ? '—'
                    : '%${(ratio * 100).toStringAsFixed(1)}',
                color: const Color(0xFFB45309),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sticky_note_2_outlined,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DayStatusBadge extends StatelessWidget {
  const _DayStatusBadge({required this.closed});

  final bool closed;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = closed
        ? (
            AppStrings.ledgerDayClosed,
            const Color(0xFFF3FBEF),
            const Color(0xFF166534),
          )
        : (
            AppStrings.ledgerDayOpen,
            AppColors.surfaceVariant,
            AppColors.textSecondary,
          );
    return Container(
      key: ValueKey('ledger_day_status_${closed ? 'closed' : 'open'}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

/// Deterministik akıllı özet chip'leri (AI yok).
class _SmartChips extends StatelessWidget {
  const _SmartChips({required this.summary, required this.dayBook});

  final DailySummary? summary;
  final BakeryDayBook? dayBook;

  static List<String> chipsFor(DailySummary? s, BakeryDayBook? book) {
    if (s == null) return const [];
    final chips = <String>[];
    final ratio = s.wasteRatio;
    if (s.totalProduction == 0) chips.add(AppStrings.ledgerChipNoProduction);
    if (book?.revenueAmount == null) chips.add(AppStrings.ledgerChipNoRevenue);
    if (ratio != null && ratio > 0.10) {
      chips.add(AppStrings.ledgerChipHighWaste);
    }
    if (!(book?.isClosed ?? false)) chips.add(AppStrings.ledgerChipDayOpen);
    if (chips.isEmpty) chips.add(AppStrings.ledgerChipAllGood);
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final chips = chipsFor(summary, dayBook);
    if (chips.isEmpty) return const SizedBox.shrink();
    final allGood =
        chips.length == 1 && chips.first == AppStrings.ledgerChipAllGood;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: allGood
                  ? const Color(0xFFF3FBEF)
                  : AppColors.brandLemonPale,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              c,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: allGood ? const Color(0xFF166534) : AppColors.brandInk,
              ),
            ),
          ),
      ],
    );
  }
}

/// 6 hızlı giriş: Üretim / Fire / Ciro / Not / İş / Gün sonu.
class _QuickEntries extends ConsumerWidget {
  const _QuickEntries();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // GridView yerine Wrap: kart yüksekliği içeriğe uyar → 320dp + 1.3x
    // yazı ölçeğinde sabit aspect-ratio taşması yaşanmaz (3 sütun).
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.s;
        final cellWidth = (constraints.maxWidth - 2 * spacing) / 3;
        final items = <(String, IconData, VoidCallback)>[
          (
            AppStrings.ledgerQuickProduction,
            Icons.bakery_dining_outlined,
            () => GoRouter.of(context).push(AppRoutes.production),
          ),
          (
            AppStrings.ledgerQuickWaste,
            Icons.delete_sweep_outlined,
            () => GoRouter.of(context).push(AppRoutes.waste),
          ),
          (
            AppStrings.ledgerQuickRevenue,
            Icons.payments_outlined,
            () => showLedgerRevenueSheet(context, ref),
          ),
          (
            AppStrings.ledgerQuickNote,
            Icons.sticky_note_2_outlined,
            () => showLedgerRevenueSheet(context, ref, focusNote: true),
          ),
          (
            AppStrings.ledgerQuickTask,
            Icons.add_task_rounded,
            () => showLedgerTaskSheet(context, ref),
          ),
          (
            AppStrings.ledgerQuickEndOfDay,
            Icons.nightlight_outlined,
            () => GoRouter.of(context).push(AppRoutes.endOfDay),
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final (label, icon, onTap) in items)
              SizedBox(
                width: cellWidth,
                child: QuickActionMini(label: label, icon: icon, onTap: onTap),
              ),
          ],
        );
      },
    );
  }
}

/// "Bugün ne yapacağım?" — görev listesi + öneri chip'leri.
class _TasksCard extends ConsumerWidget {
  const _TasksCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(todayTasksProvider).valueOrNull ?? const [];
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tasks.isEmpty) ...[
            const Text(
              AppStrings.ledgerTasksEmpty,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in kBakeryTaskSuggestions)
                  ActionChip(
                    key: ValueKey('ledger_suggestion_$s'),
                    label: Text(s),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    onPressed: () async {
                      await ref
                          .read(bakeryRepositoryProvider)
                          .addTask(day: DateTime.now(), title: s);
                    },
                  ),
              ],
            ),
          ] else ...[
            for (final t in tasks) _TaskRow(task: t),
          ],
          const SizedBox(height: AppSpacing.s),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('ledger_task_add'),
              onPressed: () => showLedgerTaskSheet(context, ref),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(AppStrings.ledgerQuickTask),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task});

  final BakeryTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Checkbox(
              key: ValueKey('ledger_task_done_${task.id}'),
              value: task.isDone,
              onChanged: (v) => ref
                  .read(bakeryRepositoryProvider)
                  .setTaskDone(task.id, v ?? false),
              activeColor: AppColors.softGold,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: task.isDone
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                decoration: task.isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          IconButton(
            key: ValueKey('ledger_task_delete_${task.id}'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
            onPressed: () =>
                ref.read(bakeryRepositoryProvider).deleteTask(task.id),
          ),
        ],
      ),
    );
  }
}

/// Bugünün son kayıtları — üretim + fire + ciro/not güncellemesi.
class _RecentList extends StatelessWidget {
  const _RecentList({required this.summary, required this.dayBook});

  final AsyncValue<DailySummary> summary;
  final BakeryDayBook? dayBook;

  @override
  Widget build(BuildContext context) {
    final data = summary.when(
      skipLoadingOnReload: true,
      data: (d) => d,
      loading: () => null,
      error: (_, __) => null,
    );
    final hasBook =
        dayBook != null &&
        (dayBook!.revenueAmount != null || dayBook!.dayNote.isNotEmpty);
    if (data == null || (data.isEmpty && !hasBook)) {
      return const PremiumCard(
        padding: EdgeInsets.all(AppSpacing.l),
        child: Text(
          AppStrings.ledgerRecentEmpty,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      );
    }
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final p in data.production.take(3))
            _RecentRow(
              icon: Icons.bakery_dining_outlined,
              title: '${p.product} · ${p.quantity} adet',
              meta: 'Üretim',
              accent: AppColors.primary,
            ),
          for (final w in data.wastes.take(3))
            _RecentRow(
              icon: Icons.delete_sweep_outlined,
              title: '${w.product} · ${w.quantity} adet · ${w.reason.label}',
              meta: 'Fire',
              accent: const Color(0xFFEF4444),
            ),
          if (dayBook?.revenueAmount != null)
            _RecentRow(
              icon: Icons.payments_outlined,
              title: NumberFormatter.currency(dayBook!.revenueAmount!),
              meta: 'Ciro',
              accent: const Color(0xFF10B981),
            ),
          if (dayBook != null && dayBook!.dayNote.isNotEmpty)
            _RecentRow(
              icon: Icons.sticky_note_2_outlined,
              title: dayBook!.dayNote,
              meta: 'Not',
              accent: AppColors.softGold,
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
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(
                color: accent.withValues(alpha: 0.18),
                width: 0.6,
              ),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

/// Gider ve bayi defterleri AYRI modüllerdir — buradan yalnız yönlendirilir.
class _OtherBooksLinks extends StatelessWidget {
  const _OtherBooksLinks();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.s,
      ),
      child: Column(
        children: [
          _LinkRow(
            keyName: 'ledger_expense_link',
            icon: Icons.account_balance_wallet_outlined,
            label: AppStrings.ledgerExpenseLinkCta,
            note: AppStrings.ledgerExpenseLinkNote,
            onTap: () => context.push(AppRoutes.debtExpense),
          ),
          const Divider(height: 0, color: AppColors.borderHairline),
          _LinkRow(
            keyName: 'ledger_dealer_link',
            icon: Icons.storefront_outlined,
            label: AppStrings.cardDealerPanel,
            note: AppStrings.cardDealerPanelSub,
            onTap: () => context.push(AppRoutes.dealers),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.note,
    required this.onTap,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey(keyName),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
