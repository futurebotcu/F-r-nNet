// B2B Pazar — Teklif İste / Teklif Ver (quote write) testleri.
//
// - Local: addQuoteRequest → Tekliflerim; addQuoteReply → replies.
// - Supabase: insert payload mapping (gerçek DB'ye vurmadan).
// - Sheet wiring: buyer submit → addQuoteRequest; supplier submit → addQuoteReply.
// - Anonimlik: payload'da buyer_id INSERT için var (RLS), okuma tarafında değil.

import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/repositories/supabase_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/widgets/b2b_offer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalB2bRepository — quote write', () {
    test('addQuoteRequest → Tekliflerim listesine (createdByMe) yansır',
        () async {
      final repo = LocalB2bRepository();
      final before = (await repo.listMyQuoteRequests()).length;
      await repo.addQuoteRequest(
        targetType: 'product',
        targetId: 'p1',
        category: 'Ekmeklik Un',
        quantity: '150 çuval',
        city: 'İstanbul',
        note: 'düzenli',
      );
      final after = await repo.listMyQuoteRequests();
      expect(after.length, before + 1);
      expect(after.first.productOrCategory, 'Ekmeklik Un');
      expect(after.first.createdByMe, isTrue);
    });

    test('addQuoteReply → repliesFor listesine yansır', () async {
      final repo = LocalB2bRepository();
      await repo.addQuoteReply(
        quoteRequestId: 'm1',
        message: 'Fiyat verebiliriz',
        priceNote: '≈ ₺640',
      );
      final replies = await repo.repliesFor('m1');
      expect(replies.any((r) => r.message == 'Fiyat verebiliriz'), isTrue);
      expect(replies.first.priceHint, '≈ ₺640');
    });
  });

  group('SupabaseB2bRepository — insert payload', () {
    test('quoteRequestInsert: buyer_id + status=open + güvenli alanlar', () {
      final p = SupabaseB2bRepository.quoteRequestInsert(
        buyerId: 'uid-1',
        targetType: 'product',
        targetId: 'p1',
        category: 'Un',
        quantity: '100 çuval',
        city: 'İzmir',
      );
      expect(p['buyer_id'], 'uid-1'); // INSERT için (RLS); okuma tarafında YOK
      expect(p['status'], 'open');
      expect(p['target_type'], 'product');
      expect(p['category'], 'Un');
      expect(p['city'], 'İzmir');
    });

    test('quoteReplyInsert: status=sent + shop + request bağı', () {
      final p = SupabaseB2bRepository.quoteReplyInsert(
        quoteRequestId: 'q1',
        supplierShopId: 'shop1',
        message: 'm',
        priceNote: '₺640',
      );
      expect(p['status'], 'sent');
      expect(p['quote_request_id'], 'q1');
      expect(p['supplier_shop_id'], 'shop1');
      expect(p['price_note'], '₺640');
    });
  });

  group('Offer sheet wiring → repository', () {
    testWidgets(
        'Genel talep: istek adı + il dropdown → addQuoteRequest (Local)',
        (t) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () =>
                    B2bOfferBottomSheet.show(ctx, kind: B2bOfferKind.newRequest),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();

      // Genel kip: TextField sırası requestName(0), miktar(1), ilçe(2), not(3).
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'Test Kategori'); // ürün/istek adı
      await t.enterText(fields.at(1), '50 çuval'); // miktar

      // İl: 2. dropdown (Kategori=0, İl=1, Teslimat=2).
      final ilDropdown = find.byType(DropdownButtonFormField<String>).at(1);
      await t.ensureVisible(ilDropdown);
      await t.tap(ilDropdown);
      await t.pumpAndSettle();
      await t.tap(find.text('Bursa').last);
      await t.pumpAndSettle();

      final submit = find.text('Talebi yayınla');
      await t.ensureVisible(submit);
      await t.tap(submit);
      await t.pumpAndSettle();

      final repo = container.read(b2bRepositoryProvider);
      final mine = await repo.listMyQuoteRequests();
      final created =
          mine.firstWhere((r) => r.productOrCategory == 'Test Kategori');
      expect(created.city, 'Bursa');
    });

    testWidgets('Ürün kartından teklif: kategori SABİT (dropdown yok)',
        (t) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => B2bOfferBottomSheet.show(
                  ctx,
                  kind: B2bOfferKind.requestQuote,
                  targetType: 'product',
                  targetId: 'p1',
                  presetCategory: 'Ekmeklik Un',
                  contextLine: 'Anadolu Un & Maya · Ekmeklik Un',
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();

      // Sabit kategori kilitli görünür; "Kategori" seçim alanı YOK.
      expect(find.text('Kategori'), findsNothing);
      expect(find.text('Ürün / kategori'), findsOneWidget);

      // Ürün kipi: TextField sırası miktar(0), ilçe(1), not(2). İl dropdown=index1.
      await t.enterText(find.byType(TextField).at(0), '10 çuval');
      final ilDropdown = find.byType(DropdownButtonFormField<String>).at(0);
      await t.ensureVisible(ilDropdown);
      await t.tap(ilDropdown);
      await t.pumpAndSettle();
      await t.tap(find.text('İstanbul').last);
      await t.pumpAndSettle();

      final submit = find.text('Teklif iste');
      await t.ensureVisible(submit);
      await t.tap(submit);
      await t.pumpAndSettle();

      final repo = container.read(b2bRepositoryProvider);
      final mine = await repo.listMyQuoteRequests();
      // Kategori kullanıcıdan değil, presetCategory'den sabit geldi.
      expect(mine.any((r) => r.productOrCategory == 'Ekmeklik Un'), isTrue);
    });

    testWidgets('Supplier "Teklif Ver" submit → addQuoteReply (Local)',
        (t) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => B2bOfferBottomSheet.show(
                  ctx,
                  kind: B2bOfferKind.giveOffer,
                  quoteRequestId: 'm1',
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField).first, 'Numune gönderebiliriz');
      await t.tap(find.text('Teklifi gönder'));
      await t.pumpAndSettle();

      final repo = container.read(b2bRepositoryProvider);
      final replies = await repo.repliesFor('m1');
      expect(replies.any((r) => r.message == 'Numune gönderebiliriz'), isTrue);
    });
  });
}
