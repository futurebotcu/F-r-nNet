// B2B Pazar — teklif detayı + cevap akışı testleri (Sprint 1).
//
// Kapsam:
//  * LocalB2bRepository.quoteRequestById + replyCount türetimi
//  * addQuoteReply → repliesFor roundtrip (deliveryNote dahil)
//  * SupabaseB2bRepository.quoteReplyFromRow delivery_note map
//  * B2bQuoteRequestCard onTap ("Detayı gör") tetiklenir
//  * BuyerQuoteDetailScreen: özet + gelen teklif + boş durum

import 'package:firin_defter/features/b2b_market/models/b2b_quote_request.dart';
import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/repositories/supabase_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/screens/buyer/buyer_quote_detail_screen.dart';
import 'package:firin_defter/features/b2b_market/widgets/b2b_quote_request_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalB2bRepository — quote detail', () {
    test('quoteRequestById kendi talebini döner, bilinmeyen id → null', () async {
      final repo = LocalB2bRepository();
      final mine = await repo.listMyQuoteRequests();
      expect(mine, isNotEmpty);

      final found = await repo.quoteRequestById(mine.first.id);
      expect(found, isNotNull);
      expect(found!.id, mine.first.id);

      final missing = await repo.quoteRequestById('yok-böyle-id');
      expect(missing, isNull);
    });

    test('addQuoteReply → repliesFor cevabı (deliveryNote dahil) döner', () async {
      final repo = LocalB2bRepository();
      final mine = await repo.listMyQuoteRequests();
      final id = mine.first.id;

      await repo.addQuoteReply(
        quoteRequestId: id,
        message: 'SMOKE-B2B teklif cevabı',
        priceNote: '≈ ₺640 / çuval',
        deliveryNote: 'Bu hafta teslim',
      );

      final replies = await repo.repliesFor(id);
      expect(replies, isNotEmpty);
      final r = replies.first;
      expect(r.message, 'SMOKE-B2B teklif cevabı');
      expect(r.priceHint, '≈ ₺640 / çuval');
      expect(r.deliveryNote, 'Bu hafta teslim');
    });

    test('listMyQuoteRequests replyCount cevap sayısına göre güncellenir',
        () async {
      final repo = LocalB2bRepository();
      final created = await repo.addQuoteRequest(
        targetType: 'general',
        category: 'Un',
        quantity: '10 çuval',
        city: 'İstanbul',
      );
      // Yeni talepte 0 cevap.
      var detail = await repo.quoteRequestById(created.id);
      expect(detail!.replyCount, 0);

      await repo.addQuoteReply(
        quoteRequestId: created.id,
        message: 'cevap',
      );
      detail = await repo.quoteRequestById(created.id);
      expect(detail!.replyCount, 1);

      final list = await repo.listMyQuoteRequests();
      final row = list.firstWhere((q) => q.id == created.id);
      expect(row.replyCount, 1);
    });
  });

  group('SupabaseB2bRepository.quoteReplyFromRow — deliveryNote map', () {
    test('delivery_note dolu → deliveryNote dolu', () {
      final reply = SupabaseB2bRepository.quoteReplyFromRow({
        'id': 'r1',
        'quote_request_id': 'q1',
        'message': 'merhaba',
        'price_note': '₺640',
        'delivery_note': 'Bu hafta',
        'created_at': '2026-06-18T06:00:00+00:00',
        'b2b_supplier_shops': {'shop_name': 'Anadolu Un'},
      });
      expect(reply.deliveryNote, 'Bu hafta');
      expect(reply.priceHint, '₺640');
      expect(reply.supplierName, 'Anadolu Un');
    });

    test('delivery_note yok → deliveryNote null', () {
      final reply = SupabaseB2bRepository.quoteReplyFromRow({
        'id': 'r2',
        'quote_request_id': 'q1',
        'message': 'merhaba',
        'created_at': '2026-06-18T06:00:00+00:00',
        'b2b_supplier_shops': {'shop_name': 'Anadolu Un'},
      });
      expect(reply.deliveryNote, isNull);
    });
  });

  group('B2bQuoteRequestCard — onTap', () {
    testWidgets('onTap dolu → "Detayı gör" görünür ve tıklama tetiklenir',
        (tester) async {
      var tapped = false;
      const req = B2bQuoteRequest(
        id: 'q_test',
        productOrCategory: 'Ekmeklik Un',
        quantity: '10 çuval',
        city: 'İstanbul',
        district: '',
        buyerType: 'Fırın',
        deliveryTime: 'Bu hafta',
        note: '',
        status: B2bQuoteStatus.waiting,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: B2bQuoteRequestCard(
              request: req,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('Detayı gör'), findsOneWidget);
      // "Teklif Ver" yalnız tedarikçi (onReply) için.
      expect(find.text('Teklif Ver'), findsNothing);
      await tester.tap(find.text('Ekmeklik Un'));
      expect(tapped, isTrue);
    });
  });

  group('BuyerQuoteDetailScreen', () {
    testWidgets('özet + gelen teklif gösterir', (tester) async {
      final repo = LocalB2bRepository();
      final mine = await repo.listMyQuoteRequests();
      final id = mine.first.id;
      await repo.addQuoteReply(
        quoteRequestId: id,
        message: 'SMOKE-B2B teklif cevabı',
        priceNote: '₺640',
        deliveryNote: 'Bu hafta teslim',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [b2bRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: BuyerQuoteDetailScreen(quoteRequestId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Teklif detayı'), findsOneWidget);
      expect(find.text('SMOKE-B2B teklif cevabı'), findsOneWidget);
      expect(find.textContaining('Bu hafta teslim'), findsOneWidget);
    });

    testWidgets('cevap yoksa boş durum gösterir', (tester) async {
      final repo = LocalB2bRepository();
      final created = await repo.addQuoteRequest(
        targetType: 'general',
        category: 'SMOKE-B2B Un Talebi',
        quantity: '10 çuval',
        city: 'İstanbul',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [b2bRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: BuyerQuoteDetailScreen(quoteRequestId: created.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Henüz teklif gelmedi'), findsOneWidget);
      expect(find.text('SMOKE-B2B Un Talebi'), findsOneWidget);
    });
  });
}
