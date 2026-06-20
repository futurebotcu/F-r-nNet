import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/dealer.dart';
import '../models/dealer_transaction.dart';
import '../providers/dealer_providers.dart';
import '../repositories/driver_permission.dart';
import '../services/dealer_period.dart';
import '../widgets/dealer_filter_chip.dart';

/// Tam İşlem Geçmişi (Bayi Defteri Kullanılabilirlik Sprinti — B/C/D/E).
///
/// Bir bayinin TÜM işlemlerini (teslimat/tahsilat/iade/düzeltme) gösterir;
/// tip + dönem filtresi + arama (ürün/not/tutar). Satır → işlem detayı (D);
/// patron işlemi silebilir/iptal edebilir (C). AppBar'dan müşteri hesap
/// dökümü paylaşılır (E). Şoför owner aksiyonunda temiz yetki mesajı alır.
class DealerTransactionHistoryScreen extends ConsumerStatefulWidget {
  const DealerTransactionHistoryScreen({super.key, required this.dealerId});
  final String dealerId;

  @override
  ConsumerState<DealerTransactionHistoryScreen> createState() =>
      _DealerTransactionHistoryScreenState();
}

enum _Period { today, last7, last30, thisMonth, all }

extension on _Period {
  String get label => switch (this) {
        _Period.today => 'Bugün',
        _Period.last7 => 'Son 7 gün',
        _Period.last30 => 'Son 30 gün',
        _Period.thisMonth => 'Bu ay',
        _Period.all => 'Tümü',
      };

  bool contains(DateTime t, DateTime now) {
    switch (this) {
      case _Period.all:
        return true;
      case _Period.today:
        final r = DealerPeriod.today(now: now);
        return !t.isBefore(r.start) && t.isBefore(r.end);
      case _Period.last7:
        final r = DealerPeriod.lastNDays(7, now: now);
        return !t.isBefore(r.start) && t.isBefore(r.end);
      case _Period.last30:
        final r = DealerPeriod.lastNDays(30, now: now);
        return !t.isBefore(r.start) && t.isBefore(r.end);
      case _Period.thisMonth:
        final r = DealerPeriod.thisMonth(now: now);
        return !t.isBefore(r.start) && t.isBefore(r.end);
    }
  }
}

class _DealerTransactionHistoryScreenState
    extends ConsumerState<DealerTransactionHistoryScreen> {
  DealerTransactionType? _type; // null = Tümü
  _Period _period = _Period.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsByDealerProvider(widget.dealerId));
    final dealer = ref.watch(dealerByIdProvider(widget.dealerId)).valueOrNull;
    final summary =
        ref.watch(balanceSummaryProvider(widget.dealerId)).valueOrNull;

    return PremiumScaffold(
      appBar: AppBar(
        title: const Text('Tüm İşlem Geçmişi'),
        actions: [
          IconButton(
            tooltip: 'Döküm paylaş',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: (dealer == null || summary == null)
                ? null
                : () => _shareStatement(
                      dealer,
                      txAsync.valueOrNull ?? const [],
                    ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: txAsync.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Center(child: Text('İşlemler yüklenemedi.')),
          data: (all) {
            final now = DateTime.now();
            final filtered = all.where((t) {
              if (_type != null && t.type != _type) return false;
              if (!_period.contains(t.createdAt, now)) return false;
              if (_query.isNotEmpty) {
                final q = _query.toLowerCase();
                final hay = [
                  t.productName ?? '',
                  t.note,
                  t.amount.toStringAsFixed(0),
                  NumberFormatter.currency(t.amount),
                ].join(' ').toLowerCase();
                if (!hay.contains(q)) return false;
              }
              return true;
            }).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return Column(
              children: [
                _SearchField(onChanged: (v) => setState(() => _query = v)),
                _TypeFilterRow(
                  selected: _type,
                  onChanged: (t) => setState(() => _type = t),
                ),
                _PeriodFilterRow(
                  selected: _period,
                  onChanged: (p) => setState(() => _period = p),
                ),
                Expanded(
                  child: (all.isEmpty)
                      ? const _Empty('Henüz işlem yok.')
                      : filtered.isEmpty
                          ? const _Empty('Bu filtrede işlem yok.')
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.pageH,
                                  AppSpacing.s,
                                  AppSpacing.pageH,
                                  AppSpacing.xxl),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.xs),
                              itemBuilder: (_, i) => _HistoryRow(
                                tx: filtered[i],
                                onTap: () => _openDetail(filtered[i]),
                              ),
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openDetail(DealerTransaction tx) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _TxDetailSheet(
        tx: tx,
        onDelete: () => _confirmDelete(tx),
      ),
    );
  }

  Future<void> _confirmDelete(DealerTransaction tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İşlem silinsin mi?'),
        content: const Text('Bu işlem silinsin mi? Bakiye yeniden hesaplanır.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(dealerRepositoryProvider).deleteTransaction(tx);
      ref.invalidate(transactionsByDealerProvider(widget.dealerId));
      ref.invalidate(balanceSummaryProvider(widget.dealerId));
      if (!mounted) return;
      // Detay sheet'i (varsa) kapat.
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşlem silindi. Bakiye güncellendi.')),
      );
    } on DriverPermissionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşlem silinemedi. Tekrar deneyin.')),
      );
    }
  }

  Future<void> _shareStatement(
    Dealer dealer,
    List<DealerTransaction> txs,
  ) async {
    final summary = ref.read(balanceSummaryProvider(widget.dealerId)).valueOrNull;
    if (summary == null) return;
    final builder = ref.read(dealerShareBuilderProvider);
    final text = builder.buildPlainText(
      dealer: dealer,
      summary: summary,
      recentTransactions: txs.take(20).toList(),
    );
    await Share.share(text, subject: 'Bayi Hesap Özeti — ${dealer.name}');
  }
}

// ── Transaction tip metadata ────────────────────────────────────────────────

({IconData icon, Color color, String sign}) _meta(DealerTransactionType t) {
  switch (t) {
    case DealerTransactionType.delivery:
      return (icon: Icons.bakery_dining_rounded, color: AppColors.copper, sign: '+');
    case DealerTransactionType.returned:
      return (icon: Icons.assignment_returned_rounded, color: AppColors.info, sign: '−');
    case DealerTransactionType.payment:
      return (icon: Icons.payments_rounded, color: AppColors.success, sign: '−');
    case DealerTransactionType.adjustment:
      return (icon: Icons.tune_rounded, color: AppColors.softGold, sign: '±');
  }
}

String _shortDateTime(DateTime d) =>
    DateFormat('d MMM yyyy, HH:mm', 'tr_TR').format(d);

// ── Widgetlar ────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH, AppSpacing.m, AppSpacing.pageH, AppSpacing.s),
      child: TextField(
        onChanged: (v) => onChanged(v.trim()),
        decoration: InputDecoration(
          hintText: 'Ürün, not veya tutar ara…',
          prefixIcon: const Icon(Icons.search_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          isDense: true,
        ),
      ),
    );
  }
}

class _TypeFilterRow extends StatelessWidget {
  const _TypeFilterRow({required this.selected, required this.onChanged});
  final DealerTransactionType? selected;
  final ValueChanged<DealerTransactionType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        children: [
          DealerFilterChip(
            label: 'Tümü',
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          for (final t in DealerTransactionType.values) ...[
            const SizedBox(width: 8),
            DealerFilterChip(
              label: t.label,
              selected: selected == t,
              onSelected: (_) => onChanged(t),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodFilterRow extends StatelessWidget {
  const _PeriodFilterRow({required this.selected, required this.onChanged});
  final _Period selected;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        children: [
          for (final p in _Period.values) ...[
            DealerFilterChip(
              label: p.label,
              selected: selected == p,
              onSelected: (_) => onChanged(p),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.tx, required this.onTap});
  final DealerTransaction tx;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = _meta(tx.type);
    final title = tx.productName?.isNotEmpty == true
        ? '${tx.type.label} · ${tx.productName}'
        : tx.type.label;
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: m.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.s),
              ),
              child: Icon(m.icon, color: m.color, size: 18),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(_shortDateTime(tx.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Text('${m.sign}${NumberFormatter.currency(tx.amount.abs())}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: m.color,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(text,
              style: const TextStyle(
                  color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ),
      );
}

/// İşlem Detayı (D) — tüm alanlar + bakiye etkisi + (patron) sil.
class _TxDetailSheet extends ConsumerWidget {
  const _TxDetailSheet({required this.tx, required this.onDelete});
  final DealerTransaction tx;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = _meta(tx.type);
    final isCredit = tx.type == DealerTransactionType.payment ||
        tx.type == DealerTransactionType.returned;
    final effect = isCredit
        ? '−${NumberFormatter.currency(tx.amount.abs())} (bakiye azalır)'
        : tx.type == DealerTransactionType.adjustment
            ? '${tx.amount >= 0 ? '+' : '−'}'
                '${NumberFormatter.currency(tx.amount.abs())} (düzeltme)'
            : '+${NumberFormatter.currency(tx.amount.abs())} (bakiye artar)';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(m.icon, color: m.color, size: 22),
              const SizedBox(width: AppSpacing.s),
              Text(tx.type.label,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: AppSpacing.m),
            if (tx.productName?.isNotEmpty == true)
              _row('Ürün', tx.productName!),
            if (tx.quantity != null) _row('Adet', '${tx.quantity}'),
            if (tx.unitPrice != null)
              _row('Birim fiyat', NumberFormatter.currency(tx.unitPrice!)),
            _row('Toplam', NumberFormatter.currency(tx.amount.abs())),
            if (tx.paymentMethod != null)
              _row('Ödeme yöntemi', tx.paymentMethod!.label),
            if (tx.note.isNotEmpty) _row('Not', tx.note),
            _row('Tarih/saat', _shortDateTime(tx.createdAt)),
            _row('Bakiye etkisi', effect),
            const SizedBox(height: AppSpacing.l),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
                label: const Text('İşlemi Sil / İptal Et',
                    style: TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.4)),
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
