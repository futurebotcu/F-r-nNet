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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/b2b_campaign.dart';
import '../models/b2b_product.dart';
import '../models/b2b_quote_reply.dart';
import '../models/b2b_quote_request.dart';
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
final b2bMarketControllerProvider =
    NotifierProvider<B2bMarketController, int>(B2bMarketController.new);

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
  }) async {
    await _repo.addProduct(
      name: name,
      category: category,
      minOrder: minOrder,
      deliveryRegion: deliveryRegion,
      description: description,
      published: published,
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
    String description = '',
    bool published = true,
  }) async {
    await _repo.addCampaign(
      title: title,
      category: category,
      region: region,
      minPurchase: minPurchase,
      validUntil: validUntil,
      linkedProduct: linkedProduct,
      description: description,
      published: published,
    );
    state++;
  }

  Future<void> updateStore({
    required String name,
    required String description,
    required List<String> serviceRegions,
    required List<String> categories,
  }) async {
    await _repo.updateStore(
      name: name,
      description: description,
      serviceRegions: serviceRegions,
      categories: categories,
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
  }) async {
    await _repo.updateProduct(
      id: id,
      name: name,
      category: category,
      minOrder: minOrder,
      deliveryRegion: deliveryRegion,
      description: description,
      published: published,
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
    String description = '',
    bool published = true,
  }) async {
    await _repo.updateCampaign(
      id: id,
      title: title,
      category: category,
      region: region,
      minPurchase: minPurchase,
      validUntil: validUntil,
      linkedProduct: linkedProduct,
      description: description,
      published: published,
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
}

// ---- Okuma FutureProvider'ları (write revizyonunu izler → otomatik yenilenir) ----

/// Ürün listesi filtre anahtarı (FutureProvider.family için equatable record).
typedef B2bProductQuery = ({String? category, String query});

final b2bMyStoreProvider = FutureProvider.autoDispose<B2bStore>((ref) {
  ref.watch(b2bMarketControllerProvider);
  return ref.watch(b2bRepositoryProvider).myStore();
});

final b2bMyProductsProvider =
    FutureProvider.autoDispose<List<B2bProduct>>((ref) {
  ref.watch(b2bMarketControllerProvider);
  return ref.watch(b2bRepositoryProvider).listMyProducts();
});

final b2bMyCampaignsProvider =
    FutureProvider.autoDispose<List<B2bCampaign>>((ref) {
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
