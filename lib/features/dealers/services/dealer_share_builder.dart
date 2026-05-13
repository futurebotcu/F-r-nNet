import 'package:intl/intl.dart';

import '../../../core/utils/number_formatter.dart';
import '../models/dealer.dart';
import '../models/dealer_balance_summary.dart';
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
