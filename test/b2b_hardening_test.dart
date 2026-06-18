// B2B final hardening patch testleri.
//
// Kapsam:
//  * B2B-3: Local kapalı/iptal talebe reply engeli (DB guard'ın yerel karşılığı)
//  * B2B-4: B2bStore.copyWith ürün/kampanya sayısını taşır (kart count fix)
//  * B2B-8: B2bMediaImage görsel yoksa placeholder ikonu gösterir

import 'package:firin_defter/features/b2b_market/models/b2b_store.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/widgets/b2b_media_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('B2B-3 — kapalı/iptal talebe reply engeli (Local)', () {
    test('açık talebe reply izinli; kapalı/iptal reddedilir', () async {
      final repo = LocalB2bRepository();
      final r = await repo.addQuoteRequest(
        targetType: 'general',
        category: 'Un',
        quantity: '10',
        city: 'İstanbul',
      );

      // open → izinli
      await repo.addQuoteReply(quoteRequestId: r.id, message: 'teklif');
      expect((await repo.repliesFor(r.id)), isNotEmpty);

      // closed → reddedilir
      await repo.closeQuoteRequest(r.id);
      expect(
        () => repo.addQuoteReply(quoteRequestId: r.id, message: 'geç'),
        throwsStateError,
      );

      // cancelled → reddedilir
      final r2 = await repo.addQuoteRequest(
        targetType: 'general',
        category: 'Maya',
        quantity: '5',
        city: 'Ankara',
      );
      await repo.cancelQuoteRequest(r2.id);
      expect(
        () => repo.addQuoteReply(quoteRequestId: r2.id, message: 'geç'),
        throwsStateError,
      );
    });
  });

  group('B2B-4 — store count', () {
    test('copyWith ürün/kampanya sayısını taşır', () {
      const s = B2bStore(
        id: 's1',
        name: 'Test',
        monogram: 'TE',
        tagline: '',
        description: '',
        categories: ['Un'],
        serviceRegions: ['Marmara'],
        productCount: 0,
        campaignCount: 0,
      );
      final updated = s.copyWith(productCount: 3, campaignCount: 2);
      expect(updated.productCount, 3);
      expect(updated.campaignCount, 2);
      expect(updated.id, 's1');
      expect(updated.name, 'Test');
    });
  });

  group('B2B-8 — B2bMediaImage placeholder', () {
    testWidgets('url yoksa placeholder ikonu görünür', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: B2bMediaImage(
              url: null,
              height: 100,
              placeholderIcon: Icons.storefront_rounded,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    });

    testWidgets('url boş string ise de placeholder', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: B2bMediaImage(
              url: '',
              height: 100,
              placeholderIcon: Icons.inventory_2_outlined,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    });
  });
}
