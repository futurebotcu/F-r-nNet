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
import '../models/b2b_lead_message.dart';
import '../models/b2b_product.dart';
import '../models/b2b_quote_lead.dart';
import '../models/b2b_quote_reply.dart';
import '../models/b2b_quote_request.dart';
import '../models/b2b_store.dart';
import 'b2b_repository.dart';

class LocalB2bRepository implements B2bRepository {
  LocalB2bRepository()
      : _stores = List<B2bStore>.of(B2bMockSeed.stores),
        _products = List<B2bProduct>.of(B2bMockSeed.products),
        _campaigns = List<B2bCampaign>.of(B2bMockSeed.campaigns),
        _myQuoteRequests =
            List<B2bQuoteRequest>.of(B2bMockSeed.myQuoteRequests),
        _replies = List<B2bQuoteReply>.of(B2bMockSeed.replies);

  final List<B2bStore> _stores;
  final List<B2bProduct> _products;
  final List<B2bCampaign> _campaigns;
  final List<B2bQuoteRequest> _myQuoteRequests;
  final List<B2bQuoteReply> _replies;
  final List<B2bQuoteLead> _leads = <B2bQuoteLead>[];
  final List<B2bLeadMessage> _leadMessages = <B2bLeadMessage>[];

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
  Future<B2bStore?> storeById(String id) async {
    final i = _stores.indexWhere((s) => s.id == id);
    return i >= 0 ? _stores[i] : null;
  }

  @override
  Future<List<B2bProduct>> productsForStore(String storeId) async => _products
      .where((p) => p.supplierId == storeId && p.published)
      .toList(growable: false);

  @override
  Future<List<B2bCampaign>> campaignsForStore(String storeId) async =>
      _campaigns
          .where((c) => c.supplierId == storeId && c.published)
          .toList(growable: false);

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
  Future<List<B2bQuoteRequest>> listMyQuoteRequests() async => _myQuoteRequests
      .map((q) => q.copyWith(
            replyCount: _replies.where((r) => r.requestId == q.id).length,
          ))
      .toList(growable: false);

  @override
  Future<B2bQuoteRequest?> quoteRequestById(String id) async {
    final i = _myQuoteRequests.indexWhere((q) => q.id == id);
    if (i < 0) return null;
    final q = _myQuoteRequests[i];
    return q.copyWith(
      replyCount: _replies.where((r) => r.requestId == q.id).length,
    );
  }

  @override
  Future<List<B2bQuoteReply>> repliesFor(String requestId) async => _replies
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
    String? imageUrl,
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
      imageUrl: imageUrl,
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
    String? imageUrl,
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
      imageUrl: imageUrl,
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
    String? logoUrl,
    String? coverUrl,
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
      logoUrl: logoUrl ?? old.logoUrl,
      coverUrl: coverUrl ?? old.coverUrl,
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
    String? imageUrl,
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
        imageUrl: imageUrl,
      );
    }
    final updated = _products[i].copyWith(
      name: name,
      category: category,
      minOrder: minOrder,
      deliveryRegion: deliveryRegion,
      description: description,
      published: published,
      imageUrl: imageUrl,
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
    String? imageUrl,
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
        imageUrl: imageUrl,
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
      imageUrl: imageUrl,
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

  @override
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
  }) async {
    final req = B2bQuoteRequest(
      id: 'q_user_${++_seq}',
      productOrCategory: category,
      quantity: quantity,
      city: city,
      district: district,
      buyerType: buyerType,
      deliveryTime: deliveryTime,
      note: note,
      status: B2bQuoteStatus.waiting,
      createdByMe: true,
    );
    _myQuoteRequests.insert(0, req);
    return req;
  }

  @override
  Future<void> addQuoteReply({
    required String quoteRequestId,
    required String message,
    String? priceNote,
    String? deliveryNote,
  }) async {
    // Kapalı/iptal talebe teklif verilemez (DB guard'ının yerel karşılığı).
    final i = _myQuoteRequests.indexWhere((q) => q.id == quoteRequestId);
    if (i >= 0 && _myQuoteRequests[i].status.isTerminal) {
      throw StateError('Kapalı/iptal talebe teklif verilemez.');
    }
    _replies.insert(
      0,
      B2bQuoteReply(
        id: 'r_user_${++_seq}',
        requestId: quoteRequestId,
        supplierName: _stores[_myStoreIndex()].name,
        supplierShopId: _stores[_myStoreIndex()].id,
        message: message,
        createdAtLabel: 'Az önce',
        priceHint: (priceNote == null || priceNote.isEmpty) ? null : priceNote,
        deliveryNote:
            (deliveryNote == null || deliveryNote.isEmpty) ? null : deliveryNote,
      ),
    );
  }

  @override
  Future<void> closeQuoteRequest(String id) async => _setStatus(
        id,
        B2bQuoteStatus.closed,
      );

  @override
  Future<void> cancelQuoteRequest(String id) async => _setStatus(
        id,
        B2bQuoteStatus.cancelled,
      );

  void _setStatus(String id, B2bQuoteStatus status) {
    final i = _myQuoteRequests.indexWhere((q) => q.id == id);
    if (i >= 0) _myQuoteRequests[i] = _myQuoteRequests[i].copyWith(status: status);
  }

  // ---- Lead (ilgi) kanalı ----

  void _addLead({
    required String quoteReplyId,
    required B2bLeadStatus status,
    String message = '',
    bool phoneShared = false,
    String? phone,
  }) {
    final reply = _replies.firstWhere(
      (r) => r.id == quoteReplyId,
      orElse: () => throw StateError('Teklif bulunamadı.'),
    );
    final reqIndex =
        _myQuoteRequests.indexWhere((q) => q.id == reply.requestId);
    if (reqIndex >= 0 && _myQuoteRequests[reqIndex].status.isTerminal) {
      throw StateError('Kapalı/iptal talebe ilgi gönderilemez.');
    }
    if (_leads.any((l) => l.quoteReplyId == quoteReplyId)) {
      throw StateError('Bu teklife zaten yanıt verdiniz.');
    }
    final req = reqIndex >= 0 ? _myQuoteRequests[reqIndex] : null;
    _leads.add(B2bQuoteLead(
      id: 'lead_${++_seq}',
      quoteRequestId: reply.requestId,
      quoteReplyId: quoteReplyId,
      supplierShopId: reply.supplierShopId ?? '',
      status: status,
      supplierName: reply.supplierName,
      buyerMessage: message.isEmpty ? null : message,
      phoneShared: phoneShared,
      sharedPhone: phoneShared ? phone : null,
      createdAtLabel: 'Az önce',
      requestCategory: req?.productOrCategory ?? '',
      requestQuantity: req?.quantity ?? '',
      requestCity: req?.city ?? '',
    ));
  }

  @override
  Future<void> expressInterestInQuoteReply({
    required String quoteReplyId,
    String message = '',
    bool phoneShared = false,
    String? phone,
  }) async =>
      _addLead(
        quoteReplyId: quoteReplyId,
        status: B2bLeadStatus.interested,
        message: message,
        phoneShared: phoneShared,
        phone: phone,
      );

  @override
  Future<void> rejectQuoteReply(String quoteReplyId) async =>
      _addLead(quoteReplyId: quoteReplyId, status: B2bLeadStatus.rejected);

  @override
  Future<List<B2bQuoteLead>> leadsForMyQuoteRequest(
          String quoteRequestId) async =>
      _leads
          .where((l) => l.quoteRequestId == quoteRequestId)
          .toList(growable: false);

  @override
  Future<List<B2bQuoteLead>> leadsForMySupplierShop() async {
    final myShopId = _stores[_myStoreIndex()].id;
    return _leads.where((l) => l.supplierShopId == myShopId).map((l) {
      final accepted = _replies.any((r) => r.id == l.quoteReplyId && r.accepted);
      return l.copyWith(replyAccepted: accepted);
    }).toList(growable: false);
  }

  @override
  Future<void> acceptQuoteReply(String quoteReplyId) async {
    final reply = _replies.firstWhere(
      (r) => r.id == quoteReplyId,
      orElse: () => throw StateError('Teklif bulunamadı.'),
    );
    final reqIndex =
        _myQuoteRequests.indexWhere((q) => q.id == reply.requestId);
    if (reqIndex >= 0 && _myQuoteRequests[reqIndex].status.isTerminal) {
      throw StateError('Kapalı/iptal talepte teklif kabul edilemez.');
    }
    if (reqIndex >= 0) {
      _myQuoteRequests[reqIndex] =
          _myQuoteRequests[reqIndex].copyWith(acceptedReplyId: quoteReplyId);
    }
    // Aynı talebin tek teklifi seçili olur.
    for (var i = 0; i < _replies.length; i++) {
      if (_replies[i].requestId == reply.requestId) {
        _replies[i] =
            _replies[i].copyWith(accepted: _replies[i].id == quoteReplyId);
      }
    }
  }

  @override
  Future<void> sendLeadMessage({
    required String leadId,
    required String message,
  }) async {
    if (message.trim().isEmpty) {
      throw StateError('Boş mesaj gönderilemez.');
    }
    if (!_leads.any((l) => l.id == leadId)) {
      throw StateError('Lead bulunamadı.');
    }
    // Local (guest/demo): gönderen alıcı kabul edilir (gerçek rol Supabase
    // RPC'sinde lead üyeliğinden türetilir).
    _leadMessages.add(B2bLeadMessage(
      id: 'lmsg_${++_seq}',
      leadId: leadId,
      senderRole: B2bLeadSenderRole.buyer,
      message: message.trim(),
      createdAtLabel: 'Az önce',
    ));
  }

  @override
  Future<List<B2bLeadMessage>> messagesForLead(String leadId) async =>
      _leadMessages
          .where((m) => m.leadId == leadId)
          .toList(growable: false);

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
