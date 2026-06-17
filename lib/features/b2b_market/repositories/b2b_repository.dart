// B2B Pazar — repository sözleşmesi.
//
// UI doğrudan veri kaynağını görmesin diye soyutlama katmanı. İki implementasyon:
//   • LocalB2bRepository  — in-memory mock (varsayılan, guest/offline fallback)
//   • SupabaseB2bRepository — gerçek backend (auth + Supabase hazırsa)
//
// Veri çeken/yazan metotlar ASYNC (Future). Yalnız sabit referans listeleri
// (productCategories/serviceRegions) senkron kalır — DB tablosu değil.

import '../models/b2b_campaign.dart';
import '../models/b2b_product.dart';
import '../models/b2b_quote_reply.dart';
import '../models/b2b_quote_request.dart';
import '../models/b2b_store.dart';

abstract class B2bRepository {
  /// Aktif kullanıcının kendi mağaza vitrini.
  Future<B2bStore> myStore();

  /// Tüm tedarikçi mağazaları (Alıcı → "Tedarikçiler" sekmesi).
  Future<List<B2bStore>> listStores();

  /// Ürün kategorileri (filtre chip kaynağı) — sabit referans, senkron.
  List<String> productCategories();

  /// Hizmet/teslimat bölgeleri (form çok-seçimli) — sabit referans, senkron.
  List<String> serviceRegions();

  /// Genel B2B ürün pazarı; opsiyonel kategori + serbest metin arama.
  Future<List<B2bProduct>> listProducts({String? category, String? query});

  /// Aktif kullanıcının kendi ürünleri (taslak dahil).
  Future<List<B2bProduct>> listMyProducts();

  /// Tüm kampanyalar; opsiyonel kategori filtresi.
  Future<List<B2bCampaign>> listCampaigns({String? category});

  /// Aktif kullanıcının kendi kampanyaları (taslak dahil).
  Future<List<B2bCampaign>> listMyCampaigns();

  /// Teklif Ağı — alıcıların açtığı ANONİM açık talepler (tedarikçi görür).
  Future<List<B2bQuoteRequest>> listOpenQuoteRequests();

  /// Tekliflerim — aktif kullanıcının (alıcı) kendi açtığı talepler.
  Future<List<B2bQuoteRequest>> listMyQuoteRequests();

  /// Bir talebe gelen teklif cevapları.
  Future<List<B2bQuoteReply>> repliesFor(String requestId);

  // ---- Write ----

  /// Yeni ürün ekler; eklenen ürünü döner.
  Future<B2bProduct> addProduct({
    required String name,
    required String category,
    required String minOrder,
    required String deliveryRegion,
    String description = '',
    bool published = true,
  });

  /// Yeni kampanya ekler; eklenen kampanyayı döner.
  Future<B2bCampaign> addCampaign({
    required String title,
    required String category,
    required String region,
    required String minPurchase,
    required String validUntil,
    String? linkedProduct,
    String description = '',
    bool published = true,
  });

  /// Mağaza vitrinini günceller; güncel mağazayı döner.
  Future<B2bStore> updateStore({
    required String name,
    required String description,
    required List<String> serviceRegions,
    required List<String> categories,
  });

  /// Id ile ürün/kampanya bul (form prefill için). Yoksa null.
  Future<B2bProduct?> productById(String id);
  Future<B2bCampaign?> campaignById(String id);

  /// Mevcut ürünü düzenler; güncel ürünü döner.
  Future<B2bProduct> updateProduct({
    required String id,
    required String name,
    required String category,
    required String minOrder,
    required String deliveryRegion,
    String description = '',
    bool published = true,
  });

  /// Mevcut kampanyayı düzenler; güncel kampanyayı döner.
  Future<B2bCampaign> updateCampaign({
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
  Future<void> setProductPublished(String id, bool published);
  Future<void> setCampaignPublished(String id, bool published);

  // ---- Teklif akışları ----

  /// Alıcı yeni teklif talebi açar (Teklif İste / Fiyat Sor / Yeni teklif).
  /// Supabase'de buyer_id = auth.uid() (repo içinde), status='open'. Eklenen
  /// talebi döner. ANONİM: kimlik alanı yok.
  Future<B2bQuoteRequest> addQuoteRequest({
    required String targetType,
    String? targetId,
    required String category,
    required String quantity,
    required String city,
    String district = '',
    String buyerType = '',
    String deliveryTime = '',
    String note = '',
  });

  /// Tedarikçi bir talebe cevap (teklif) verir. supplier_shop_id repo içinde
  /// giriş yapan kullanıcının mağazasından çözülür; status='sent'.
  Future<void> addQuoteReply({
    required String quoteRequestId,
    required String message,
    String? priceNote,
    String? deliveryNote,
  });
}
