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

import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/b2b_campaign.dart';
import '../models/b2b_product.dart';
import '../models/b2b_quote_request.dart';
import '../models/b2b_store.dart';
import '../repositories/b2b_repository.dart';
import '../repositories/local_b2b_repository.dart';

/// B2B repository sağlayıcısı. Şimdilik Local (mock); Supabase seçimi Adım C.
final b2bRepositoryProvider = Provider<B2bRepository>((ref) {
  return LocalB2bRepository();
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
