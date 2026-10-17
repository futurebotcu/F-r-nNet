// S2 — Tedarikçi Talepler gelen kutusu (saf hesaplama, test edilebilir).
//
// Kaynaklar (hepsi mevcut okuma yolları, yeni tablo/RPC YOK):
//   * openRequests  — rpc b2b_open_quote_requests(): ağdaki AÇIK talepler
//                     (closed/cancelled ve karar verilmişler HARİÇ, anonim).
//   * myReplies     — b2b_quote_replies where supplier_shop_id = mağazam.
//   * leads         — b2b_quote_leads (alıcının "İlgileniyorum" dediği
//                     cevaplarım; talep özeti denormalize: kategori/miktar/il).
//   * myProducts / myCampaigns / myShopId — talebin hedefi benim ürünüm mü?
//
// Segmentler:
//   Yeni            = openRequests − yanıtladıklarım (aktif, yanıta uygun).
//   Yanıtladıklarım = myReplies (talep hâlâ açıksa detayı eşlenir; değilse
//                     lead özeti; o da yoksa yalnız cevap bilgisi — DÜRÜST).
//   İlgilenenler    = leads where interested.
//   Kazanılan       = myReplies where accepted (yalnız RPC set eder).
//
// SINIR: Tedarikçi b2b_quote_requests tablosunu okuyamaz (RLS buyer-only) ve
// RPC yalnız açık talepleri döndürür → kapanmış/karar verilmiş bir talebin
// detayı, lead yoksa istemciden ERİŞİLEMEZ. Bu durum kartta açıkça
// "Talep artık açık değil" olarak gösterilir; kalıcı çözüm (S3 önerisi)
// tedarikçinin yanıtladığı taleplerin anonim özetini döndüren yeni bir RPC.

import 'b2b_campaign.dart';
import 'b2b_product.dart';
import 'b2b_quote_lead.dart';
import 'b2b_quote_reply.dart';
import 'b2b_quote_request.dart';
import 'b2b_replied_request.dart';

/// Talebin tedarikçi açısından hedef bağlamı.
enum SupplierRequestTarget {
  /// Kategori düzeyinde genel talep.
  category,

  /// Benim ürünüme / kampanyama / mağazama yönelik.
  mine,

  /// Başka bir tedarikçinin ürün/kampanya/mağazasına yönelik.
  other,
}

/// "Yanıtladıklarım" / "Kazanılan" satırı: cevabım + (varsa) talep bağlamı.
class SupplierRepliedItem {
  const SupplierRepliedItem({
    required this.reply,
    this.request,
    this.lead,
    this.decision,
  });

  final B2bQuoteReply reply;

  /// S3 — sunucu kararı (RPC varsa). null → S2 türetimi (reply.status).
  final B2bReplyDecision? decision;

  /// Talep hâlâ açıksa RPC'den gelen tam satır; değilse null.
  final B2bQuoteRequest? request;

  /// Alıcı ilgilendiyse lead (talep özeti + telefon/mesaj); yoksa null.
  final B2bQuoteLead? lead;

  /// Kartta gösterilecek talep başlığı (kategori/ürün). Erişilemiyorsa boş.
  String get title => request?.productOrCategory ?? lead?.requestCategory ?? '';

  String get quantity => request?.quantity ?? lead?.requestQuantity ?? '';

  String get city => request?.city ?? lead?.requestCity ?? '';

  /// Talep bilgisi hiç yok (kapanmış/karar verilmiş ve lead yok).
  bool get requestUnavailable => request == null && lead == null;

  /// Talep hâlâ yanıt bekliyor (açık) ve kararı yok.
  bool get requestStillOpen =>
      request != null && !request!.hasAcceptedReply && !closed;

  bool get won =>
      decision == B2bReplyDecision.won ||
      (decision == null &&
          (reply.accepted || reply.status == B2bReplyStatus.accepted));

  bool get lost =>
      decision == B2bReplyDecision.lost ||
      (decision == null && reply.status == B2bReplyStatus.declined);

  /// Alıcı talebi kapattı/iptal etti (karar vermeden).
  bool get closed =>
      decision == B2bReplyDecision.closed ||
      (decision == null && (request?.status.isTerminal ?? false));
}

class SupplierRequestsInbox {
  const SupplierRequestsInbox({
    required this.fresh,
    required this.replied,
    required this.interested,
    required this.won,
    required this.networkOpenCount,
    this.serverFreshCount,
    this.historyAvailable = false,
  });

  /// Yanıtlamadığım, yanıta uygun açık talepler ("Yeni").
  final List<B2bQuoteRequest> fresh;

  /// Verdiğim tüm cevaplar (en yeni önce).
  final List<SupplierRepliedItem> replied;

  /// Alıcının ilgilendiği cevaplarım.
  final List<B2bQuoteLead> interested;

  /// Alıcının seçtiği cevaplarım.
  final List<SupplierRepliedItem> won;

  /// Ağdaki toplam açık talep (yanıtladıklarım dahil) — KPI yardımcı metni.
  final int networkOpenCount;

  /// S3 — sunucu "yanıt bekleyen" sayısı (RPC varsa); yoksa fresh.length.
  final int? serverFreshCount;

  /// S3 — geçmiş RPC'si çalışıyor mu (kapanmış talep ayrıntısı var).
  final bool historyAvailable;

  int get freshCount => serverFreshCount ?? fresh.length;

  static const empty = SupplierRequestsInbox(
    fresh: [],
    replied: [],
    interested: [],
    won: [],
    networkOpenCount: 0,
  );

  static SupplierRequestsInbox build({
    required List<B2bQuoteRequest> openRequests,
    required List<B2bQuoteReply> myReplies,
    required List<B2bQuoteLead> leads,
    // S3: sunucu geçmişi (null → S2 davranışı) ve sunucu sayaçları.
    List<B2bRepliedRequest>? history,
    B2bSupplierRequestCounts? serverCounts,
  }) {
    final repliedIds = myReplies.map((r) => r.requestId).toSet();
    final openById = {for (final r in openRequests) r.id: r};
    final leadByReply = <String, B2bQuoteLead>{};
    for (final l in leads) {
      leadByReply.putIfAbsent(l.quoteReplyId, () => l);
    }
    final fresh = openRequests
        .where((r) => r.status.isActive && !repliedIds.contains(r.id))
        .toList(growable: false);
    final historyByReply = <String, B2bRepliedRequest>{
      if (history != null)
        for (final h in history) h.reply.id: h,
    };
    final replied = myReplies
        .map((rep) {
          final h = historyByReply[rep.id];
          return SupplierRepliedItem(
            reply: rep,
            // Sunucu geçmişi varsa talep ayrıntısı her zaman mevcut.
            request: h?.request ?? openById[rep.requestId],
            lead: leadByReply[rep.id],
            decision: h?.decision,
          );
        })
        .toList(growable: false);
    return SupplierRequestsInbox(
      fresh: fresh,
      replied: replied,
      interested: leads.where((l) => l.isInterested).toList(growable: false),
      won: replied.where((i) => i.won).toList(growable: false),
      networkOpenCount: serverCounts?.networkOpen ??
          openRequests.where((r) => r.status.isActive).length,
      serverFreshCount: serverCounts?.fresh,
      historyAvailable: history != null,
    );
  }

  /// Talep hedefinin tedarikçiyle ilişkisi.
  static SupplierRequestTarget targetOf(
    B2bQuoteRequest r, {
    required String? myShopId,
    required List<B2bProduct> myProducts,
    required List<B2bCampaign> myCampaigns,
  }) {
    final id = r.targetId;
    switch (r.targetType) {
      case 'product':
        if (id == null) return SupplierRequestTarget.category;
        return myProducts.any((p) => p.id == id)
            ? SupplierRequestTarget.mine
            : SupplierRequestTarget.other;
      case 'campaign':
        if (id == null) return SupplierRequestTarget.category;
        return myCampaigns.any((c) => c.id == id)
            ? SupplierRequestTarget.mine
            : SupplierRequestTarget.other;
      case 'shop':
        if (id == null) return SupplierRequestTarget.category;
        return (myShopId != null && myShopId == id)
            ? SupplierRequestTarget.mine
            : SupplierRequestTarget.other;
      default:
        return SupplierRequestTarget.category;
    }
  }

  /// "Ürünün: X" / "Kampanyan: Y" / "Mağazana özel" etiketi; benim değilse null.
  static String? myTargetLabel(
    B2bQuoteRequest r, {
    required String? myShopId,
    required List<B2bProduct> myProducts,
    required List<B2bCampaign> myCampaigns,
  }) {
    final id = r.targetId;
    if (id == null) return null;
    switch (r.targetType) {
      case 'product':
        for (final p in myProducts) {
          if (p.id == id) return p.name;
        }
        return null;
      case 'campaign':
        for (final c in myCampaigns) {
          if (c.id == id) return c.title;
        }
        return null;
      case 'shop':
        return (myShopId != null && myShopId == id) ? '' : null;
      default:
        return null;
    }
  }
}

/// Liste filtreleri (kategori / il / metin). Mevcut veriden türetilir.
class SupplierRequestFilter {
  const SupplierRequestFilter({this.category, this.city, this.query = ''});

  final String? category;
  final String? city;
  final String query;

  bool get isEmpty => category == null && city == null && query.trim().isEmpty;

  SupplierRequestFilter copyWith({
    String? Function()? category,
    String? Function()? city,
    String? query,
  }) => SupplierRequestFilter(
    category: category == null ? this.category : category(),
    city: city == null ? this.city : city(),
    query: query ?? this.query,
  );

  bool matchesRequest(B2bQuoteRequest r) {
    if (category != null && r.productOrCategory != category) return false;
    if (city != null && r.city != city) return false;
    final q = _norm(query);
    if (q.isEmpty) return true;
    return _norm(r.productOrCategory).contains(q) ||
        _norm(r.note).contains(q) ||
        _norm(r.city).contains(q) ||
        _norm(r.district).contains(q) ||
        _norm(r.quantity).contains(q);
  }

  bool matchesReplied(SupplierRepliedItem i) {
    if (category != null && i.title != category) return false;
    if (city != null && i.city != city) return false;
    final q = _norm(query);
    if (q.isEmpty) return true;
    return _norm(i.title).contains(q) ||
        _norm(i.city).contains(q) ||
        _norm(i.reply.message).contains(q);
  }

  /// Türkçe-duyarlı küçük harf (İ→i, I→ı) — plain toLowerCase İ'yi bozar.
  static String _norm(String s) =>
      s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().trim();

  /// Filtre seçenekleri: listedeki benzersiz kategori/il değerleri (sıralı).
  static List<String> categoriesOf(Iterable<B2bQuoteRequest> rs) =>
      _distinct(rs.map((r) => r.productOrCategory));

  static List<String> citiesOf(Iterable<B2bQuoteRequest> rs) =>
      _distinct(rs.map((r) => r.city));

  static List<String> _distinct(Iterable<String> xs) {
    final set = <String>{};
    for (final x in xs) {
      final t = x.trim();
      if (t.isNotEmpty) set.add(t);
    }
    final list = set.toList()..sort();
    return list;
  }
}
