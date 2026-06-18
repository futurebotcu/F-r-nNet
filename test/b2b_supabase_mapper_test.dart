// B2B Pazar — SupabaseB2bRepository row→model mapper testleri.
//
// Gerçek Supabase client'a VURULMAZ; yalnız static mapper'lar Map satırlarıyla
// test edilir. Anonimlik: quote_request mapper'ı buyer_id taşımaz (model'de
// alan yok); satırda buyer_id olsa bile modele sızmaz.

import 'package:firin_defter/features/b2b_market/models/b2b_quote_request.dart';
import 'package:firin_defter/features/b2b_market/repositories/supabase_b2b_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseB2bRepository — mapper', () {
    test('monogramFor ad baş harflerinden türetir', () {
      expect(SupabaseB2bRepository.monogramFor('Anadolu Un'), 'AU');
      expect(SupabaseB2bRepository.monogramFor('Toros'), 'TO');
      expect(SupabaseB2bRepository.monogramFor(''), '?');
    });

    test('statusFromText: open→waiting, replied/closed eşlenir', () {
      expect(SupabaseB2bRepository.statusFromText('open'),
          B2bQuoteStatus.waiting);
      expect(SupabaseB2bRepository.statusFromText('replied'),
          B2bQuoteStatus.replied);
      expect(SupabaseB2bRepository.statusFromText('closed'),
          B2bQuoteStatus.closed);
      expect(SupabaseB2bRepository.statusFromText(null),
          B2bQuoteStatus.waiting);
    });

    test('storeFromRow: monogram + isMine + dizi alanları', () {
      final s = SupabaseB2bRepository.storeFromRow({
        'id': 'shop1',
        'owner_id': 'u1',
        'shop_name': 'Anadolu Un',
        'description': 'açıklama',
        'service_regions': ['Ege', 'Marmara'],
        'categories': ['Un', 'Maya'],
      }, currentUserId: 'u1');
      expect(s.id, 'shop1');
      expect(s.name, 'Anadolu Un');
      expect(s.monogram, 'AU');
      expect(s.serviceRegions, ['Ege', 'Marmara']);
      expect(s.categories, ['Un', 'Maya']);
      expect(s.isMine, isTrue);
    });

    test('storeFromRow: başka owner → isMine false', () {
      final s = SupabaseB2bRepository.storeFromRow({
        'id': 'shop2',
        'owner_id': 'u2',
        'shop_name': 'Ege Ambalaj',
      }, currentUserId: 'u1');
      expect(s.isMine, isFalse);
    });

    test('productFromRow: embed mağazadan supplierName + isMine, dizi→string',
        () {
      final p = SupabaseB2bRepository.productFromRow({
        'id': 'p1',
        'shop_id': 'shop1',
        'name': 'Tam Buğday Unu',
        'category': 'Un',
        'min_order': '50 çuval',
        'delivery_regions': ['Ege', 'İç Anadolu'],
        'description': 'd',
        'published': true,
        'b2b_supplier_shops': {'shop_name': 'Anadolu Un', 'owner_id': 'u1'},
      }, currentUserId: 'u1');
      expect(p.supplierId, 'shop1');
      expect(p.supplierName, 'Anadolu Un');
      expect(p.deliveryRegion, 'Ege, İç Anadolu');
      expect(p.isMine, isTrue);
      expect(p.published, isTrue);
    });

    test('campaignFromRow: regions→string, valid_until null→Süresiz', () {
      final c = SupabaseB2bRepository.campaignFromRow({
        'id': 'c1',
        'shop_id': 'shop1',
        'title': 'Sezon Fırsatı',
        'category': 'Un',
        'regions': ['Marmara'],
        'min_order': '200 çuval',
        'valid_until': null,
        'description': '',
        'published': false,
        'b2b_supplier_shops': {'shop_name': 'Anadolu Un', 'owner_id': 'u9'},
      }, currentUserId: 'u1');
      expect(c.region, 'Marmara');
      expect(c.validUntil, 'Süresiz');
      expect(c.published, isFalse);
      expect(c.isMine, isFalse);
    });

    test('quoteRequestFromRow ANONİM: buyer_id satırda olsa bile modele sızmaz',
        () {
      // RPC normalde buyer_id döndürmez; burada kazara gelse bile mapper
      // okumaz (model'de alan yok). İzinli alanlar doğru eşlenir.
      final q = SupabaseB2bRepository.quoteRequestFromRow({
        'id': 'q1',
        'buyer_id': 'GIZLI-UID', // mapper bunu OKUMAZ
        'category': 'Ekmeklik Un',
        'quantity': '300 çuval',
        'city': 'İstanbul',
        'district': 'Bağcılar',
        'buyer_type': 'Fırın',
        'delivery_time': 'Haftalık',
        'note': 'not',
        'status': 'open',
      });
      expect(q.productOrCategory, 'Ekmeklik Un');
      expect(q.city, 'İstanbul');
      expect(q.buyerType, 'Fırın');
      expect(q.status, B2bQuoteStatus.waiting);
      expect(q.createdByMe, isFalse);
      // Modelde buyer_id / telefon / adres / kişi adı alanı YOKTUR —
      // toString içinde gizli uid geçmemeli.
      expect(q.toString().contains('GIZLI-UID'), isFalse);
    });

    test('quoteReplyFromRow: embed mağaza adı + price_note→priceHint', () {
      final r = SupabaseB2bRepository.quoteReplyFromRow({
        'id': 'r1',
        'quote_request_id': 'q1',
        'message': 'Fiyat verebiliriz',
        'price_note': '≈ ₺640 / çuval',
        'created_at': '2026-06-17T10:00:00Z',
        'b2b_supplier_shops': {'shop_name': 'Anadolu Un'},
      });
      expect(r.requestId, 'q1');
      expect(r.supplierName, 'Anadolu Un');
      expect(r.priceHint, '≈ ₺640 / çuval');
      expect(r.createdAtLabel, '2026-06-17');
    });
  });
}
