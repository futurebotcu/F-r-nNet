import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/number_formatter.dart';
import '../models/dealer.dart';
import '../models/dealer_balance_summary.dart';
import '../models/dealer_transaction.dart';

/// Bayi cari hesabını fırıncıya uygun, sade bir PDF olarak üretir.
///
/// [regularFont] / [boldFont] verilirse PDF tüm Türkçe karakterler ve
/// ₺ glyph'i ile render olur. Verilmezse Helvetica fallback kullanılır
/// (V1'de bu hata uyarıları üretiyordu — V1.1'de Roboto asset bundled).
class DealerPdfBuilder {
  const DealerPdfBuilder();

  Future<Uint8List> build({
    required Dealer dealer,
    required DealerBalanceSummary summary,
    required List<DealerTransaction> recentTransactions,
    DateTime? now,
    Uint8List? regularFont,
    Uint8List? boldFont,
  }) async {
    final ref = now ?? DateTime.now();
    final df = DateFormat('d MMMM yyyy, EEEE', 'tr_TR');
    final dt = DateFormat('d MMM, HH:mm', 'tr_TR');

    final pw.Font? base = regularFont != null
        ? pw.Font.ttf(regularFont.buffer.asByteData())
        : null;
    final pw.Font? bold = boldFont != null
        ? pw.Font.ttf(boldFont.buffer.asByteData())
        : null;

    final doc = pw.Document(
      title: 'FırınNet — ${dealer.name} hesap özeti',
      author: 'FırınNet',
      theme: base != null
          ? pw.ThemeData.withFont(
              base: base,
              bold: bold ?? base,
              italic: base,
              boldItalic: bold ?? base,
            )
          : null,
    );

    // Renk paleti — uygulama dark ama PDF light/printer dostu.
    const lemon = PdfColor.fromInt(0xFFFFE66D);
    const ink = PdfColor.fromInt(0xFF111827);
    const muted = PdfColor.fromInt(0xFF6B7280);
    const line = PdfColor.fromInt(0xFFF2F2F2);

    pw.Widget kv(String k, String v, {pw.TextStyle? vStyle}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: const pw.TextStyle(color: muted, fontSize: 11)),
            pw.Text(
              v,
              style:
                  vStyle ??
                  pw.TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
            ),
          ],
        ),
      );
    }

    pw.Widget txRow(DealerTransaction t) {
      String label;
      String amount;
      switch (t.type) {
        case DealerTransactionType.delivery:
          label = '${t.productName ?? "Ürün"} x${t.quantity ?? 0}';
          amount = '+ ${NumberFormatter.currency(t.amount)}';
          break;
        case DealerTransactionType.returned:
          label = 'İade · ${t.productName ?? "Ürün"} x${t.quantity ?? 0}';
          amount = '- ${NumberFormatter.currency(t.amount)}';
          break;
        case DealerTransactionType.payment:
          label = 'Ödeme · ${t.paymentMethod?.label ?? "—"}';
          amount = '- ${NumberFormatter.currency(t.amount)}';
          break;
        case DealerTransactionType.adjustment:
          label = 'Düzeltme';
          final sign = t.amount >= 0 ? '+' : '-';
          amount = '$sign ${NumberFormatter.currency(t.amount.abs())}';
          break;
      }
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 90,
              child: pw.Text(
                dt.format(t.createdAt),
                style: const pw.TextStyle(color: muted, fontSize: 10),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  color: ink,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              amount,
              style: const pw.TextStyle(color: ink, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final balanceTag = summary.currentBalance > 0
        ? 'borç'
        : summary.currentBalance < 0
        ? 'alacak'
        : 'kapalı';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 32,
          marginRight: 32,
          marginTop: 36,
          marginBottom: 36,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 32,
                  height: 32,
                  decoration: const pw.BoxDecoration(
                    color: lemon,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'F',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FırınNet',
                      style: pw.TextStyle(
                        color: ink,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Bayi Hesap Özeti',
                      style: const pw.TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Text(
                  df.format(ref),
                  style: const pw.TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // Bayi şeridi
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: line, width: 0.6),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    dealer.name,
                    style: pw.TextStyle(
                      color: ink,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (dealer.area.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        dealer.area,
                        style: const pw.TextStyle(color: muted, fontSize: 10),
                      ),
                    ),
                  if (dealer.contactName.isNotEmpty || dealer.phone.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        [
                          dealer.contactName,
                          dealer.phone,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: const pw.TextStyle(color: muted, fontSize: 10),
                      ),
                    ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Çalışma tipi: ${dealer.workingType.label}',
                    style: const pw.TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Toplamlar
            kv(
              'Toplam teslim',
              NumberFormatter.currency(summary.totalDelivery),
            ),
            kv('Toplam iade', NumberFormatter.currency(summary.totalReturn)),
            kv('Toplam ödeme', NumberFormatter.currency(summary.totalPayment)),
            if (summary.totalAdjustment != 0)
              kv('Düzeltme', NumberFormatter.currency(summary.totalAdjustment)),
            pw.SizedBox(height: 4),
            pw.Divider(color: line, thickness: 0.6),
            pw.SizedBox(height: 4),
            kv(
              'Güncel bakiye  ($balanceTag)',
              NumberFormatter.currency(summary.currentBalance),
              vStyle: pw.TextStyle(
                color: lemon,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (summary.lastPayment != null)
              kv('Son ödeme', dt.format(summary.lastPayment!)),

            pw.SizedBox(height: 18),

            // Son hareketler
            pw.Text(
              'SON HAREKETLER',
              style: pw.TextStyle(
                color: lemon,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: line, thickness: 0.6),
            if (recentTransactions.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 12),
                child: pw.Text(
                  'Bu bayide henüz hareket yok.',
                  style: const pw.TextStyle(color: muted, fontSize: 10),
                ),
              )
            else
              for (final t in recentTransactions) txRow(t),

            pw.Spacer(),
            pw.Divider(color: line, thickness: 0.6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'FırınNet — Fırıncının dijital ağı',
                  style: const pw.TextStyle(color: muted, fontSize: 9),
                ),
                pw.Text(
                  'firinnet.app',
                  style: const pw.TextStyle(color: muted, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }
}
