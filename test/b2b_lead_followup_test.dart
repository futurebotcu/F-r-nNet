// B2B Lead Sonrası Temas + Anlaşma — testler.
//
// Kapsam:
//  * Local: teklif kabul (accepted_reply_id + reply.accepted, tek seçim, switch)
//  * Local: kapalı talepte kabul engelli
//  * Local: lead takip mesajı gönder/oku; boş mesaj engelli
//  * Supabase mapper: reply.accepted, request.accepted_reply_id, lead.replyAccepted,
//    leadMessageFromRow sender_role/mesaj

import 'package:firin_defter/features/b2b_market/models/b2b_lead_message.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/repositories/supabase_b2b_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Local'de bir talep + iki cevap üret; (request, reply1, reply2) döndür.
  Future<({LocalB2bRepository repo, String reqId, String r1, String r2})>
      seedTwoReplies() async {
    final repo = LocalB2bRepository();
    final req = await repo.addQuoteRequest(
      targetType: 'general',
      category: 'Un',
      quantity: '10',
      city: 'İstanbul',
    );
    await repo.addQuoteReply(quoteRequestId: req.id, message: 'teklif 1');
    await repo.addQuoteReply(quoteRequestId: req.id, message: 'teklif 2');
    final replies = await repo.repliesFor(req.id);
    return (repo: repo, reqId: req.id, r1: replies[0].id, r2: replies[1].id);
  }

  group('Local — teklif kabul / anlaşma', () {
    test('kabul → accepted_reply_id + tek reply accepted', () async {
      final s = await seedTwoReplies();
      await s.repo.acceptQuoteReply(s.r1);

      final detail = await s.repo.quoteRequestById(s.reqId);
      expect(detail!.acceptedReplyId, s.r1);
      expect(detail.hasAcceptedReply, isTrue);

      final replies = await s.repo.repliesFor(s.reqId);
      expect(replies.firstWhere((r) => r.id == s.r1).accepted, isTrue);
      expect(replies.firstWhere((r) => r.id == s.r2).accepted, isFalse);
    });

    test('ikinci kabul seçimi günceller (tek seçim)', () async {
      final s = await seedTwoReplies();
      await s.repo.acceptQuoteReply(s.r1);
      await s.repo.acceptQuoteReply(s.r2);

      final detail = await s.repo.quoteRequestById(s.reqId);
      expect(detail!.acceptedReplyId, s.r2);
      final replies = await s.repo.repliesFor(s.reqId);
      expect(replies.firstWhere((r) => r.id == s.r1).accepted, isFalse);
      expect(replies.firstWhere((r) => r.id == s.r2).accepted, isTrue);
    });

    test('kapalı talepte kabul engelli', () async {
      final s = await seedTwoReplies();
      await s.repo.closeQuoteRequest(s.reqId);
      expect(() => s.repo.acceptQuoteReply(s.r1), throwsStateError);
    });
  });

  group('Local — lead takip mesajı', () {
    Future<({LocalB2bRepository repo, String leadId})> seedLead() async {
      final repo = LocalB2bRepository();
      final req = await repo.addQuoteRequest(
        targetType: 'general',
        category: 'Un',
        quantity: '5',
        city: 'İzmir',
      );
      await repo.addQuoteReply(quoteRequestId: req.id, message: 'teklif');
      final reply = (await repo.repliesFor(req.id)).first;
      await repo.expressInterestInQuoteReply(quoteReplyId: reply.id);
      final lead = (await repo.leadsForMyQuoteRequest(req.id)).first;
      return (repo: repo, leadId: lead.id);
    }

    test('mesaj gönder → messagesForLead döner', () async {
      final s = await seedLead();
      await s.repo.sendLeadMessage(leadId: s.leadId, message: 'görüşelim');
      final msgs = await s.repo.messagesForLead(s.leadId);
      expect(msgs.length, 1);
      expect(msgs.first.message, 'görüşelim');
    });

    test('boş mesaj engelli', () async {
      final s = await seedLead();
      expect(
        () => s.repo.sendLeadMessage(leadId: s.leadId, message: '   '),
        throwsStateError,
      );
    });
  });

  group('Supabase mapper', () {
    test('quoteReplyFromRow accepted okur', () {
      final r = SupabaseB2bRepository.quoteReplyFromRow({
        'id': 'r1',
        'quote_request_id': 'q1',
        'message': 'm',
        'accepted': true,
        'created_at': '2026-06-18T12:00:00+00:00',
        'b2b_supplier_shops': {'shop_name': 'Shop'},
      });
      expect(r.accepted, isTrue);
    });

    test('quoteRequestFromRow accepted_reply_id okur', () {
      final q = SupabaseB2bRepository.quoteRequestFromRow({
        'id': 'q1',
        'category': 'Un',
        'status': 'answered',
        'accepted_reply_id': 'r9',
      });
      expect(q.acceptedReplyId, 'r9');
      expect(q.hasAcceptedReply, isTrue);
    });

    test('leadFromRow replyAccepted (embed) okur', () {
      final l = SupabaseB2bRepository.leadFromRow({
        'id': 'l1',
        'quote_request_id': 'q1',
        'quote_reply_id': 'r1',
        'supplier_shop_id': 's1',
        'status': 'interested',
        'phone_shared': false,
        'created_at': '2026-06-18T12:00:00+00:00',
        'b2b_quote_replies': {'accepted': true},
      });
      expect(l.replyAccepted, isTrue);
    });

    test('leadMessageFromRow sender_role + mesaj', () {
      final m = SupabaseB2bRepository.leadMessageFromRow({
        'id': 'm1',
        'lead_id': 'l1',
        'sender_role': 'supplier',
        'message': 'merhaba',
        'created_at': '2026-06-18T12:00:00+00:00',
      });
      expect(m.senderRole, B2bLeadSenderRole.supplier);
      expect(m.message, 'merhaba');
    });
  });
}
