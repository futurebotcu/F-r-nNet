// B2B Pazar — Supabase repository (Adım B).
//
// B2bRepository (async) interface'ini gerçek Supabase backend ile uygular.
// Bu sınıf bu adımda HENÜZ AKTİF DEĞİL — provider varsayılanı LocalB2bRepository
// kalır (Adım C). Burada amaç: tam mapping + metotların hazır olması.
//
// ANONİMLİK: Teklif Ağı (tedarikçinin gördüğü açık talepler) DOĞRUDAN
// b2b_quote_requests tablosundan OKUNMAZ; yalnız rpc('b2b_open_quote_requests')
// üzerinden okunur (buyer_id döndürmez). "Tekliflerim" ise tabloyu yalnız
// kendi buyer_id'siyle (RLS) okur. buyer_id / telefon / adres / kişi adı
// modele HİÇ taşınmaz.
//
// Görsel: image_url/logo_url/cover_url kolonları nullable; upload YOK, modele
// taşınmaz (modellerde bu alanlar yoktur).

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/b2b_campaign.dart';
import '../models/b2b_product.dart';
import '../models/b2b_quote_lead.dart';
import '../models/b2b_quote_reply.dart';
import '../models/b2b_quote_request.dart';
import '../models/b2b_store.dart';
import 'b2b_repository.dart';

class SupabaseB2bRepository implements B2bRepository {
  SupabaseB2bRepository(this._client);

  final sb.SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  static const _shopCols =
      'id, owner_id, shop_name, description, city, district, '
      'service_regions, categories, logo_url, cover_url, is_active, '
      'is_verified, created_at, updated_at';

  // Ürün/kampanya: tedarikçi adı + sahiplik için mağaza embed edilir.
  static const _productCols =
      'id, shop_id, name, category, min_order, delivery_regions, price_type, '
      'description, image_url, published, created_at, '
      'b2b_supplier_shops!inner(shop_name, owner_id)';
  static const _campaignCols =
      'id, shop_id, title, category, linked_product_id, regions, min_order, '
      'valid_until, description, image_url, published, created_at, '
      'b2b_supplier_shops!inner(shop_name, owner_id)';

  // ---- Sabit referans (DB tablosu değil) ----
  @override
  List<String> productCategories() => const [
        'Un', 'Maya', 'Katkı', 'Yağ', 'Ambalaj', 'Ekipman',
      ];

  @override
  List<String> serviceRegions() => const [
        'Marmara', 'Ege', 'İç Anadolu', 'Akdeniz', 'Karadeniz',
        'Doğu Anadolu', 'Güneydoğu', 'Tüm Türkiye',
      ];

  // ---- Mapper'lar (test edilebilir; gerçek client gerekmez) ----

  static String monogramFor(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  static List<String> _strList(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? const <String>[];

  static B2bQuoteStatus statusFromText(String? s) {
    switch (s) {
      case 'answered':
      case 'replied': // geriye dönük
        return B2bQuoteStatus.replied;
      case 'closed':
        return B2bQuoteStatus.closed;
      case 'cancelled':
        return B2bQuoteStatus.cancelled;
      case 'open':
      default:
        return B2bQuoteStatus.waiting;
    }
  }

  static String _dateLabel(dynamic isoOrDate) {
    if (isoOrDate == null) return '';
    final s = isoOrDate.toString();
    return s.contains('T') ? s.split('T').first : s;
  }

  static B2bStore storeFromRow(
    Map<String, dynamic> row, {
    String? currentUserId,
  }) {
    final name = (row['shop_name'] ?? '').toString();
    return B2bStore(
      id: (row['id'] ?? '').toString(),
      name: name,
      monogram: monogramFor(name),
      tagline: '', // DB'de yok — opsiyonel pazarlama satırı; boş kalır.
      description: (row['description'] ?? '').toString(),
      categories: _strList(row['categories']),
      serviceRegions: _strList(row['service_regions']),
      productCount: 0, // sayaç DB'de tutulmaz; ileride agregat ile (gap).
      campaignCount: 0,
      isMine: currentUserId != null && row['owner_id'] == currentUserId,
      logoUrl: row['logo_url'] as String?,
      coverUrl: row['cover_url'] as String?,
    );
  }

  static B2bProduct productFromRow(
    Map<String, dynamic> row, {
    String? currentUserId,
  }) {
    final shop = row['b2b_supplier_shops'] as Map<String, dynamic>?;
    return B2bProduct(
      id: (row['id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      supplierId: (row['shop_id'] ?? '').toString(),
      supplierName: (shop?['shop_name'] ?? '').toString(),
      category: (row['category'] ?? '').toString(),
      minOrder: (row['min_order'] ?? '').toString(),
      deliveryRegion: _strList(row['delivery_regions']).join(', '),
      description: (row['description'] ?? '').toString(),
      published: (row['published'] as bool?) ?? true,
      isMine: currentUserId != null && shop?['owner_id'] == currentUserId,
      imageUrl: row['image_url'] as String?,
    );
  }

  static B2bCampaign campaignFromRow(
    Map<String, dynamic> row, {
    String? currentUserId,
  }) {
    final shop = row['b2b_supplier_shops'] as Map<String, dynamic>?;
    final validUntil = row['valid_until'];
    return B2bCampaign(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      supplierId: (row['shop_id'] ?? '').toString(),
      supplierName: (shop?['shop_name'] ?? '').toString(),
      category: (row['category'] ?? '').toString(),
      region: _strList(row['regions']).join(', '),
      minPurchase: (row['min_order'] ?? '').toString(),
      validUntil: validUntil == null ? 'Süresiz' : _dateLabel(validUntil),
      description: (row['description'] ?? '').toString(),
      published: (row['published'] as bool?) ?? true,
      isMine: currentUserId != null && shop?['owner_id'] == currentUserId,
      imageUrl: row['image_url'] as String?,
    );
  }

  /// Hem tablo (Tekliflerim) hem RPC (Teklif Ağı) satırları için. Her iki
  /// kaynak da buyer_id içermez/taşımaz — anonimlik korunur.
  static B2bQuoteRequest quoteRequestFromRow(
    Map<String, dynamic> row, {
    bool createdByMe = false,
  }) {
    return B2bQuoteRequest(
      id: (row['id'] ?? '').toString(),
      productOrCategory: (row['category'] ?? '').toString(),
      quantity: (row['quantity'] ?? '').toString(),
      city: (row['city'] ?? '').toString(),
      district: (row['district'] ?? '').toString(),
      buyerType: (row['buyer_type'] ?? '').toString(),
      deliveryTime: (row['delivery_time'] ?? '').toString(),
      note: (row['note'] ?? '').toString(),
      status: statusFromText(row['status'] as String?),
      createdByMe: createdByMe,
    );
  }

  static B2bQuoteReply quoteReplyFromRow(Map<String, dynamic> row) {
    final shop = row['b2b_supplier_shops'] as Map<String, dynamic>?;
    return B2bQuoteReply(
      id: (row['id'] ?? '').toString(),
      requestId: (row['quote_request_id'] ?? '').toString(),
      supplierName: (shop?['shop_name'] ?? '').toString(),
      message: (row['message'] ?? '').toString(),
      createdAtLabel: _dateLabel(row['created_at']),
      priceHint: row['price_note'] as String?,
      deliveryNote: row['delivery_note'] as String?,
      supplierShopId: row['supplier_shop_id']?.toString(),
    );
  }

  // ---- Mağaza ----

  Future<Map<String, dynamic>?> _myShopRow() async {
    final uid = _uid;
    if (uid == null) return null;
    return _client
        .from('b2b_supplier_shops')
        .select(_shopCols)
        .eq('owner_id', uid)
        .maybeSingle();
  }

  Future<String?> _myShopId() async => (await _myShopRow())?['id'] as String?;

  @override
  Future<B2bStore> myStore() async {
    final row = await _myShopRow();
    if (row == null) {
      // Henüz mağaza yok → boş vitrin (form upsert ile oluşturur).
      return B2bStore(
        id: '',
        name: '',
        monogram: '?',
        tagline: '',
        description: '',
        categories: const [],
        serviceRegions: const [],
        productCount: 0,
        campaignCount: 0,
        isMine: true,
      );
    }
    return storeFromRow(row, currentUserId: _uid);
  }

  @override
  Future<List<B2bStore>> listStores() async {
    final rows = await _client
        .from('b2b_supplier_shops')
        .select(_shopCols)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    final uid = _uid;
    final stores =
        rows.map((r) => storeFromRow(r, currentUserId: uid)).toList();
    if (stores.isEmpty) return stores;
    // Yayındaki ürün/kampanya sayıları — tek grouped sorgu (kartta doğru sayı).
    final ids = stores.map((s) => s.id).toList();
    final counts = await _shopCounts(ids);
    return stores
        .map((s) => s.copyWith(
              productCount: counts.products[s.id] ?? 0,
              campaignCount: counts.campaigns[s.id] ?? 0,
            ))
        .toList(growable: false);
  }

  /// Mağaza id'leri için yayındaki ürün/kampanya sayıları (bellekte say).
  Future<({Map<String, int> products, Map<String, int> campaigns})>
      _shopCounts(List<String> shopIds) async {
    final prod = <String, int>{};
    final camp = <String, int>{};
    final pRows = await _client
        .from('b2b_products')
        .select('shop_id')
        .inFilter('shop_id', shopIds)
        .eq('published', true);
    for (final r in pRows) {
      final k = (r['shop_id'] ?? '').toString();
      prod[k] = (prod[k] ?? 0) + 1;
    }
    final cRows = await _client
        .from('b2b_campaigns')
        .select('shop_id')
        .inFilter('shop_id', shopIds)
        .eq('published', true);
    for (final r in cRows) {
      final k = (r['shop_id'] ?? '').toString();
      camp[k] = (camp[k] ?? 0) + 1;
    }
    return (products: prod, campaigns: camp);
  }

  @override
  Future<B2bStore?> storeById(String id) async {
    final row = await _client
        .from('b2b_supplier_shops')
        .select(_shopCols)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : storeFromRow(row, currentUserId: _uid);
  }

  @override
  Future<List<B2bProduct>> productsForStore(String storeId) async {
    final rows = await _client
        .from('b2b_products')
        .select(_productCols)
        .eq('shop_id', storeId)
        .eq('published', true)
        .order('created_at', ascending: false);
    final uid = _uid;
    return rows
        .map((r) => productFromRow(r, currentUserId: uid))
        .toList(growable: false);
  }

  @override
  Future<List<B2bCampaign>> campaignsForStore(String storeId) async {
    final rows = await _client
        .from('b2b_campaigns')
        .select(_campaignCols)
        .eq('shop_id', storeId)
        .eq('published', true)
        .order('created_at', ascending: false);
    final uid = _uid;
    return rows
        .map((r) => campaignFromRow(r, currentUserId: uid))
        .toList(growable: false);
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
    final uid = _uid;
    if (uid == null) throw StateError('Oturum bulunamadı.');
    final row = await _client
        .from('b2b_supplier_shops')
        .upsert({
          'owner_id': uid,
          'shop_name': name,
          'description': description,
          'service_regions': serviceRegions,
          'categories': categories,
          if (logoUrl != null) 'logo_url': logoUrl,
          if (coverUrl != null) 'cover_url': coverUrl,
        }, onConflict: 'owner_id')
        .select(_shopCols)
        .single();
    return storeFromRow(row, currentUserId: uid);
  }

  // ---- Ürünler ----

  @override
  Future<List<B2bProduct>> listProducts({String? category, String? query}) async {
    final base = _client.from('b2b_products').select(_productCols).eq(
          'published',
          true,
        );
    final filtered = category != null ? base.eq('category', category) : base;
    final rows = await filtered.order('created_at', ascending: false);
    final uid = _uid;
    var list =
        rows.map((r) => productFromRow(r, currentUserId: uid)).toList();
    final q = (query ?? '').trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.supplierName.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Future<List<B2bProduct>> listMyProducts() async {
    final shopId = await _myShopId();
    if (shopId == null) return const [];
    final rows = await _client
        .from('b2b_products')
        .select(_productCols)
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);
    final uid = _uid;
    return rows
        .map((r) => productFromRow(r, currentUserId: uid))
        .toList(growable: false);
  }

  @override
  Future<B2bProduct?> productById(String id) async {
    final row = await _client
        .from('b2b_products')
        .select(_productCols)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : productFromRow(row, currentUserId: _uid);
  }

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
    final shopId = await _myShopId();
    if (shopId == null) throw StateError('Önce mağaza oluşturun.');
    final row = await _client
        .from('b2b_products')
        .insert({
          'shop_id': shopId,
          'name': name,
          'category': category,
          'min_order': minOrder,
          'delivery_regions': _splitRegions(deliveryRegion),
          'price_type': 'quote',
          'description': description,
          'published': published,
          if (imageUrl != null) 'image_url': imageUrl,
        })
        .select(_productCols)
        .single();
    return productFromRow(row, currentUserId: _uid);
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
    final row = await _client
        .from('b2b_products')
        .update({
          'name': name,
          'category': category,
          'min_order': minOrder,
          'delivery_regions': _splitRegions(deliveryRegion),
          'description': description,
          'published': published,
          if (imageUrl != null) 'image_url': imageUrl,
        })
        .eq('id', id)
        .select(_productCols)
        .single();
    return productFromRow(row, currentUserId: _uid);
  }

  @override
  Future<void> setProductPublished(String id, bool published) async {
    await _client
        .from('b2b_products')
        .update({'published': published}).eq('id', id);
  }

  // ---- Kampanyalar ----

  @override
  Future<List<B2bCampaign>> listCampaigns({String? category}) async {
    final base = _client.from('b2b_campaigns').select(_campaignCols).eq(
          'published',
          true,
        );
    final filtered = category != null ? base.eq('category', category) : base;
    final rows = await filtered.order('created_at', ascending: false);
    final uid = _uid;
    return rows
        .map((r) => campaignFromRow(r, currentUserId: uid))
        .toList(growable: false);
  }

  @override
  Future<List<B2bCampaign>> listMyCampaigns() async {
    final shopId = await _myShopId();
    if (shopId == null) return const [];
    final rows = await _client
        .from('b2b_campaigns')
        .select(_campaignCols)
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);
    final uid = _uid;
    return rows
        .map((r) => campaignFromRow(r, currentUserId: uid))
        .toList(growable: false);
  }

  @override
  Future<B2bCampaign?> campaignById(String id) async {
    final row = await _client
        .from('b2b_campaigns')
        .select(_campaignCols)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : campaignFromRow(row, currentUserId: _uid);
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
    final shopId = await _myShopId();
    if (shopId == null) throw StateError('Önce mağaza oluşturun.');
    final row = await _client
        .from('b2b_campaigns')
        .insert({
          'shop_id': shopId,
          'title': title,
          'category': category,
          'regions': _splitRegions(region),
          'min_order': minPurchase,
          'valid_until': _tryDate(validUntil),
          'description': description,
          'published': published,
          if (imageUrl != null) 'image_url': imageUrl,
        })
        .select(_campaignCols)
        .single();
    return campaignFromRow(row, currentUserId: _uid);
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
    final row = await _client
        .from('b2b_campaigns')
        .update({
          'title': title,
          'category': category,
          'regions': _splitRegions(region),
          'min_order': minPurchase,
          'valid_until': _tryDate(validUntil),
          'description': description,
          'published': published,
          if (imageUrl != null) 'image_url': imageUrl,
        })
        .eq('id', id)
        .select(_campaignCols)
        .single();
    return campaignFromRow(row, currentUserId: _uid);
  }

  @override
  Future<void> setCampaignPublished(String id, bool published) async {
    await _client
        .from('b2b_campaigns')
        .update({'published': published}).eq('id', id);
  }

  // ---- Teklif talepleri ----

  @override
  Future<List<B2bQuoteRequest>> listOpenQuoteRequests() async {
    // ANONİM: tablo değil RPC. buyer_id dönmez.
    final rows = await _client.rpc('b2b_open_quote_requests') as List;
    return rows
        .map((r) => quoteRequestFromRow(
              Map<String, dynamic>.from(r as Map),
              createdByMe: false,
            ))
        .toList(growable: false);
  }

  static const _qrCols =
      'id, target_type, target_id, category, quantity, city, district, '
      'buyer_type, delivery_time, note, status, created_at';

  @override
  Future<List<B2bQuoteRequest>> listMyQuoteRequests() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _client
        .from('b2b_quote_requests')
        .select(_qrCols)
        .eq('buyer_id', uid)
        .order('created_at', ascending: false);
    final requests =
        rows.map((r) => quoteRequestFromRow(r, createdByMe: true)).toList();
    // Cevap sayıları: alıcı kendi taleplerine gelen cevapları RLS ile görebilir.
    // Tek sorguda çekip bellekte say (migration/sayaç kolonu gerekmez).
    final ids = requests.map((q) => q.id).toList();
    if (ids.isEmpty) return requests;
    final replyRows = await _client
        .from('b2b_quote_replies')
        .select('quote_request_id')
        .inFilter('quote_request_id', ids);
    final counts = <String, int>{};
    for (final r in replyRows) {
      final k = (r['quote_request_id'] ?? '').toString();
      counts[k] = (counts[k] ?? 0) + 1;
    }
    return requests
        .map((q) => q.copyWith(replyCount: counts[q.id] ?? 0))
        .toList(growable: false);
  }

  @override
  Future<B2bQuoteRequest?> quoteRequestById(String id) async {
    // RLS: yalnız buyer_id=auth.uid() satırı döner → başka alıcının detayı okunamaz.
    final row = await _client
        .from('b2b_quote_requests')
        .select(_qrCols)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final base = quoteRequestFromRow(row, createdByMe: true);
    final replyRows = await _client
        .from('b2b_quote_replies')
        .select('id')
        .eq('quote_request_id', id);
    return base.copyWith(replyCount: replyRows.length);
  }

  @override
  Future<List<B2bQuoteReply>> repliesFor(String requestId) async {
    final rows = await _client
        .from('b2b_quote_replies')
        .select(
          'id, quote_request_id, supplier_shop_id, message, price_note, '
          'delivery_note, created_at, b2b_supplier_shops!inner(shop_name)',
        )
        .eq('quote_request_id', requestId)
        .order('created_at', ascending: false);
    return rows.map(quoteReplyFromRow).toList(growable: false);
  }

  // ---- Teklif yazma ----

  /// b2b_quote_requests insert payload (test edilebilir). buyer_id INSERT
  /// için gereklidir (RLS with_check buyer_id=auth.uid()); READ tarafında ASLA
  /// expose edilmez (RPC + mapper). status daima 'open'.
  static Map<String, dynamic> quoteRequestInsert({
    required String buyerId,
    required String targetType,
    String? targetId,
    required String category,
    required String quantity,
    required String city,
    String district = '',
    String buyerType = '',
    String deliveryTime = '',
    String note = '',
  }) =>
      {
        'buyer_id': buyerId,
        'target_type': targetType,
        'target_id': targetId,
        'category': category,
        'quantity': quantity,
        'city': city,
        'district': district,
        'buyer_type': buyerType,
        'delivery_time': deliveryTime,
        'note': note,
        'status': 'open',
      };

  /// b2b_quote_replies insert payload (test edilebilir). status daima 'sent'.
  static Map<String, dynamic> quoteReplyInsert({
    required String quoteRequestId,
    required String supplierShopId,
    required String message,
    String? priceNote,
    String? deliveryNote,
  }) =>
      {
        'quote_request_id': quoteRequestId,
        'supplier_shop_id': supplierShopId,
        'message': message,
        'price_note': priceNote,
        'delivery_note': deliveryNote,
        'status': 'sent',
      };

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
    final uid = _uid;
    if (uid == null) throw StateError('Oturum bulunamadı.');
    final row = await _client
        .from('b2b_quote_requests')
        .insert(quoteRequestInsert(
          buyerId: uid,
          targetType: targetType,
          targetId: targetId,
          category: category,
          quantity: quantity,
          city: city,
          district: district,
          buyerType: buyerType,
          deliveryTime: deliveryTime,
          note: note,
        ))
        .select(
          'id, target_type, target_id, category, quantity, city, district, '
          'buyer_type, delivery_time, note, status, created_at',
        )
        .single();
    return quoteRequestFromRow(row, createdByMe: true);
  }

  @override
  Future<void> addQuoteReply({
    required String quoteRequestId,
    required String message,
    String? priceNote,
    String? deliveryNote,
  }) async {
    final shopId = await _myShopId();
    if (shopId == null) throw StateError('Önce mağaza oluşturun.');
    await _client.from('b2b_quote_replies').insert(quoteReplyInsert(
          quoteRequestId: quoteRequestId,
          supplierShopId: shopId,
          message: message,
          priceNote: priceNote,
          deliveryNote: deliveryNote,
        ));
  }

  @override
  Future<void> closeQuoteRequest(String id) => _setRequestStatus(id, 'closed');

  @override
  Future<void> cancelQuoteRequest(String id) =>
      _setRequestStatus(id, 'cancelled');

  /// Alıcı kendi talebinin durumunu günceller (RLS: buyer_id=auth.uid()).
  Future<void> _setRequestStatus(String id, String status) async {
    final uid = _uid;
    if (uid == null) throw StateError('Oturum bulunamadı.');
    await _client
        .from('b2b_quote_requests')
        .update({'status': status})
        .eq('id', id)
        .eq('buyer_id', uid);
  }

  // ---- Lead (ilgi) kanalı ----

  static const _leadCols =
      'id, quote_request_id, quote_reply_id, supplier_shop_id, status, '
      'buyer_message, phone_shared, shared_phone, request_category, '
      'request_quantity, request_city, created_at';

  static B2bQuoteLead leadFromRow(Map<String, dynamic> row) {
    final shop = row['b2b_supplier_shops'] as Map<String, dynamic>?;
    return B2bQuoteLead(
      id: (row['id'] ?? '').toString(),
      quoteRequestId: (row['quote_request_id'] ?? '').toString(),
      quoteReplyId: (row['quote_reply_id'] ?? '').toString(),
      supplierShopId: (row['supplier_shop_id'] ?? '').toString(),
      status: B2bLeadStatusX.fromText(row['status'] as String?),
      supplierName: (shop?['shop_name'] ?? '').toString(),
      buyerMessage: row['buyer_message'] as String?,
      phoneShared: (row['phone_shared'] as bool?) ?? false,
      sharedPhone: row['shared_phone'] as String?,
      createdAtLabel: _dateLabel(row['created_at']),
      requestCategory: (row['request_category'] ?? '').toString(),
      requestQuantity: (row['request_quantity'] ?? '').toString(),
      requestCity: (row['request_city'] ?? '').toString(),
    );
  }

  @override
  Future<void> expressInterestInQuoteReply({
    required String quoteReplyId,
    String message = '',
    bool phoneShared = false,
    String? phone,
  }) async {
    await _client.rpc('create_b2b_quote_lead', params: {
      'p_quote_reply_id': quoteReplyId,
      'p_status': 'interested',
      'p_buyer_message': message,
      'p_phone_shared': phoneShared,
      'p_shared_phone': phoneShared ? phone : null,
    });
  }

  @override
  Future<void> rejectQuoteReply(String quoteReplyId) async {
    await _client.rpc('create_b2b_quote_lead', params: {
      'p_quote_reply_id': quoteReplyId,
      'p_status': 'rejected',
      'p_phone_shared': false,
    });
  }

  @override
  Future<List<B2bQuoteLead>> leadsForMyQuoteRequest(
      String quoteRequestId) async {
    // Alıcı kendi talebindeki lead'leri görür (RLS buyer_id=auth.uid()).
    // Mağaza adı için shop embed.
    final rows = await _client
        .from('b2b_quote_leads')
        .select('$_leadCols, b2b_supplier_shops!inner(shop_name)')
        .eq('quote_request_id', quoteRequestId);
    return rows.map(leadFromRow).toList(growable: false);
  }

  @override
  Future<List<B2bQuoteLead>> leadsForMySupplierShop() async {
    final shopId = await _myShopId();
    if (shopId == null) return const [];
    // RLS yalnız kendi mağazasına ait lead'leri döndürür; ayrıca filtrele.
    final rows = await _client
        .from('b2b_quote_leads')
        .select(_leadCols)
        .eq('supplier_shop_id', shopId)
        .order('created_at', ascending: false);
    return rows.map(leadFromRow).toList(growable: false);
  }

  // ---- Yardımcılar ----

  static List<String> _splitRegions(String joined) => joined
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && e != 'Belirtilmedi')
      .toList();

  /// Serbest metin tarihi date'e çevirmeye çalışır; olmazsa null (DB date
  /// kolonu). Form serbest metin verdiği için çoğu zaman null kalır (gap:
  /// ileride date picker).
  static String? _tryDate(String raw) {
    final d = DateTime.tryParse(raw.trim());
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
