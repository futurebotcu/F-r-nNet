// B2B lead (ilgi) kanalı testleri.
//
// Kapsam:
//  * Local: İlgileniyorum → lead (interested); telefonsuz → sharedPhone null;
//    telefonlu → sharedPhone dolu; aynı reply'a ikinci lead engelli;
//    Uygun değil → rejected; kapalı/iptal talebe lead engelli;
//    leadsForMySupplierShop kendi mağaza lead'ini döner.
//  * Supabase leadFromRow mapper (supplierName embed + telefon + talep özeti).

import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/repositories/supabase_b2b_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Local'de bir talep + ona ait bir cevap üretip cevabın id'sini döndürür.
  Future<({LocalB2bRepository repo, String requestId, String replyId})>
      seedReply() async {
    final repo = LocalB2bRepository();
    final req = await repo.addQuoteRequest(
      targetType: 'general',
      category: 'Un',
      quantity: '10 çuval',
      city: 'İstanbul',
    );
    await repo.addQuoteReply(quoteRequestId: req.id, message: 'teklifim');
    final replies = await repo.repliesFor(req.id);
    return (repo: repo, requestId: req.id, replyId: replies.first.id);
  }

  group('Local — lead (ilgi)', () {
    test('İlgileniyorum (telefonsuz) → interested, sharedPhone null', () async {
      final s = await seedReply();
      await s.repo.expressInterestInQuoteReply(
        quoteReplyId: s.replyId,
        message: 'Görüşelim',
      );
      final leads = await s.repo.leadsForMyQuoteRequest(s.requestId);
      expect(leads.length, 1);
      expect(leads.first.isInterested, isTrue);
      expect(leads.first.phoneShared, isFalse);
      expect(leads.first.sharedPhone, isNull);
      expect(leads.first.buyerMessage, 'Görüşelim');
    });

    test('İlgileniyorum (telefon paylaş) → sharedPhone dolu', () async {
      final s = await seedReply();
      await s.repo.expressInterestInQuoteReply(
        quoteReplyId: s.replyId,
        message: 'ara beni',
        phoneShared: true,
        phone: '0555 111 22 33',
      );
      final leads = await s.repo.leadsForMyQuoteRequest(s.requestId);
      expect(leads.first.phoneShared, isTrue);
      expect(leads.first.sharedPhone, '0555 111 22 33');
    });

    test('Aynı reply için ikinci lead engelli', () async {
      final s = await seedReply();
      await s.repo.expressInterestInQuoteReply(quoteReplyId: s.replyId);
      expect(
        () => s.repo.expressInterestInQuoteReply(quoteReplyId: s.replyId),
        throwsStateError,
      );
    });

    test('Uygun değil → rejected', () async {
      final s = await seedReply();
      await s.repo.rejectQuoteReply(s.replyId);
      final leads = await s.repo.leadsForMyQuoteRequest(s.requestId);
      expect(leads.first.isRejected, isTrue);
    });

    test('Kapalı talebe lead engelli', () async {
      final s = await seedReply();
      await s.repo.closeQuoteRequest(s.requestId);
      expect(
        () => s.repo.expressInterestInQuoteReply(quoteReplyId: s.replyId),
        throwsStateError,
      );
    });

    test('leadsForMySupplierShop kendi mağaza lead\'ini döner', () async {
      final s = await seedReply();
      await s.repo.expressInterestInQuoteReply(quoteReplyId: s.replyId);
      final supplierLeads = await s.repo.leadsForMySupplierShop();
      expect(supplierLeads.length, 1);
      expect(supplierLeads.first.isInterested, isTrue);
    });
  });

  group('Supabase leadFromRow', () {
    test('telefon paylaşılan + talep özeti + mağaza adı', () {
      final lead = SupabaseB2bRepository.leadFromRow({
        'id': 'l1',
        'quote_request_id': 'q1',
        'quote_reply_id': 'r1',
        'supplier_shop_id': 's1',
        'status': 'interested',
        'buyer_message': 'ilgileniyorum',
        'phone_shared': true,
        'shared_phone': '05551112233',
        'request_category': 'Un',
        'request_quantity': '100 çuval',
        'request_city': 'İzmir',
        'created_at': '2026-06-18T12:00:00+00:00',
        'b2b_supplier_shops': {'shop_name': 'Anadolu Un'},
      });
      expect(lead.isInterested, isTrue);
      expect(lead.phoneShared, isTrue);
      expect(lead.sharedPhone, '05551112233');
      expect(lead.requestCategory, 'Un');
      expect(lead.requestCity, 'İzmir');
      expect(lead.supplierName, 'Anadolu Un');
    });

    test('telefon paylaşılmamış → sharedPhone null', () {
      final lead = SupabaseB2bRepository.leadFromRow({
        'id': 'l2',
        'quote_request_id': 'q1',
        'quote_reply_id': 'r2',
        'supplier_shop_id': 's1',
        'status': 'rejected',
        'phone_shared': false,
        'created_at': '2026-06-18T12:00:00+00:00',
      });
      expect(lead.isRejected, isTrue);
      expect(lead.phoneShared, isFalse);
      expect(lead.sharedPhone, isNull);
    });
  });
}
