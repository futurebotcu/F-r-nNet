// B2B Pazar — Riverpod provider'ları.
//
// Repository ASYNC; tab'lar veriyi FutureProvider'lardan AsyncValue olarak alır
// (loading/error/data). Write'lar [b2bMarketControllerProvider] üzerinden
// yapılır; her write revizyonu artırır → ilgili FutureProvider'lar yenilenir.
//
// Repository seçimi (Local / Supabase) [b2bRepositoryProvider] içindedir
// (Adım C). Şu an varsayılan Local; guest/offline fallback korunur.
//
// ROL ÇÖZÜMÜ — TEK NOKTA: [b2bRoleProvider] (profildeki AccountType'tan;
// wholesaler → tedarikçi, diğerleri/guest → alıcı). AccountType DEĞİŞTİRİLMEZ.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/b2b_campaign.dart';
import '../models/b2b_lead_message.dart';
import '../models/b2b_product.dart';
import '../models/b2b_quote_lead.dart';
import '../models/b2b_quote_reply.dart';
import '../models/b2b_replied_request.dart';
import '../models/b2b_quote_request.dart';
import '../models/supplier_requests_inbox.dart';
import '../models/b2b_store.dart';
import '../repositories/b2b_repository.dart';
import '../repositories/local_b2b_repository.dart';
import '../repositories/supabase_b2b_repository.dart';

/// Repository seçim mantığı — saf ve test edilebilir.
///
/// Supabase yapılandırılmış VE oturum (userId) varsa → Supabase; aksi halde
/// (guest / Supabase kapalı / oturum yok) → Local. Supabase örneği
/// oluşturulurken hata olursa (client hazır değil) güvenli şekilde Local'a
/// düşer → Pazar boş kalmaz/çökmez.
B2bRepository b2bRepositoryFor({
  required bool supabaseEnabled,
  required String? userId,
  required B2bRepository Function() makeSupabase,
  required B2bRepository Function() makeLocal,
}) {
  if (supabaseEnabled && userId != null) {
    try {
      return makeSupabase();
    } catch (_) {
      return makeLocal();
    }
  }
  return makeLocal();
}

/// B2B repository sağlayıcısı. Auth + Supabase hazırsa SupabaseB2bRepository,
/// yoksa LocalB2bRepository (guest/offline fallback). Yalnız userId izlenir
/// (token refresh repo'yu gereksiz resetlemesin — marketplace P0 kalıbı).
final b2bRepositoryProvider = Provider<B2bRepository>((ref) {
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  return b2bRepositoryFor(
    supabaseEnabled: AppConfig.supabaseEnabled,
    userId: userId,
    makeSupabase: () => SupabaseB2bRepository(sb.Supabase.instance.client),
    makeLocal: LocalB2bRepository.new,
  );
});

/// Mağaza yönetim write akışlarının tek giriş noktası + reaktif sinyal.
/// State bir revizyon sayacıdır; her write sonrası artar.
final b2bMarketControllerProvider = NotifierProvider<B2bMarketController, int>(
  B2bMarketController.new,
);

class B2bMarketController extends Notifier<int> {
  @override
  int build() => 0;

  B2bRepository get _repo => ref.read(b2bRepositoryProvider);

  Future<void> addProduct({
    required String name,
    required String category,
    required String minOrder,
    required String deliveryRegion,
    String description = '',
    bool published = true,
    String? imageUrl,
  }) async {
    await _repo.addProduct(
      name: name,
      category: category,
      minOrder: minOrder,
      deliveryRegion: deliveryRegion,
      description: description,
      published: published,
      imageUrl: imageUrl,
    );
    state++;
  }

  Future<void> addCampaign({
    required String title,
    required String category,
    required String region,
    required String minPurchase,
    required String validUntil,
    String? linkedProduct,
    String? linkedProductId,
    String description = '',
    bool published = true,
    String? imageUrl,
  }) async {
    await _repo.addCampaign(
      title: title,
      category: category,
      region: region,
      minPurchase: minPurchase,
      validUntil: validUntil,
      linkedProduct: linkedProduct,
      linkedProductId: linkedProductId,
      description: description,
      published: published,
      imageUrl: imageUrl,
    );
    state++;
  }

  Future<void> updateStore({
    required String name,
    required String description,
    required List<String> serviceRegions,
    required List<String> categories,
    String? logoUrl,
    String? coverUrl,
    String? phone,
    String? whatsapp,
    String? website,
    String? address,
  }) async {
    await _repo.updateStore(
      name: name,
      description: description,
      serviceRegions: serviceRegions,
      categories: categories,
      logoUrl: logoUrl,
      coverUrl: coverUrl,
      phone: phone,
      whatsapp: whatsapp,
      website: website,
      address: address,
    );
    state++;
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String category,
    required String minOrder,
    required String deliveryRegion,
    String description = '',
    bool published = true,
    String? imageUrl,
  }) async {
    await _repo.updateProduct(
      id: id,
      name: name,
      category: category,
      minOrder: minOrder,
      deliveryRegion: deliveryRegion,
      description: description,
      published: published,
      imageUrl: imageUrl,
    );
    state++;
  }

  Future<void> updateCampaign({
    required String id,
    required String title,
    required String category,
    required String region,
    required String minPurchase,
    required String validUntil,
    String? linkedProduct,
    String? linkedProductId,
    String description = '',
    bool published = true,
    String? imageUrl,
  }) async {
    await _repo.updateCampaign(
      id: id,
      title: title,
      category: category,
      region: region,
      minPurchase: minPurchase,
      validUntil: validUntil,
      linkedProduct: linkedProduct,
      linkedProductId: linkedProductId,
      description: description,
      published: published,
      imageUrl: imageUrl,
    );
    state++;
  }

  Future<void> setProductPublished(String id, bool published) async {
    await _repo.setProductPublished(id, published);
    state++;
  }

  Future<void> setCampaignPublished(String id, bool published) async {
    await _repo.setCampaignPublished(id, published);
    state++;
  }

  /// S3 — silme / çoğaltma (RLS: yalnız sahip).
  Future<void> deleteProduct(String id) async {
    await _repo.deleteProduct(id);
    state++;
  }

  Future<void> deleteCampaign(String id) async {
    await _repo.deleteCampaign(id);
    state++;
  }

  Future<B2bProduct> duplicateProduct(String id) async {
    final p = await _repo.duplicateProduct(id);
    state++;
    return p;
  }

  Future<void> addQuoteRequest({
    required String targetType,
    String? targetId,
    required String category,
    required String quantity,
    required String city,
    String district = '',
    String buyerType = '',
    String deliveryTime = '',
    String note = '',
  }) async {
    await _repo.addQuoteRequest(
      targetType: targetType,
      targetId: targetId,
      category: category,
      quantity: quantity,
      city: city,
      district: district,
      buyerType: buyerType,
      deliveryTime: deliveryTime,
      note: note,
    );
    state++;
  }

  Future<void> addQuoteReply({
    required String quoteRequestId,
    required String message,
    String? priceNote,
    String? deliveryNote,
  }) async {
    await _repo.addQuoteReply(
      quoteRequestId: quoteRequestId,
      message: message,
      priceNote: priceNote,
      deliveryNote: deliveryNote,
    );
    state++;
  }

  Future<void> closeQuoteRequest(String id) async {
    await _repo.closeQuoteRequest(id);
    state++;
  }

  Future<void> cancelQuoteRequest(String id) async {
    await _repo.cancelQuoteRequest(id);
    state++;
  }

  Future<void> expressInterestInQuoteReply({
    required String quoteReplyId,
    String message = '',
    bool phoneShared = false,
    String? phone,
  }) async {
    await _repo.expressInterestInQuoteReply(
      quoteReplyId: quoteReplyId,
      message: message,
      phoneShared: phoneShared,
      phone: phone,
    );
    state++;
  }

  Future<void> rejectQuoteReply(String quoteReplyId) async {
    await _repo.rejectQuoteReply(quoteReplyId);
    state++;
  }

  Future<void> acceptQuoteReply(String quoteReplyId) async {
    await _repo.acceptQuoteReply(quoteReplyId);
    state++;
  }

  Future<void> sendLeadMessage({
    required String leadId,
    required String message,
  }) async {
    await _repo.sendLeadMessage(leadId: leadId, message: message);
    state++;
  }
}

// ---- Okuma FutureProvider'ları (write revizyonunu izler → otomatik yenilenir) ----

/// Ürün listesi filtre anahtarı (FutureProvider.family için equatable record).
typedef B2bProductQuery = ({String? category, String query});

final b2bMyStoreProvider = FutureProvider.autoDispose<B2bStore>((ref) {
  ref.watch(b2bMarketControllerProvider);
  return ref.watch(b2bRepositoryProvider).myStore();
});

final b2bMyProductsProvider = FutureProvider.autoDispose<List<B2bProduct>>((
  ref,
) {
  ref.watch(b2bMarketControllerProvider);
  return ref.watch(b2bRepositoryProvider).listMyProducts();
});

final b2bMyCampaignsProvider = FutureProvider.autoDispose<List<B2bCampaign>>((
  ref,
) {
  ref.watch(b2bMarketControllerProvider);
  return ref.watch(b2bRepositoryProvider).listMyCampaigns();
});

final b2bStoresProvider = FutureProvider.autoDispose<List<B2bStore>>((ref) {
  ref.watch(b2bMarketControllerProvider);
  return ref.watch(b2bRepositoryProvider).listStores();
});

final b2bProductsProvider = FutureProvider.autoDispose
    .family<List<B2bProduct>, B2bProductQuery>((ref, q) {
      ref.watch(b2bMarketControllerProvider);
      return ref
          .watch(b2bRepositoryProvider)
          .listProducts(category: q.category, query: q.query);
    });

final b2bCampaignsProvider = FutureProvider.autoDispose
    .family<List<B2bCampaign>, String?>((ref, category) {
      ref.watch(b2bMarketControllerProvider);
      return ref.watch(b2bRepositoryProvider).listCampaigns(category: category);
    });

final b2bOpenQuoteRequestsProvider =
    FutureProvider.autoDispose<List<B2bQuoteRequest>>((ref) {
      ref.watch(b2bMarketControllerProvider);
      return ref.watch(b2bRepositoryProvider).listOpenQuoteRequests();
    });

final b2bMyQuoteRequestsProvider =
    FutureProvider.autoDispose<List<B2bQuoteRequest>>((ref) {
      ref.watch(b2bMarketControllerProvider);
      return ref.watch(b2bRepositoryProvider).listMyQuoteRequests();
    });

/// Tek teklif talebi detayı (alıcı, kendi talebi).
final b2bQuoteDetailProvider = FutureProvider.autoDispose
    .family<B2bQuoteRequest?, String>((ref, id) {
      ref.watch(b2bMarketControllerProvider);
      return ref.watch(b2bRepositoryProvider).quoteRequestById(id);
    });

/// Bir talebe gelen teklif cevapları (detay ekranı).
final b2bRepliesProvider = FutureProvider.autoDispose
    .family<List<B2bQuoteReply>, String>((ref, id) {
      ref.watch(b2bMarketControllerProvider);
      return ref.watch(b2bRepositoryProvider).repliesFor(id);
    });

/// Alıcının kendi talebine ait lead'ler (her reply'in ilgi durumu).
final b2bRequestLeadsProvider = FutureProvider.autoDispose
    .family<List<B2bQuoteLead>, String>((ref, id) {
      ref.watch(b2bMarketControllerProvider);
      return ref.watch(b2bRepositoryProvider).leadsForMyQuoteRequest(id);
    });

/// Tedarikçinin kendi mağazasına gelen lead'ler ("İlgilenenler").
final b2bSupplierLeadsProvider = FutureProvider.autoDispose<List<B2bQuoteLead>>(
  (ref) {
    ref.watch(b2bMarketControllerProvider);
    return ref.watch(b2bRepositoryProvider).leadsForMySupplierShop();
  },
);

/// S2 — Tedarikçinin verdiği tüm teklif cevapları (kendi mağazası, RLS).
final b2bMyRepliesProvider = FutureProvider.autoDispose<List<B2bQuoteReply>>((
  ref,
) {
  ref.watch(b2bMarketControllerProvider);
  return ref.watch(b2bRepositoryProvider).listMyQuoteReplies();
});

/// S3 — Yanıtladığım talepler (sunucu RPC; migration yoksa null → S2 eşleme).
final b2bMyRepliedRequestsProvider =
    FutureProvider.autoDispose<List<B2bRepliedRequest>?>((ref) {
  ref.watch(b2bMarketControllerProvider);
  return ref.watch(b2bRepositoryProvider).listMyRepliedRequests();
});

/// S3 — Sunucu sayaçları (RPC yoksa null → gelen kutusundan hesap).
final b2bSupplierRequestCountsProvider =
    FutureProvider.autoDispose<B2bSupplierRequestCounts?>((ref) {
  ref.watch(b2bMarketControllerProvider);
  return ref.watch(b2bRepositoryProvider).supplierRequestCounts();
});

/// S2/S3 — Talepler gelen kutusu: açık talepler + cevaplarım + lead'ler (+ S3
/// geçmiş RPC'si varsa kapanmış/karar verilmiş taleplerin ayrıntısı) tek
/// hesapta (Yeni / Yanıtladıklarım / İlgilenenler / Kazanılan). Kaynaklardan
/// biri hata verirse bütün kutu hata (retry hepsini yeniler). Panel KPI'sı ve
/// Talepler sekmesi aynı kaynağı kullanır → sayılar birbirini tutar.
final supplierRequestsInboxProvider =
    FutureProvider.autoDispose<SupplierRequestsInbox>((ref) async {
  final open = ref.watch(b2bOpenQuoteRequestsProvider.future);
  final replies = ref.watch(b2bMyRepliesProvider.future);
  final leads = ref.watch(b2bSupplierLeadsProvider.future);
  final history = ref.watch(b2bMyRepliedRequestsProvider.future);
  final counts = ref.watch(b2bSupplierRequestCountsProvider.future);
  return SupplierRequestsInbox.build(
    openRequests: await open,
    myReplies: await replies,
    leads: await leads,
    history: await history,
    serverCounts: await counts,
  );
});

void supplierRequestsInboxRefresh(WidgetRef ref) {
  ref.invalidate(b2bOpenQuoteRequestsProvider);
  ref.invalidate(b2bMyRepliesProvider);
  ref.invalidate(b2bSupplierLeadsProvider);
  ref.invalidate(b2bMyRepliedRequestsProvider);
  ref.invalidate(b2bSupplierRequestCountsProvider);
}

/// S3 — Yeni talepler sayfası (sunucu filtre + sayfalama). Anahtar: filtre +
/// offset. RPC yoksa null (UI gelen kutusundaki istemci listesine düşer).
typedef B2bFreshPageKey = ({
  List<String>? categories,
  List<String>? cities,
  int offset,
  int limit,
});

final b2bFreshRequestsPageProvider = FutureProvider.autoDispose
    .family<B2bOpenRequestsPage?, String>((ref, keyJson) {
  ref.watch(b2bMarketControllerProvider);
  final key = decodeFreshPageKey(keyJson);
  return ref.watch(b2bRepositoryProvider).listOpenQuoteRequestsPage(
        categories: key.categories,
        cities: key.cities,
        excludeReplied: true,
        limit: key.limit,
        offset: key.offset,
      );
});

/// Family anahtarı JSON (record family anahtarı olarak equatable değil).
String encodeFreshPageKey(B2bFreshPageKey k) => jsonEncode({
      'c': k.categories,
      't': k.cities,
      'o': k.offset,
      'l': k.limit,
    });

B2bFreshPageKey decodeFreshPageKey(String s) {
  final m = jsonDecode(s) as Map<String, dynamic>;
  List<String>? asList(dynamic v) =>
      v == null ? null : (v as List).map((e) => e.toString()).toList();
  return (
    categories: asList(m['c']),
    cities: asList(m['t']),
    offset: (m['o'] as num).toInt(),
    limit: (m['l'] as num).toInt(),
  );
}

/// Bir lead'in takip mesajları (mini görüşme).
final b2bLeadMessagesProvider = FutureProvider.autoDispose
    .family<List<B2bLeadMessage>, String>((ref, leadId) {
      ref.watch(b2bMarketControllerProvider);
      return ref.watch(b2bRepositoryProvider).messagesForLead(leadId);
    });

/// Tek ürün detayı.
final b2bProductDetailProvider = FutureProvider.autoDispose
    .family<B2bProduct?, String>((ref, id) {
      ref.watch(b2bMarketControllerProvider);
      return ref.watch(b2bRepositoryProvider).productById(id);
    });

/// Tek kampanya detayı.
final b2bCampaignDetailProvider = FutureProvider.autoDispose
    .family<B2bCampaign?, String>((ref, id) {
      ref.watch(b2bMarketControllerProvider);
      return ref.watch(b2bRepositoryProvider).campaignById(id);
    });

/// Tek mağaza detayı.
final b2bStoreDetailProvider = FutureProvider.autoDispose
    .family<B2bStore?, String>((ref, id) {
      ref.watch(b2bMarketControllerProvider);
      return ref.watch(b2bRepositoryProvider).storeById(id);
    });

/// Mağazanın yayındaki ürünleri (mağaza detayı).
final b2bStoreProductsProvider = FutureProvider.autoDispose
    .family<List<B2bProduct>, String>((ref, id) {
      ref.watch(b2bMarketControllerProvider);
      return ref.watch(b2bRepositoryProvider).productsForStore(id);
    });

/// Mağazanın yayındaki kampanyaları (mağaza detayı).
final b2bStoreCampaignsProvider = FutureProvider.autoDispose
    .family<List<B2bCampaign>, String>((ref, id) {
      ref.watch(b2bMarketControllerProvider);
      return ref.watch(b2bRepositoryProvider).campaignsForStore(id);
    });

/// Pazar'a giren kullanıcının B2B görünüm rolü.
enum B2bRole { supplier, buyer }

extension B2bRoleX on B2bRole {
  String get headerSubtitle {
    switch (this) {
      case B2bRole.supplier:
        return 'B2B tedarik ağı';
      case B2bRole.buyer:
        return 'Fırının için ürün ve tedarikçi keşfi';
    }
  }
}

/// Yalnız test/development için rol zorlama. Üretimde `null`.
final b2bRoleOverrideProvider = StateProvider<B2bRole?>((ref) => null);

/// Tek role resolution noktası.
final b2bRoleProvider = Provider<B2bRole>((ref) {
  final override = ref.watch(b2bRoleOverrideProvider);
  if (override != null) return override;
  final account = ref.watch(
    profileControllerProvider.select((p) => p?.accountType),
  );
  return account == AccountType.wholesaler ? B2bRole.supplier : B2bRole.buyer;
});
