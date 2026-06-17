// B2B Pazar — yerel mock repository (varsayılan + guest/offline fallback).
//
// In-memory mutable: seed veriler başlangıçta kopyalanır; write'lar bu kopyaları
// günceller. Backend/persist YOK — uygulama kapatılınca eklenenler kaybolur.
// Async interface'e uyumludur (IO yoktur; gövdeler senkron tamamlanır).
//
// Yayın kuralı: Taslak (published=false) ürün/kampanyalar genel pazarda
// görünmez; yalnız sahibinin Mağazam listelerinde görünür.

import '../data/b2b_mock_seed.dart';
import '../models/b2b_campaign.dart';
import '../models/b2b_product.dart';
import '../models/b2b_quote_reply.dart';
import '../models/b2b_quote_request.dart';
import '../models/b2b_store.dart';
import 'b2b_repository.dart';

class LocalB2bRepository implements B2bRepository {
  LocalB2bRepository()
      : _stores = List<B2bStore>.of(B2bMockSeed.stores),
        _products = List<B2bProduct>.of(B2bMockSeed.products),
        _campaigns = List<B2bCampaign>.of(B2bMockSeed.campaigns);

  final List<B2bStore> _stores;
  final List<B2bProduct> _products;
  final List<B2bCampaign> _campaigns;

  int _seq = 0;

  String get _mySupplierId => B2bMockSeed.mySupplierId;

  int _myStoreIndex() {
    final i = _stores.indexWhere((s) => s.id == _mySupplierId);
    return i >= 0 ? i : 0;
  }

  @override
  Future<B2bStore> myStore() async => _stores[_myStoreIndex()];

  @override
  Future<List<B2bStore>> listStores() async =>
      List<B2bStore>.unmodifiable(_stores);

  @override
  List<String> productCategories() =>
      List<String>.unmodifiable(B2bMockSeed.productCategories);

  @override
  List<String> serviceRegions() =>
      List<String>.unmodifiable(B2bMockSeed.serviceRegions);

  @override
  Future<List<B2bProduct>> listProducts({String? category, String? query}) async {
    final q = (query ?? '').trim().toLowerCase();
    return _products.where((p) {
      if (!p.published) return false;
      final categoryOk = category == null || p.category == category;
      final queryOk = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.supplierName.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
      return categoryOk && queryOk;
    }).toList(growable: false);
  }

  @override
  Future<List<B2bProduct>> listMyProducts() async => _products
      .where((p) => p.supplierId == _mySupplierId)
      .toList(growable: false);

  @override
  Future<List<B2bCampaign>> listCampaigns({String? category}) async {
    return _campaigns
        .where((c) =>
            c.published && (category == null || c.category == category))
        .toList(growable: false);
  }

  @override
  Future<List<B2bCampaign>> listMyCampaigns() async => _campaigns
      .where((c) => c.supplierId == _mySupplierId)
      .toList(growable: false);

  @override
  Future<List<B2bQuoteRequest>> listOpenQuoteRequests() async =>
      List<B2bQuoteRequest>.unmodifiable(B2bMockSeed.openQuoteRequests);

  @override
  Future<List<B2bQuoteRequest>> listMyQuoteRequests() async =>
      List<B2bQuoteRequest>.unmodifiable(B2bMockSeed.myQuoteRequests);

  @override
  Future<List<B2bQuoteReply>> repliesFor(String requestId) async =>
      B2bMockSeed.replies
          .where((r) => r.requestId == requestId)
          .toList(growable: false);

  // ---- Write ----

  @override
  Future<B2bProduct> addProduct({
    required String name,
    required String category,
    required String minOrder,
    required String deliveryRegion,
    String description = '',
    bool published = true,
  }) async {
    final store = _stores[_myStoreIndex()];
    final product = B2bProduct(
      id: 'p_user_${++_seq}',
      name: name,
      supplierId: store.id,
      supplierName: store.name,
      category: category,
      minOrder: minOrder,
      deliveryRegion: deliveryRegion,
      description: description,
      published: published,
      isMine: true,
    );
    _products.insert(0, product);
    return product;
  }

  @override
  Future<B2bCampaign> addCampaign({
    required String title,
    required String category,
    required String region,
    required String minPurchase,
    required String validUntil,
    String? linkedProduct,
    String description = '',
    bool published = true,
  }) async {
    final store = _stores[_myStoreIndex()];
    final campaign = B2bCampaign(
      id: 'c_user_${++_seq}',
      title: title,
      supplierId: store.id,
      supplierName: store.name,
      category: category,
      region: region,
      minPurchase: minPurchase,
      validUntil: validUntil,
      linkedProduct: linkedProduct,
      description: description,
      published: published,
      isMine: true,
    );
    _campaigns.insert(0, campaign);
    return campaign;
  }

  @override
  Future<B2bStore> updateStore({
    required String name,
    required String description,
    required List<String> serviceRegions,
    required List<String> categories,
  }) async {
    final i = _myStoreIndex();
    final old = _stores[i];
    final updated = B2bStore(
      id: old.id,
      name: name,
      monogram: _monogramFor(name, fallback: old.monogram),
      tagline: old.tagline,
      description: description,
      categories: List<String>.of(categories),
      serviceRegions: List<String>.of(serviceRegions),
      productCount: old.productCount,
      campaignCount: old.campaignCount,
      isMine: old.isMine,
    );
    _stores[i] = updated;
    return updated;
  }

  @override
  Future<B2bProduct?> productById(String id) async {
    final i = _products.indexWhere((p) => p.id == id);
    return i >= 0 ? _products[i] : null;
  }

  @override
  Future<B2bCampaign?> campaignById(String id) async {
    final i = _campaigns.indexWhere((c) => c.id == id);
    return i >= 0 ? _campaigns[i] : null;
  }

  @override
  Future<B2bProduct> updateProduct({
    required String id,
    required String name,
    required String category,
    required String minOrder,
    required String deliveryRegion,
    String description = '',
    bool published = true,
  }) async {
    final i = _products.indexWhere((p) => p.id == id);
    if (i < 0) {
      return addProduct(
        name: name,
        category: category,
        minOrder: minOrder,
        deliveryRegion: deliveryRegion,
        description: description,
        published: published,
      );
    }
    final updated = _products[i].copyWith(
      name: name,
      category: category,
      minOrder: minOrder,
      deliveryRegion: deliveryRegion,
      description: description,
      published: published,
    );
    _products[i] = updated;
    return updated;
  }

  @override
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
  }) async {
    final i = _campaigns.indexWhere((c) => c.id == id);
    if (i < 0) {
      return addCampaign(
        title: title,
        category: category,
        region: region,
        minPurchase: minPurchase,
        validUntil: validUntil,
        linkedProduct: linkedProduct,
        description: description,
        published: published,
      );
    }
    final updated = _campaigns[i].copyWith(
      title: title,
      category: category,
      region: region,
      minPurchase: minPurchase,
      validUntil: validUntil,
      linkedProduct: linkedProduct,
      description: description,
      published: published,
    );
    _campaigns[i] = updated;
    return updated;
  }

  @override
  Future<void> setProductPublished(String id, bool published) async {
    final i = _products.indexWhere((p) => p.id == id);
    if (i >= 0) _products[i] = _products[i].copyWith(published: published);
  }

  @override
  Future<void> setCampaignPublished(String id, bool published) async {
    final i = _campaigns.indexWhere((c) => c.id == id);
    if (i >= 0) _campaigns[i] = _campaigns[i].copyWith(published: published);
  }

  static String _monogramFor(String name, {required String fallback}) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return fallback;
    if (words.length == 1) {
      final w = words.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }
}
