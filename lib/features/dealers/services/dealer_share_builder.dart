import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../models/dealer.dart';
import '../models/dealer_balance_summary.dart';
import '../models/dealer_range_metrics.dart';
import '../models/dealer_transaction.dart';

/// Bayi cari hesabını WhatsApp/SMS-uyumlu düz metin olarak üretir.
class DealerShareBuilder {
  const DealerShareBuilder();

  String buildPlainText({
    required Dealer dealer,
    required DealerBalanceSummary summary,
    required List<DealerTransaction> recentTransactions,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final df = DateFormat('d MMMM yyyy, EEEE', 'tr_TR');
    final dt = DateFormat('d MMM, HH:mm', 'tr_TR');

    final buf = StringBuffer()
      ..writeln('FırınNet — Bayi Hesap Özeti')
      ..writeln(dealer.name)
      ..writeln(df.format(ref))
      ..writeln('────────────────')
      ..writeln('Toplam teslim:  ${NumberFormatter.currency(summary.totalDelivery)}')
      ..writeln('Toplam iade:    ${NumberFormatter.currency(summary.totalReturn)}')
      ..writeln('Toplam ödeme:   ${NumberFormatter.currency(summary.totalPayment)}');

    if (summary.totalAdjustment != 0) {
      buf.writeln(
          'Düzeltme:       ${NumberFormatter.currency(summary.totalAdjustment)}');
    }

    buf
      ..writeln('────────────────')
      ..writeln('Güncel bakiye:  ${NumberFormatter.currency(summary.currentBalance)}');

    final tag = summary.currentBalance > 0
        ? '(borç)'
        : summary.currentBalance < 0
            ? '(alacak)'
            : '(kapalı)';
    buf.writeln('Durum:          $tag');

    if (summary.lastPayment != null) {
      buf.writeln('Son ödeme:      ${dt.format(summary.lastPayment!)}');
    }

    if (recentTransactions.isNotEmpty) {
      buf
        ..writeln('────────────────')
        ..writeln('Son ${recentTransactions.length} hareket');
      for (final t in recentTransactions) {
        buf.writeln(_lineFor(t, dt));
      }
    }

    return buf.toString();
  }

  /// Gün Sonu V1 — cross-dealer günlük özet plain text (WhatsApp/SMS).
  ///
  /// `metrics` aralığı tipik olarak `[bugün 00:00, yarın 00:00)` ama
  /// builder periyot-agnostik çalışır. Bugün hareketi olan aktif
  /// bayiler [DealerAggregateRangeMetrics.perDealerTxCount] > 0 olarak
  /// belirlenir; sıralama netChange descending (en pozitif önce).
  String buildDailySummary({
    required DealerAggregateRangeMetrics metrics,
    required List<Dealer> dealers,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final df = DateFormat('d MMMM yyyy, EEEE', 'tr_TR');

    final buf = StringBuffer()
      ..writeln(AppStrings.dealerEndOfDayPlainTextHeader)
      ..writeln(df.format(ref))
      ..writeln('────────────────');

    if (metrics.txCount == 0) {
      buf.writeln(AppStrings.dealerEndOfDayShareEmptyLine);
      return buf.toString();
    }

    buf
      ..writeln('Teslimat:  ${NumberFormatter.currency(metrics.totalDelivery)}')
      ..writeln('İade:      ${NumberFormatter.currency(metrics.totalReturn)}')
      ..writeln('Tahsilat:  ${NumberFormatter.currency(metrics.totalPayment)}');

    if (metrics.totalAdjustment != 0) {
      buf.writeln(
          'Düzeltme:  ${NumberFormatter.currency(metrics.totalAdjustment)}');
    }

    buf
      ..writeln('Net:       ${NumberFormatter.currency(metrics.netChange)}')
      ..writeln('İşlem:     ${metrics.txCount}');

    // Bayi bazlı bugün: yalnız txCount > 0 (aktif + bugün hareketi olan).
    // Aktiflik filtre'si `metrics.perDealerTxCount` map'inin kendisi —
    // provider zaten pasif bayileri groupBy filter'lamış. Yine de dealer
    // adlarını çözmek için `dealers` listesi gerekli.
    final dealerById = {for (final d in dealers) d.id: d};
    final activeEntries = metrics.perDealerTxCount.entries
        .where((e) => e.value > 0 && dealerById.containsKey(e.key))
        .toList()
      // En pozitif net (borç artışı) en üstte; ardından negatif (tahsilat).
      ..sort((a, b) {
        final na = metrics.perDealerNet[a.key] ?? 0;
        final nb = metrics.perDealerNet[b.key] ?? 0;
        return nb.compareTo(na);
      });

    if (activeEntries.isNotEmpty) {
      buf
        ..writeln('────────────────')
        ..writeln(AppStrings.dealerEndOfDayByDealerTitle);
      for (final e in activeEntries) {
        final d = dealerById[e.key]!;
        final net = metrics.perDealerNet[e.key] ?? 0;
        buf.writeln(
          '• ${d.name}  ${NumberFormatter.currency(net)}  '
          '(${e.value} ${AppStrings.dealerEndOfDayTxCountSuffix})',
        );
      }
    }

    return buf.toString();
  }

  String _lineFor(DealerTransaction t, DateFormat dt) {
    final stamp = dt.format(t.createdAt);
    switch (t.type) {
      case DealerTransactionType.delivery:
        final qty = t.quantity ?? 0;
        final pname = t.productName ?? 'Ürün';
        return '• $stamp · $pname x$qty · '
            '${NumberFormatter.currency(t.amount)}';
      case DealerTransactionType.returned:
        final qty = t.quantity ?? 0;
        final pname = t.productName ?? 'Ürün';
        return '• $stamp · İade $pname x$qty · '
            '−${NumberFormatter.currency(t.amount)}';
      case DealerTransactionType.payment:
        final method = t.paymentMethod?.label ?? 'Ödeme';
        return '• $stamp · $method · '
            '−${NumberFormatter.currency(t.amount)}';
      case DealerTransactionType.adjustment:
        final sign = t.amount >= 0 ? '+' : '−';
        return '• $stamp · Düzeltme · $sign'
            '${NumberFormatter.currency(t.amount.abs())}';
    }
  }
}
