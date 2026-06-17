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

  /// Hizmet/teslimat bölgeleri (mağaza + ürün formlarında çok seçimli).
  List<String> serviceRegions();

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

  // ---- Mock write (in-memory; backend/persist YOK) ----

  /// Preview tedarikçi adına yeni ürün ekler ve eklenen ürünü döner.
  /// supplierId/supplierName/isMine repo tarafından kendi mağazaya bağlanır.
  B2bProduct addProduct({
    required String name,
    required String category,
    required String minOrder,
    required String deliveryRegion,
    String description = '',
    bool published = true,
  });

  /// Preview tedarikçi adına yeni kampanya ekler ve eklenen kampanyayı döner.
  B2bCampaign addCampaign({
    required String title,
    required String category,
    required String region,
    required String minPurchase,
    required String validUntil,
    String? linkedProduct,
    String description = '',
    bool published = true,
  });

  /// Preview tedarikçinin mağaza vitrinini günceller (id/sayaçlar korunur,
  /// monogram addan türetilir) ve güncel mağazayı döner.
  B2bStore updateStore({
    required String name,
    required String description,
    required List<String> serviceRegions,
    required List<String> categories,
  });

  /// Id ile ürün/kampanya bul (form prefill için). Yoksa null.
  B2bProduct? productById(String id);
  B2bCampaign? campaignById(String id);

  /// Mevcut ürünü düzenler (sahiplik/id korunur). Güncel ürünü döner.
  B2bProduct updateProduct({
    required String id,
    required String name,
    required String category,
    required String minOrder,
    required String deliveryRegion,
    String description = '',
    bool published = true,
  });

  /// Mevcut kampanyayı düzenler (sahiplik/id korunur). Güncel kampanyayı döner.
  B2bCampaign updateCampaign({
    required String id,
    required String title,
    required String category,
    required String region,
    required String minPurchase,
    required String validUntil,
    String? linkedProduct,
    String description = '',
    bool published = true,
  });

  /// Ürünü/kampanyayı yayına alır veya taslağa çeker (publish toggle).
  void setProductPublished(String id, bool published);
  void setCampaignPublished(String id, bool published);
}
