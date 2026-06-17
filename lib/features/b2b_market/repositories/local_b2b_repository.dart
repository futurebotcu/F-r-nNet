// B2B Pazar — yerel mock repository (preview sprint).
//
// Tüm veriyi [B2bMockSeed]'den okur; filtreleme bellek-içi yapılır.
// Yazma yok (ilan ekleme/teklif kaydı persist edilmez) — aksiyonlar UI'da
// banner ile geri bildirilir.

import '../data/b2b_mock_seed.dart';
import '../models/b2b_campaign.dart';
import '../models/b2b_product.dart';
import '../models/b2b_quote_reply.dart';
import '../models/b2b_quote_request.dart';
import '../models/b2b_store.dart';
import 'b2b_repository.dart';

class LocalB2bRepository implements B2bRepository {
  const LocalB2bRepository();

  @override
  B2bStore myStore() {
    return B2bMockSeed.stores.firstWhere(
      (s) => s.id == B2bMockSeed.mySupplierId,
      orElse: () => B2bMockSeed.stores.first,
    );
  }

  @override
  List<B2bStore> listStores() => List<B2bStore>.unmodifiable(B2bMockSeed.stores);

  @override
  List<String> productCategories() =>
      List<String>.unmodifiable(B2bMockSeed.productCategories);

  @override
  List<B2bProduct> listProducts({String? category, String? query}) {
    final q = (query ?? '').trim().toLowerCase();
    return B2bMockSeed.products.where((p) {
      final categoryOk = category == null || p.category == category;
      final queryOk = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.supplierName.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
      return categoryOk && queryOk;
    }).toList(growable: false);
  }

  @override
  List<B2bProduct> listMyProducts() => B2bMockSeed.products
      .where((p) => p.supplierId == B2bMockSeed.mySupplierId)
      .toList(growable: false);

  @override
  List<B2bCampaign> listCampaigns({String? category}) {
    return B2bMockSeed.campaigns
        .where((c) => category == null || c.category == category)
        .toList(growable: false);
  }

  @override
  List<B2bCampaign> listMyCampaigns() => B2bMockSeed.campaigns
      .where((c) => c.supplierId == B2bMockSeed.mySupplierId)
      .toList(growable: false);

  @override
  List<B2bQuoteRequest> listOpenQuoteRequests() =>
      List<B2bQuoteRequest>.unmodifiable(B2bMockSeed.openQuoteRequests);

  @override
  List<B2bQuoteRequest> listMyQuoteRequests() =>
      List<B2bQuoteRequest>.unmodifiable(B2bMockSeed.myQuoteRequests);

  @override
  List<B2bQuoteReply> repliesFor(String requestId) => B2bMockSeed.replies
      .where((r) => r.requestId == requestId)
      .toList(growable: false);
}
