import 'package:intl/intl.dart';

import '../../../core/utils/number_formatter.dart';
import '../models/daily_summary.dart';

/// Gün sonu özetinden paylaşılabilir metin üretir.
class ReportBuilder {
  const ReportBuilder();

  String buildPlainText(DailySummary summary) {
    final df = DateFormat('d MMMM yyyy', 'tr_TR');
    final buf = StringBuffer()
      ..writeln('FırınNet — Gün Sonu')
      ..writeln(df.format(summary.day))
      ..writeln('────────────────');

    if (summary.isEmpty) {
      buf.writeln('Bugün henüz kayıt yok.');
      return buf.toString();
    }

    buf
      ..writeln('Toplam üretim: ${NumberFormatter.integer(summary.totalProduction)} adet')
      ..writeln('Bayiye verilen: ${NumberFormatter.integer(summary.totalDelivered)} adet')
      ..writeln('Bayi tutarı:    ${NumberFormatter.currency(summary.totalDealerAmount)}')
      ..writeln('Fire:           ${NumberFormatter.integer(summary.totalWaste)} adet')
      ..writeln('Tahmini zarar:  ${NumberFormatter.currency(summary.totalEstimatedLoss)}')
      ..writeln('────────────────')
      ..writeln('Net özet:       ${NumberFormatter.currency(summary.netAmount)}');

    return buf.toString();
  }
}
