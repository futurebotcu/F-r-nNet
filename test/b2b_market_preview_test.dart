// B2B Pazar — native modül testleri.
//
// Kapsam: mock repository davranışı (okuma + write), anonimlik sözleşmesi,
// role resolution + 4+4 segment, Mağazam yönetim aksiyonları ve ürün
// ekleme formu validasyonu.

import 'package:firin_defter/features/b2b_market/models/b2b_product.dart';
import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/screens/b2b_shell_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/forms/supplier_product_form_screen.dart';
import 'package:firin_defter/features/b2b_market/widgets/b2b_product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalB2bRepository — mock veri', () {
    final repo = LocalB2bRepository();

    test('myStore tedarikçinin mağazası (isMine)', () async {
      final s = await repo.myStore();
      expect(s.isMine, isTrue);
      expect(s.id, 's1');
    });

    test('listProducts kategori filtresi yalnız o kategoriyi döner', () async {
      final un = await repo.listProducts(category: 'Un');
      expect(un, isNotEmpty);
      expect(un.every((p) => p.category == 'Un'), isTrue);
    });

    test('listProducts arama tedarikçi/ürün adında çalışır', () async {
      final r = await repo.listProducts(query: 'ege');
      expect(r, isNotEmpty);
      expect(
        r.every((p) =>
            p.supplierName.toLowerCase().contains('ege') ||
            p.name.toLowerCase().contains('ege') ||
            p.category.toLowerCase().contains('ege')),
        isTrue,
      );
    });

    test('listMyProducts yalnız tedarikçinin ürünleri (isMine)', () async {
      final mine = await repo.listMyProducts();
      expect(mine, isNotEmpty);
      expect(mine.every((p) => p.isMine), isTrue);
    });

    test('listMyCampaigns yalnız tedarikçinin kampanyaları', () async {
      final mine = await repo.listMyCampaigns();
      expect(mine, isNotEmpty);
      expect(mine.every((c) => c.isMine), isTrue);
    });

    test('Teklif Ağı: izinli alanlar dolu (anonimlik modelle garantili)',
        () async {
      // B2bQuoteRequest'te işletme adı/telefon/adres/kişi alanı YOKTUR;
      // anonimlik tip düzeyinde garanti edilir. Burada izinli alanların
      // geldiğini doğrularız.
      final open = await repo.listOpenQuoteRequests();
      expect(open, isNotEmpty);
      final q = open.first;
      expect(q.productOrCategory, isNotEmpty);
      expect(q.city, isNotEmpty);
      expect(q.buyerType, isNotEmpty);
    });

    test('Tekliflerim hepsi createdByMe', () async {
      final mine = await repo.listMyQuoteRequests();
      expect(mine, isNotEmpty);
      expect(mine.every((q) => q.createdByMe), isTrue);
    });
  });

  group('B2bShellScreen — role resolution + 4+4 sekme (toggle YOK)', () {
    // Rol UI toggle'ı kaldırıldı; test/development için b2bRoleOverrideProvider
    // ile zorlanır. Üretimde rol profilden çözülür.
    Widget host(B2bRole? role) => ProviderScope(
          overrides: [
            if (role != null)
              b2bRoleOverrideProvider.overrideWith((ref) => role),
          ],
          child: const MaterialApp(home: B2bShellScreen()),
        );

    testWidgets('Tedarikçi rolü → tedarikçi segment seti + Mağazam vitrini',
        (t) async {
      await t.pumpWidget(host(B2bRole.supplier));
      await t.pump();
      expect(find.text('Mağazam'), findsOneWidget);
      expect(find.text('Teklif Ağı'), findsOneWidget);
      expect(
        find.text('Fırıncılar mağazanı böyle görüyor.'),
        findsOneWidget,
      );
    });

    testWidgets('Alıcı rolü → alıcı segment seti; Mağazam YOK', (t) async {
      await t.pumpWidget(host(B2bRole.buyer));
      await t.pump();
      expect(find.text('Tedarikçiler'), findsOneWidget);
      expect(find.text('Tekliflerim'), findsOneWidget);
      // Alıcı tedarikçi yüzeylerini görmez.
      expect(find.text('Mağazam'), findsNothing);
      expect(find.text('Teklif Ağı'), findsNothing);
    });

    testWidgets('Varsayılan (profil/override yok) → alıcı görünümü', (t) async {
      await t.pumpWidget(host(null));
      await t.pump();
      expect(find.text('Ürünler'), findsOneWidget);
      expect(find.text('Tekliflerim'), findsOneWidget);
      expect(find.text('Mağazam'), findsNothing);
    });

    testWidgets('Rol toggle ve önizleme/demo metni UI\'da YOK', (t) async {
      await t.pumpWidget(host(B2bRole.supplier));
      await t.pump();
      expect(find.textContaining('önizleme'), findsNothing);
      expect(find.textContaining('Önizleme'), findsNothing);
      expect(find.textContaining('demo'), findsNothing);
      // "Fırıncı" rol-toggle pili yoktu; tedarikçi görünümünde geçmemeli.
      expect(find.text('Fırıncı'), findsNothing);
    });

    testWidgets('Teklif Ağı segmenti anonimlik notu gösterir', (t) async {
      await t.pumpWidget(host(B2bRole.supplier));
      await t.pump();
      await t.tap(find.text('Teklif Ağı'));
      await t.pumpAndSettle();
      expect(find.textContaining('anonim'), findsWidgets);
    });
  });

  group('Mağazam yönetim aksiyonları — rol ayrımı', () {
    testWidgets('Tedarikçi Mağazam: Düzenle / Ürün ekle / Kampanya oluştur',
        (t) async {
      // Mağazam uzun bir liste; tüm bölümlerin build olması için yüksek yüzey.
      t.view.physicalSize = const Size(1080, 3400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      await t.pumpWidget(ProviderScope(
        overrides: [
          b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.supplier),
        ],
        child: const MaterialApp(home: B2bShellScreen()),
      ));
      await t.pump();
      expect(find.text('Mağazanı düzenle'), findsOneWidget);
      expect(find.text('Ürün ekle'), findsOneWidget);
      expect(find.text('Kampanya oluştur'), findsOneWidget);
    });

    testWidgets('Alıcı bu yönetim aksiyonlarını GÖRMEZ', (t) async {
      await t.pumpWidget(ProviderScope(
        overrides: [
          b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.buyer),
        ],
        child: const MaterialApp(home: B2bShellScreen()),
      ));
      await t.pump();
      expect(find.text('Mağazanı düzenle'), findsNothing);
      expect(find.text('Ürün ekle'), findsNothing);
      expect(find.text('Kampanya oluştur'), findsNothing);
    });
  });

  group('Ürün ekleme formu — validasyon', () {
    testWidgets('Boş ürün adı + kategori reddedilir', (t) async {
      // Form uzun; "Ürünü kaydet" butonu build olsun diye yüksek yüzey.
      t.view.physicalSize = const Size(1080, 3400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      await t.pumpWidget(const ProviderScope(
        child: MaterialApp(home: SupplierProductFormScreen()),
      ));
      await t.pump();
      await t.tap(find.text('Ürünü kaydet'));
      await t.pump();
      expect(find.text('Ürün adı gerekli'), findsOneWidget);
      expect(find.text('Kategori seçin'), findsOneWidget);
    });
  });

  group('Mock write akışı — Mağazam\'a yansıma', () {
    test('addProduct (yayında) → Mağazam + genel Ürünler\'de görünür', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final repo = c.read(b2bRepositoryProvider);
      final before = (await repo.listMyProducts()).length;
      await c.read(b2bMarketControllerProvider.notifier).addProduct(
            name: 'Test Unu',
            category: 'Un',
            minOrder: '10 çuval',
            deliveryRegion: 'Ege',
          );
      expect((await repo.listMyProducts()).length, before + 1);
      expect((await repo.listMyProducts()).any((p) => p.name == 'Test Unu'),
          isTrue);
      // Yayında → genel pazarda da görünür.
      expect((await repo.listProducts()).any((p) => p.name == 'Test Unu'),
          isTrue);
    });

    test('addProduct (taslak) → genel Ürünler\'de görünmez, Mağazam\'da görünür',
        () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(b2bMarketControllerProvider.notifier).addProduct(
            name: 'Taslak Ürün',
            category: 'Maya',
            minOrder: '5 koli',
            deliveryRegion: 'Marmara',
            published: false,
          );
      final repo = c.read(b2bRepositoryProvider);
      expect((await repo.listMyProducts()).any((p) => p.name == 'Taslak Ürün'),
          isTrue);
      expect((await repo.listProducts()).any((p) => p.name == 'Taslak Ürün'),
          isFalse);
    });

    test('addCampaign → Mağazam kampanyalarında görünür', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final repo = c.read(b2bRepositoryProvider);
      final before = (await repo.listMyCampaigns()).length;
      await c.read(b2bMarketControllerProvider.notifier).addCampaign(
            title: 'Test Kampanya',
            category: 'Un',
            region: 'Ege',
            minPurchase: '100 çuval',
            validUntil: '30 Haziran 2026',
          );
      expect((await repo.listMyCampaigns()).length, before + 1);
      expect(
        (await repo.listMyCampaigns()).any((c) => c.title == 'Test Kampanya'),
        isTrue,
      );
    });

    test('updateStore → Mağazam bilgisi güncellenir (monogram türetilir)',
        () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(b2bMarketControllerProvider.notifier).updateStore(
            name: 'Yeni Ticaret',
            description: 'Güncellenmiş açıklama',
            serviceRegions: ['Ege', 'Akdeniz'],
            categories: ['Un'],
          );
      final store = await c.read(b2bRepositoryProvider).myStore();
      expect(store.name, 'Yeni Ticaret');
      expect(store.description, 'Güncellenmiş açıklama');
      expect(store.serviceRegions, ['Ege', 'Akdeniz']);
      expect(store.categories, ['Un']);
      expect(store.monogram, 'YT');
    });

    test('write sonrası controller revizyonu artar (reaktivite)', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final r0 = c.read(b2bMarketControllerProvider);
      await c.read(b2bMarketControllerProvider.notifier).addProduct(
            name: 'X',
            category: 'Un',
            minOrder: '1',
            deliveryRegion: 'Ege',
          );
      expect(c.read(b2bMarketControllerProvider), greaterThan(r0));
    });
  });

  group('Kendi kartında yönetim menüsü — rol/sahiplik ayrımı', () {
    const mine = B2bProduct(
      id: 'x',
      name: 'Benim Ürünüm',
      supplierId: 's1',
      supplierName: 'Benim Mağaza',
      category: 'Un',
      minOrder: '10 çuval',
      deliveryRegion: 'Ege',
      isMine: true,
      published: true,
    );

    Widget host(Widget child) =>
        MaterialApp(home: Scaffold(body: child));

    testWidgets('Supplier kendi (yayında) ürününde Düzenle + Taslağa al',
        (t) async {
      await t.pumpWidget(host(B2bProductCard(
        product: mine,
        onEdit: () {},
        onTogglePublish: () {},
      )));
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      await t.tap(find.byIcon(Icons.more_vert_rounded));
      await t.pumpAndSettle();
      expect(find.text('Düzenle'), findsOneWidget);
      expect(find.text('Taslağa al'), findsOneWidget);
    });

    testWidgets('Kendi taslak ürününde menüde "Yayına al"', (t) async {
      await t.pumpWidget(host(B2bProductCard(
        product: mine.copyWith(published: false),
        onEdit: () {},
        onTogglePublish: () {},
      )));
      await t.tap(find.byIcon(Icons.more_vert_rounded));
      await t.pumpAndSettle();
      expect(find.text('Yayına al'), findsOneWidget);
    });

    testWidgets('Alıcı (ownerContext:false) yönetim menüsü GÖRMEZ', (t) async {
      await t.pumpWidget(host(B2bProductCard(
        product: mine,
        ownerContext: false,
        onEdit: () {},
        onTogglePublish: () {},
      )));
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    });

    testWidgets('Başka tedarikçinin ürününde menü GÖRÜNMEZ', (t) async {
      const other = B2bProduct(
        id: 'y',
        name: 'Başka Ürün',
        supplierId: 's2',
        supplierName: 'Başka Tedarik',
        category: 'Un',
        minOrder: '10',
        deliveryRegion: 'Ege',
        isMine: false,
        published: true,
      );
      await t.pumpWidget(host(B2bProductCard(
        product: other,
        onEdit: () {},
        onTogglePublish: () {},
      )));
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    });
  });

  group('Publish toggle — genel liste vs Mağazam', () {
    test('Ürün: taslağa al → genel düşer, Mağazam kalır; yayına al → geri',
        () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(b2bMarketControllerProvider.notifier);
      await ctrl.addProduct(
        name: 'Toggle Ürün',
        category: 'Un',
        minOrder: '1',
        deliveryRegion: 'Ege',
      );
      final repo = c.read(b2bRepositoryProvider);
      final id = (await repo.listMyProducts())
          .firstWhere((p) => p.name == 'Toggle Ürün')
          .id;

      await ctrl.setProductPublished(id, false);
      expect((await repo.listProducts()).any((p) => p.id == id), isFalse);
      expect((await repo.listMyProducts()).any((p) => p.id == id), isTrue);

      await ctrl.setProductPublished(id, true);
      expect((await repo.listProducts()).any((p) => p.id == id), isTrue);
    });

    test('Kampanya: taslağa al → genel düşer, Mağazam kalır; yayına al → geri',
        () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(b2bMarketControllerProvider.notifier);
      await ctrl.addCampaign(
        title: 'Toggle Kampanya',
        category: 'Un',
        region: 'Ege',
        minPurchase: '100',
        validUntil: 'Süresiz',
      );
      final repo = c.read(b2bRepositoryProvider);
      final id = (await repo.listMyCampaigns())
          .firstWhere((c) => c.title == 'Toggle Kampanya')
          .id;

      await ctrl.setCampaignPublished(id, false);
      expect((await repo.listCampaigns()).any((c) => c.id == id), isFalse);
      expect((await repo.listMyCampaigns()).any((c) => c.id == id), isTrue);

      await ctrl.setCampaignPublished(id, true);
      expect((await repo.listCampaigns()).any((c) => c.id == id), isTrue);
    });

    test('updateProduct: ad/kategori güncellenir, id + sahiplik korunur',
        () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(b2bMarketControllerProvider.notifier);
      await ctrl.addProduct(
        name: 'Eski Ad',
        category: 'Un',
        minOrder: '1',
        deliveryRegion: 'Ege',
      );
      final repo = c.read(b2bRepositoryProvider);
      final p =
          (await repo.listMyProducts()).firstWhere((p) => p.name == 'Eski Ad');
      await ctrl.updateProduct(
        id: p.id,
        name: 'Yeni Ad',
        category: 'Maya',
        minOrder: '5',
        deliveryRegion: 'Marmara',
      );
      final updated = (await repo.productById(p.id))!;
      expect(updated.name, 'Yeni Ad');
      expect(updated.category, 'Maya');
      expect(updated.id, p.id);
      expect(updated.isMine, isTrue);
    });
  });
}
