// S3 — Tedarikçinin yanıtladığı talep (geçmiş dahil), sunucu RPC'si
// `b2b_my_replied_requests()` satırı. ANONİM: alıcı kimliği/iletişimi ve
// diğer tedarikçilerin cevapları yok; yalnız talep özeti + BENİM cevabım +
// alıcı kararı (won/lost/closed/pending).

import 'b2b_quote_reply.dart';
import 'b2b_quote_request.dart';

enum B2bReplyDecision { pending, won, lost, closed }

extension B2bReplyDecisionX on B2bReplyDecision {
  static B2bReplyDecision fromText(String? s) {
    switch (s) {
      case 'won':
        return B2bReplyDecision.won;
      case 'lost':
        return B2bReplyDecision.lost;
      case 'closed':
        return B2bReplyDecision.closed;
      default:
        return B2bReplyDecision.pending;
    }
  }
}

class B2bRepliedRequest {
  const B2bRepliedRequest({
    required this.request,
    required this.reply,
    required this.decision,
  });

  /// Talep özeti (kapanmış/karar verilmiş olsa da erişilebilir — S2 sınırı
  /// bu RPC ile kalktı).
  final B2bQuoteRequest request;

  /// Benim cevabım (status/accepted sunucudan).
  final B2bQuoteReply reply;

  final B2bReplyDecision decision;
}

/// Sunucu tarafı sayfalanmış açık talep listesi (`b2b_open_quote_requests_page`).
class B2bOpenRequestsPage {
  const B2bOpenRequestsPage({required this.items, required this.totalCount});

  final List<B2bQuoteRequest> items;

  /// Filtreye uyan toplam (sayfadan bağımsız).
  final int totalCount;

  bool hasMoreAfter(int offset) => offset + items.length < totalCount;
}

/// `b2b_supplier_request_counts()` — Panel KPI ile Talepler aynı sayı.
class B2bSupplierRequestCounts {
  const B2bSupplierRequestCounts({
    required this.fresh,
    required this.networkOpen,
  });

  /// Yanıtlamadığım açık talepler.
  final int fresh;

  /// Ağdaki tüm açık talepler.
  final int networkOpen;
}
