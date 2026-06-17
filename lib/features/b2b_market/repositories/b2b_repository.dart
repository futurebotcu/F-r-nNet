// B2B Pazar — repository sözleşmesi.
//
// UI doğrudan mock seed görmesin diye soyutlama katmanı (marketplace
// feature'ındaki Repository deseninin sade hâli). Bu sprintte tek implementasyon
// LocalB2bRepository (mock). İleride Supabase implementasyonu aynı arayüzü
// uygular; UI/değişmez.
//
// Tüm metotlar senkron: yerel mock, IO yok → loading/spinner durumu yok.

import '../models/b2b_campaign.dart';
import '../models/b2b_product.dart';
import '../models/b2b_quote_reply.dart';
import '../models/b2b_quote_request.dart';
import '../models/b2b_store.dart';

abstract class B2bRepository {
  /// Preview tedarikçinin kendi mağaza vitrini.
  B2bStore myStore();

  /// Tüm tedarikçi mağazaları (Bireysel → "Tedarikçiler" sekmesi).
  List<B2bStore> listStores();

  /// Ürün kategorileri (filtre chip kaynağı).
  List<String> productCategories();

  /// Genel B2B ürün pazarı; opsiyonel kategori + serbest metin arama.
  List<B2bProduct> listProducts({String? category, String? query});

  /// Preview tedarikçinin kendi ürünleri.
  List<B2bProduct> listMyProducts();

  /// Tüm kampanyalar; opsiyonel kategori filtresi.
  List<B2bCampaign> listCampaigns({String? category});

  /// Preview tedarikçinin kendi kampanyaları.
  List<B2bCampaign> listMyCampaigns();

  /// Teklif Ağı — alıcıların açtığı anonim açık talepler (tedarikçi görür).
  List<B2bQuoteRequest> listOpenQuoteRequests();

  /// Tekliflerim — preview alıcının kendi açtığı talepler.
  List<B2bQuoteRequest> listMyQuoteRequests();

  /// Bir talebe gelen teklif cevapları (mock özet).
  List<B2bQuoteReply> repliesFor(String requestId);
}
