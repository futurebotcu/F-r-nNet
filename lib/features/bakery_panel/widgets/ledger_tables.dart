import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../models/ledger_range_report.dart';
import '../models/production_entry.dart';
import '../models/waste_entry.dart';

/// Fırın Defteri operasyon tabloları — mobil uyumlu tablo/kart hibrit.
///
/// ERP tablosu değil: dar ekranda kompakt satırlar (kolonlar ikinci satıra
/// düşer), genişte başlıklı tablo hissi. Yalnız MEVCUT verileri gösterir;
/// yeni veri kaynağı/migration yok. Sayılar sağa hizalı, rozetler küçük.

String _timeLabel(DateTime d) {
  final local = d.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _ratioLabel(double? ratio) =>
    ratio == null ? '—' : '%${(ratio * 100).toStringAsFixed(1)}';

/// Başlıklı tablo kartı iskeleti: başlık + (genişte) kolon başlığı + satırlar
/// + boş durum + opsiyonel "Tümünü gör".
class LedgerTableCard extends StatefulWidget {
  const LedgerTableCard({
    super.key,
    required this.title,
    required this.rows,
    this.header,
    this.emptyText,
    this.emptyAction,
    this.collapsedCount = 5,
    this.keyName,
  });

  final String title;
  final List<Widget> rows;

  /// Geniş ekranda gösterilen kolon başlığı satırı.
  final Widget? header;
  final String? emptyText;
  final Widget? emptyAction;

  /// Bu sayıdan fazlası "Tümünü gör" arkasına katlanır.
  final int collapsedCount;
  final String? keyName;

  @override
  State<LedgerTableCard> createState() => _LedgerTableCardState();
}

class _LedgerTableCardState extends State<LedgerTableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final visible = _expanded ? rows : rows.take(widget.collapsedCount);
    final hasMore = rows.length > widget.collapsedCount;
    return Container(
      // NOT: `ValueKey(widget.keyName)` String? tipiyle ValueKey<String?>
      // üretir ve find.byKey(ValueKey<String>) ile EŞLEŞMEZ — `!` şart.
      key: widget.keyName == null ? null : ValueKey<String>(widget.keyName!),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: AppShadow.card,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          if (rows.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: Text(
                widget.emptyText ?? AppStrings.ledgerReportEmpty,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            if (widget.emptyAction != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: widget.emptyAction!,
              ),
          ] else ...[
            if (widget.header != null)
              LayoutBuilder(
                builder: (context, c) => c.maxWidth >= 380
                    ? Column(
                        children: [
                          widget.header!,
                          const Divider(
                            height: 12,
                            color: AppColors.borderHairline,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ...visible,
            if (hasMore)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: widget.keyName == null
                      ? null
                      : ValueKey('${widget.keyName}_toggle'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    _expanded
                        ? AppStrings.ledgerTableShowLess
                        : AppStrings.ledgerTableShowAll,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// Kolon başlığı hücresi.
class LedgerHeaderCell extends StatelessWidget {
  const LedgerHeaderCell(
    this.label, {
    super.key,
    this.flex = 1,
    this.alignEnd = false,
  });

  final String label;
  final int flex;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Küçük durum/sebep rozeti.
class LedgerBadge extends StatelessWidget {
  const LedgerBadge(
    this.label, {
    super.key,
    this.tone = LedgerBadgeTone.neutral,
  });

  final String label;
  final LedgerBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      LedgerBadgeTone.neutral => (
        AppColors.surfaceVariant,
        AppColors.textSecondary,
      ),
      LedgerBadgeTone.success => (
        const Color(0xFFF3FBEF),
        const Color(0xFF166534),
      ),
      LedgerBadgeTone.warning => (
        const Color(0xFFFFF7E6),
        const Color(0xFFB45309),
      ),
      LedgerBadgeTone.danger => (
        const Color(0xFFFFF1F2),
        const Color(0xFFB91C1C),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

enum LedgerBadgeTone { neutral, success, warning, danger }

// ────────────────────────────────────────────────────────────────────────
// Bugünün Üretimi
// ────────────────────────────────────────────────────────────────────────

class TodayProductionTable extends StatelessWidget {
  const TodayProductionTable({super.key, required this.entries, this.onAdd});

  final List<ProductionEntry> entries;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return LedgerTableCard(
      keyName: 'ledger_table_production',
      title: AppStrings.ledgerTableProductionTitle,
      emptyText: AppStrings.ledgerTableProductionEmpty,
      emptyAction: onAdd == null
          ? null
          : OutlinedButton.icon(
              key: const ValueKey('ledger_table_production_add'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(AppStrings.ledgerQuickProduction),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandInk,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
      header: Row(
        children: const [
          LedgerHeaderCell(AppStrings.ledgerTableColTime),
          LedgerHeaderCell(AppStrings.ledgerTableColProduct, flex: 3),
          LedgerHeaderCell(AppStrings.ledgerTableColQty, alignEnd: true),
        ],
      ),
      rows: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _timeLabel(e.createdAt),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        e.product,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${NumberFormatter.integer(e.quantity)} adet',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (e.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      e.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Bugünün Fire / Zayiatı
// ────────────────────────────────────────────────────────────────────────

class TodayWasteTable extends StatelessWidget {
  const TodayWasteTable({super.key, required this.entries, this.onAdd});

  final List<WasteEntry> entries;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return LedgerTableCard(
      keyName: 'ledger_table_waste',
      title: AppStrings.ledgerTableWasteTitle,
      emptyText: AppStrings.ledgerTableWasteEmpty,
      emptyAction: onAdd == null
          ? null
          : OutlinedButton.icon(
              key: const ValueKey('ledger_table_waste_add'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(AppStrings.ledgerQuickWaste),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandInk,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
      header: Row(
        children: const [
          LedgerHeaderCell(AppStrings.ledgerTableColTime),
          LedgerHeaderCell(AppStrings.ledgerTableColProduct, flex: 2),
          LedgerHeaderCell(AppStrings.ledgerTableColReason, flex: 2),
          LedgerHeaderCell(AppStrings.ledgerTableColLoss, alignEnd: true),
        ],
      ),
      rows: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _timeLabel(e.createdAt),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        '${e.product} · ${NumberFormatter.integer(e.quantity)} adet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      e.unitValue > 0
                          ? NumberFormatter.currency(e.estimatedLoss)
                          : '—',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      LedgerBadge(
                        e.reason.label,
                        tone: LedgerBadgeTone.warning,
                      ),
                      if (e.note.isNotEmpty)
                        Text(
                          e.note,
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
              ],
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Rapor: Gün Sonu Defteri
// ────────────────────────────────────────────────────────────────────────

class DayBookTable extends StatelessWidget {
  const DayBookTable({super.key, required this.rows});

  final List<LedgerDayRow> rows;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM', 'tr_TR');
    return LedgerTableCard(
      keyName: 'ledger_table_daybook',
      title: AppStrings.ledgerTableDayBookTitle,
      collapsedCount: 7,
      header: Row(
        children: const [
          LedgerHeaderCell(AppStrings.ledgerTableColDate, flex: 2),
          LedgerHeaderCell(
            AppStrings.ledgerTableColRevenue,
            flex: 2,
            alignEnd: true,
          ),
          LedgerHeaderCell(AppStrings.ledgerTableColProduction, alignEnd: true),
          LedgerHeaderCell(AppStrings.ledgerTableColWaste, alignEnd: true),
          LedgerHeaderCell(AppStrings.ledgerTableColRatio, alignEnd: true),
        ],
      ),
      rows: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarih + rozetler: dar ekran + 1.3x'te ikinci satıra düşer.
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      df.format(r.date),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    LedgerBadge(
                      r.isClosed
                          ? AppStrings.ledgerDayClosed
                          : AppStrings.ledgerDayOpen,
                      tone: r.isClosed
                          ? LedgerBadgeTone.success
                          : LedgerBadgeTone.neutral,
                    ),
                    if (r.isHighWaste)
                      const LedgerBadge(
                        AppStrings.ledgerChipHighWaste,
                        tone: LedgerBadgeTone.danger,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                // Sayılar: dar ekranda ikinci satıra düşen kompakt hücreler.
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: 2,
                  children: [
                    _MiniStat(
                      label: AppStrings.ledgerTableColRevenue,
                      value: r.revenue == null
                          ? '—'
                          : NumberFormatter.currency(r.revenue!),
                    ),
                    _MiniStat(
                      label: AppStrings.ledgerTableColProduction,
                      value: NumberFormatter.integer(r.production),
                    ),
                    _MiniStat(
                      label: AppStrings.ledgerTableColWaste,
                      value: NumberFormatter.integer(r.waste),
                    ),
                    _MiniStat(
                      label: AppStrings.ledgerTableColRatio,
                      value: _ratioLabel(r.wasteRatio),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Rapor: Ürün Bazlı Özet
// ────────────────────────────────────────────────────────────────────────

class ProductSummaryTable extends StatelessWidget {
  const ProductSummaryTable({super.key, required this.rows});

  final List<LedgerProductRow> rows;

  @override
  Widget build(BuildContext context) {
    return LedgerTableCard(
      keyName: 'ledger_table_products',
      title: AppStrings.ledgerTableProductSummaryTitle,
      collapsedCount: 6,
      header: Row(
        children: const [
          LedgerHeaderCell(AppStrings.ledgerTableColProduct, flex: 3),
          LedgerHeaderCell(AppStrings.ledgerTableColProduction, alignEnd: true),
          LedgerHeaderCell(AppStrings.ledgerTableColWaste, alignEnd: true),
          LedgerHeaderCell(AppStrings.ledgerTableColRatio, alignEnd: true),
          LedgerHeaderCell(AppStrings.ledgerTableColLoss, alignEnd: true),
        ],
      ),
      rows: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.product,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (r.isHighWaste)
                      const LedgerBadge(
                        AppStrings.ledgerChipHighWaste,
                        tone: LedgerBadgeTone.danger,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: 2,
                  children: [
                    _MiniStat(
                      label: AppStrings.ledgerTableColProduction,
                      value: NumberFormatter.integer(r.production),
                    ),
                    _MiniStat(
                      label: AppStrings.ledgerTableColWaste,
                      value: NumberFormatter.integer(r.waste),
                    ),
                    _MiniStat(
                      label: AppStrings.ledgerTableColRatio,
                      value: _ratioLabel(r.wasteRatio),
                    ),
                    _MiniStat(
                      label: AppStrings.ledgerTableColLoss,
                      value: r.estimatedLoss > 0
                          ? NumberFormatter.currency(r.estimatedLoss)
                          : '—',
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Rapor: Son Notlar
// ────────────────────────────────────────────────────────────────────────

class NotesTable extends StatelessWidget {
  const NotesTable({super.key, required this.rows});

  /// (gün, gün notu, ciro/kasa notu)
  final List<(DateTime, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final df = DateFormat('d MMM', 'tr_TR');
    return LedgerTableCard(
      keyName: 'ledger_table_notes',
      title: AppStrings.ledgerTableNotesTitle,
      collapsedCount: 5,
      rows: [
        for (final (date, dayNote, cashNote) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  df.format(date),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
                if (dayNote.isNotEmpty)
                  Text(
                    dayNote,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                if (cashNote.isNotEmpty)
                  Text(
                    '${AppStrings.ledgerTableColRevenue}: $cashNote',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Gün Sonu mini özet tablosu
// ────────────────────────────────────────────────────────────────────────

class EodMiniTable extends StatelessWidget {
  const EodMiniTable({
    super.key,
    required this.production,
    required this.waste,
    this.revenue,
    required this.openTasks,
    required this.doneTasks,
  });

  final int production;
  final int waste;
  final double? revenue;
  final int openTasks;
  final int doneTasks;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {IconData? icon}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );

    return LedgerTableCard(
      keyName: 'ledger_table_eod',
      title: AppStrings.ledgerTableEodTitle,
      collapsedCount: 10,
      rows: [
        row(
          AppStrings.ledgerEodProduction,
          '${NumberFormatter.integer(production)} adet',
          icon: Icons.bakery_dining_outlined,
        ),
        row(
          AppStrings.ledgerEodWaste,
          '${NumberFormatter.integer(waste)} adet',
          icon: Icons.delete_sweep_outlined,
        ),
        row(
          AppStrings.ledgerEodRevenue,
          revenue == null ? '—' : NumberFormatter.currency(revenue!),
          icon: Icons.payments_outlined,
        ),
        row(
          AppStrings.ledgerEodTasksOpen,
          NumberFormatter.integer(openTasks),
          icon: Icons.radio_button_unchecked_rounded,
        ),
        row(
          AppStrings.ledgerEodTasksDone,
          NumberFormatter.integer(doneTasks),
          icon: Icons.task_alt_rounded,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // Uzun para değeri (örn. ₺123.456,78) 320dp + 1.3x'te satır genişliğini
    // aşabilir — kırpma yerine tek satır kalıp küçülür (StatCard emsali).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
