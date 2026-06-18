// B2B V1 UX kapanış — detay ekranları + repo read + navigasyon testleri.
//
// Kapsam:
//  * Local storeById / productsForStore / campaignsForStore
//  * quoteReplyFromRow supplier_shop_id map
//  * Ürün detay ekranı: ad + "Teklif iste" + "Tedarikçi mağazasını gör"
//  * Kampanya detay ekranı: başlık + aksiyonlar
//  * Mağaza detay ekranı: ad + (non-mine) "Teklif iste"

import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/repositories/supabase_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/screens/detail/b2b_campaign_detail_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/detail/b2b_product_detail_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/detail/b2b_store_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(LocalB2bRepository repo, Widget child) {
  return ProviderScope(
    overrides: [b2bRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('Local — mağaza detay read', () {
    test('storeById / productsForStore / campaignsForStore', () async {
      final repo = LocalB2bRepository();
      final stores = await repo.listStores();
      expect(stores, isNotEmpty);
      final id = stores.first.id;

      final s = await repo.storeById(id);
      expect(s, isNotNull);
      expect(s!.id, id);
      expect(await repo.storeById('yok'), isNull);

      // Mağazanın yayındaki ürün/kampanyaları (taslak hariç).
      final prods = await repo.productsForStore(id);
      expect(prods.every((p) => p.published), isTrue);
      final camps = await repo.campaignsForStore(id);
      expect(camps.every((c) => c.published), isTrue);
    });
  });

  group('quoteReplyFromRow — supplier_shop_id', () {
    test('supplierShopId map edilir', () {
      final r = SupabaseB2bRepository.quoteReplyFromRow({
        'id': 'r1',
        'quote_request_id': 'q1',
        'supplier_shop_id': 'shop-9',
        'message': 'm',
        'created_at': '2026-06-18T06:00:00+00:00',
        'b2b_supplier_shops': {'shop_name': 'Shop'},
      });
      expect(r.supplierShopId, 'shop-9');
    });
  });

  group('Ürün detay ekranı', () {
    testWidgets('ad + Teklif iste + Tedarikçi mağazasını gör', (t) async {
      final repo = LocalB2bRepository();
      final products = await repo.listProducts();
      final p = products.first;

      await t.pumpWidget(_wrap(repo, B2bProductDetailScreen(productId: p.id)));
      await t.pumpAndSettle();

      expect(find.text('Ürün detayı'), findsOneWidget);
      expect(find.text(p.name), findsWidgets);
      expect(find.text('Teklif iste'), findsOneWidget);
      expect(find.text('Tedarikçi mağazasını gör'), findsOneWidget);
    });
  });

  group('Kampanya detay ekranı', () {
    testWidgets('başlık + Teklif iste', (t) async {
      final repo = LocalB2bRepository();
      final camps = await repo.listCampaigns();
      final c = camps.first;

      await t.pumpWidget(
        _wrap(repo, B2bCampaignDetailScreen(campaignId: c.id)),
      );
      await t.pumpAndSettle();

      expect(find.text('Kampanya detayı'), findsOneWidget);
      expect(find.text(c.title), findsWidgets);
      expect(find.text('Teklif iste'), findsOneWidget);
    });
  });

  group('Mağaza detay ekranı', () {
    testWidgets('ad görünür; "Yakında" yok', (t) async {
      final repo = LocalB2bRepository();
      // Sahibi olmayan bir mağaza seç (isMine=false → "Teklif iste").
      final stores = await repo.listStores();
      final notMine = stores.firstWhere(
        (s) => !s.isMine,
        orElse: () => stores.first,
      );

      await t.pumpWidget(
        _wrap(repo, B2bStoreDetailScreen(storeId: notMine.id)),
      );
      await t.pumpAndSettle();

      expect(find.text('Tedarikçi mağazası'), findsOneWidget);
      expect(find.text(notMine.name), findsWidgets);
      expect(find.textContaining('yakında'), findsNothing);
      if (!notMine.isMine) {
        expect(find.text('Teklif iste'), findsOneWidget);
      }
    });
  });
}
