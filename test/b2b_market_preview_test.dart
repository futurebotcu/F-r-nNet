// B2B Pazar — native modül preview sprint testleri.
//
// Kapsam: mock repository davranışı, anonimlik sözleşmesi, B2bShellScreen
// preview toggle (Tedarikçi/Fırıncı) ve 4+4 segment.

import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/screens/b2b_shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalB2bRepository — mock veri', () {
    const repo = LocalB2bRepository();

    test('myStore preview tedarikçinin mağazası (isMine)', () {
      final s = repo.myStore();
      expect(s.isMine, isTrue);
      expect(s.id, 's1');
    });

    test('listProducts kategori filtresi yalnız o kategoriyi döner', () {
      final un = repo.listProducts(category: 'Un');
      expect(un, isNotEmpty);
      expect(un.every((p) => p.category == 'Un'), isTrue);
    });

    test('listProducts arama tedarikçi/ürün adında çalışır', () {
      final r = repo.listProducts(query: 'ege');
      expect(r, isNotEmpty);
      expect(
        r.every((p) =>
            p.supplierName.toLowerCase().contains('ege') ||
            p.name.toLowerCase().contains('ege') ||
            p.category.toLowerCase().contains('ege')),
        isTrue,
      );
    });

    test('listMyProducts yalnız preview tedarikçinin ürünleri (isMine)', () {
      final mine = repo.listMyProducts();
      expect(mine, isNotEmpty);
      expect(mine.every((p) => p.isMine), isTrue);
    });

    test('listMyCampaigns yalnız preview tedarikçinin kampanyaları', () {
      final mine = repo.listMyCampaigns();
      expect(mine, isNotEmpty);
      expect(mine.every((c) => c.isMine), isTrue);
    });

    test('Teklif Ağı: izinli alanlar dolu (anonimlik modelle garantili)', () {
      // B2bQuoteRequest'te işletme adı/telefon/adres/kişi alanı YOKTUR;
      // anonimlik tip düzeyinde garanti edilir. Burada izinli alanların
      // geldiğini doğrularız.
      final open = repo.listOpenQuoteRequests();
      expect(open, isNotEmpty);
      final q = open.first;
      expect(q.productOrCategory, isNotEmpty);
      expect(q.city, isNotEmpty);
      expect(q.buyerType, isNotEmpty);
    });

    test('Tekliflerim hepsi createdByMe', () {
      final mine = repo.listMyQuoteRequests();
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
}
