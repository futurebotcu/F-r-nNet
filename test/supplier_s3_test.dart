// S3 — Tedarikçi: talep geçmişi (RPC/fallback), sunucu sayfalama, ürün
// silme/çoğaltma, kampanya-ürün bağı, mağaza iletişim alanları.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_quote_reply.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_quote_request.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_replied_request.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_store.dart';
import 'package:firin_defter/features/b2b_market/models/supplier_requests_inbox.dart';
import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/repositories/supabase_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/forms/supplier_campaign_form_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/forms/supplier_store_edit_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/supplier_requests_tab.dart';
import 'package:firin_defter/features/b2b_market/widgets/b2b_product_card.dart';
import 'package:firin_defter/features/b2b_market/widgets/b2b_store_contact.dart';
import 'package:firin_defter/features/dashboard/screens/role_dashboard_screen.dart';
import 'package:firin_defter/features/messaging/providers/messaging_providers.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

B2bQuoteRequest _req(
  String id, {
  B2bQuoteStatus status = B2bQuoteStatus.waiting,
}) => B2bQuoteRequest(
  id: id,
  productOrCategory: 'Un',
  quantity: '1',
  city: 'Bursa',
  district: '',
  buyerType: 'Fırın',
  deliveryTime: '',
  note: '',
  status: status,
);

B2bQuoteReply _rep(String id, String reqId) => B2bQuoteReply(
  id: id,
  requestId: reqId,
  supplierName: 'Ben',
  message: 'm',
  createdAtLabel: 'dün',
  supplierShopId: 's1',
);

class _WholesalerProfile extends ProfileController {
  _WholesalerProfile(super.ref) {
    state = const BakeryProfile(
      displayName: 'A',
      accountType: AccountType.wholesaler,
      city: 'K',
      roleBadge: 'T',
      email: 't@t.com',
    );
  }
}

/// Sunucu RPC'leri olmayan (migration uygulanmamış) backend simülasyonu.
class _NoRpcRepo extends LocalB2bRepository {
  @override
  Future<List<B2bRepliedRequest>?> listMyRepliedRequests() async => null;
  @override
  Future<B2bOpenRequestsPage?> listOpenQuoteRequestsPage({
    List<String>? categories,
    List<String>? cities,
    bool excludeReplied = true,
    int limit = 20,
    int offset = 0,
  }) async => null;
  @override
  Future<B2bSupplierRequestCounts?> supplierRequestCounts() async => null;
}

/// Küçük sayfa boyutu simülasyonu (Daha fazla yükle).
class _SmallPageRepo extends LocalB2bRepository {
  @override
  Future<B2bOpenRequestsPage?> listOpenQuoteRequestsPage({
    List<String>? categories,
    List<String>? cities,
    bool excludeReplied = true,
    int limit = 20,
    int offset = 0,
  }) => super.listOpenQuoteRequestsPage(
    categories: categories,
    cities: cities,
    excludeReplied: excludeReplied,
    limit: 2,
    offset: offset,
  );

  @override
  Future<B2bSupplierRequestCounts?> supplierRequestCounts() async =>
      const B2bSupplierRequestCounts(fresh: 42, networkOpen: 99);
}

Future<void> _surface(WidgetTester t, {double w = 360, double h = 2000}) async {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Widget _supplierApp(Widget home, {LocalB2bRepository? repo}) => ProviderScope(
  overrides: [
    b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.supplier),
    b2bRepositoryProvider.overrideWithValue(repo ?? LocalB2bRepository()),
  ],
  child: MaterialApp(home: home),
);

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('Mapper (S3 RPC satırları)', () {
    test('repliedRequestFromRow: decision + talep + cevap; kimlik yok', () {
      final r = SupabaseB2bRepository.repliedRequestFromRow({
        'request_id': 'q1',
        'category': 'Un',
        'quantity': '10',
        'city': 'Bursa',
        'district': '',
        'buyer_type': 'Fırın',
        'delivery_time': '',
        'note': 'n',
        'request_status': 'closed',
        'request_created_at': '2026-10-01T10:00:00+00:00',
        'target_type': 'category',
        'target_id': null,
        'my_reply_id': 'r1',
        'my_reply_status': 'sent',
        'my_reply_accepted': false,
        'my_reply_created_at': '2026-10-02T10:00:00+00:00',
        'decision': 'closed',
      });
      expect(r.decision, B2bReplyDecision.closed);
      expect(r.request.id, 'q1');
      expect(r.request.status, B2bQuoteStatus.closed);
      expect(r.request.acceptedReplyId, isNull);
      expect(r.reply.id, 'r1');
      expect(r.reply.createdAt, isNotNull);
      final won = SupabaseB2bRepository.repliedRequestFromRow({
        'request_id': 'q2',
        'my_reply_id': 'r2',
        'decision': 'won',
        'my_reply_status': 'accepted',
        'my_reply_accepted': true,
      });
      expect(won.decision, B2bReplyDecision.won);
      expect(won.request.hasAcceptedReply, isTrue);
      expect(B2bReplyDecisionX.fromText('lost'), B2bReplyDecision.lost);
      expect(B2bReplyDecisionX.fromText(null), B2bReplyDecision.pending);
    });

    test('storeFromRow: iletişim alanları (boş → null)', () {
      final s = SupabaseB2bRepository.storeFromRow({
        'id': 's',
        'owner_id': 'u',
        'shop_name': 'A',
        'phone': ' 0532 ',
        'whatsapp': '',
        'website': null,
        'address': 'X',
      });
      expect(s.phone, '0532');
      expect(s.whatsapp, isNull);
      expect(s.website, isNull);
      expect(s.address, 'X');
      expect(s.hasContact, isTrue);
    });

    test('campaignFromRow: linked_product_id + embed adı', () {
      final c = SupabaseB2bRepository.campaignFromRow({
        'id': 'c',
        'shop_id': 's',
        'title': 'K',
        'category': 'Un',
        'linked_product_id': 'p1',
        'linked_product': {'name': 'Tip 650'},
      });
      expect(c.linkedProductId, 'p1');
      expect(c.linkedProduct, 'Tip 650');
    });
  });

  group('Inbox — sunucu geçmişi ve sayaçlar', () {
    test(
      'history varsa kapanmış talebin ayrıntısı gelir; decision kararı belirler',
      () {
        final closedReq = _req('x', status: B2bQuoteStatus.closed);
        final box = SupplierRequestsInbox.build(
          openRequests: const [],
          myReplies: [_rep('r1', 'x'), _rep('r2', 'y')],
          leads: const [],
          history: [
            B2bRepliedRequest(
              request: closedReq,
              reply: _rep('r1', 'x'),
              decision: B2bReplyDecision.closed,
            ),
            B2bRepliedRequest(
              request: _req('y'),
              reply: _rep('r2', 'y'),
              decision: B2bReplyDecision.won,
            ),
          ],
          serverCounts: const B2bSupplierRequestCounts(
            fresh: 7,
            networkOpen: 12,
          ),
        );
        expect(box.historyAvailable, isTrue);
        final r1 = box.replied.firstWhere((i) => i.reply.id == 'r1');
        expect(r1.requestUnavailable, isFalse);
        expect(r1.title, 'Un');
        expect(r1.closed, isTrue);
        expect(r1.won, isFalse);
        final r2 = box.replied.firstWhere((i) => i.reply.id == 'r2');
        expect(r2.won, isTrue);
        expect(box.won.length, 1);
        expect(box.freshCount, 7);
        expect(box.networkOpenCount, 12);
      },
    );

    test('history null → S2 davranışı (fallback) korunur', () {
      final box = SupplierRequestsInbox.build(
        openRequests: const [],
        myReplies: [_rep('r1', 'x')],
        leads: const [],
        history: null,
      );
      expect(box.historyAvailable, isFalse);
      expect(box.replied.single.requestUnavailable, isTrue);
      expect(box.freshCount, 0);
    });
  });

  group('LocalB2bRepository — S3 metotları', () {
    test(
      'duplicateProduct taslak kopya; deleteProduct kampanya bağını temizler',
      () async {
        final repo = LocalB2bRepository();
        final mine = await repo.listMyProducts();
        final src = mine.first;
        final copy = await repo.duplicateProduct(src.id);
        expect(copy.name, '${src.name} (kopya)');
        expect(copy.published, isFalse);
        expect((await repo.listMyProducts()).length, mine.length + 1);

        final c = await repo.addCampaign(
          title: 'K',
          category: 'Un',
          region: 'Marmara',
          minPurchase: '-',
          validUntil: '',
          linkedProductId: src.id,
        );
        expect(c.linkedProductId, src.id);
        expect(c.linkedProduct, src.name);
        await repo.deleteProduct(src.id);
        expect(
          (await repo.listMyProducts()).any((p) => p.id == src.id),
          isFalse,
        );
        final after = await repo.campaignById(c.id);
        expect(after!.linkedProductId, isNull);
        await repo.deleteCampaign(c.id);
        expect(await repo.campaignById(c.id), isNull);
      },
    );

    test(
      'updateStore iletişim; listMyRepliedRequests; sayfalama; sayaç',
      () async {
        final repo = LocalB2bRepository();
        final s = await repo.updateStore(
          name: 'A',
          description: 'd',
          serviceRegions: const [],
          categories: const [],
          phone: '0532 1',
          whatsapp: ' ',
          website: 'firma.com',
          address: '',
        );
        expect(s.phone, '0532 1');
        expect(s.whatsapp, isNull);
        expect(s.website, 'firma.com');
        expect(s.address, isNull);

        final hist = await repo.listMyRepliedRequests();
        expect(hist, isNotNull);
        expect(hist!.every((h) => h.request.id == h.reply.requestId), isTrue);

        final all = await repo.listOpenQuoteRequestsPage(
          excludeReplied: false,
          limit: 100,
        );
        final p1 = await repo.listOpenQuoteRequestsPage(
          excludeReplied: false,
          limit: 2,
          offset: 0,
        );
        expect(p1!.items.length, 2);
        expect(p1.totalCount, all!.totalCount);
        expect(p1.hasMoreAfter(0), all.totalCount > 2);
        final counts = await repo.supplierRequestCounts();
        final fresh = await repo.listOpenQuoteRequestsPage(limit: 100);
        expect(counts!.fresh, fresh!.totalCount);
        expect(counts.networkOpen, all.totalCount);
      },
    );
  });

  group('Widgetlar', () {
    testWidgets('B2bStoreContact: alanlara göre butonlar; boşsa hiçbir şey', (
      t,
    ) async {
      await _surface(t);
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: B2bStoreContact(
              store: B2bStore(
                id: 's',
                name: 'A',
                monogram: 'A',
                tagline: '',
                description: '',
                categories: [],
                serviceRegions: [],
                productCount: 0,
                campaignCount: 0,
                phone: '0532',
                whatsapp: '0532',
                website: 'firma.com',
                address: 'Konya',
              ),
            ),
          ),
        ),
      );
      await t.pump();
      expect(find.byKey(const ValueKey('b2b_store_call')), findsOneWidget);
      expect(find.byKey(const ValueKey('b2b_store_whatsapp')), findsOneWidget);
      expect(find.byKey(const ValueKey('b2b_store_website')), findsOneWidget);
      expect(find.text('Konya'), findsOneWidget);
      expect(
        B2bStoreContact.websiteUri('firma.com').toString(),
        'https://firma.com',
      );
      expect(B2bStoreContact.websiteUri('http://x.y/z')!.scheme, 'http');
      expect(B2bStoreContact.websiteUri(''), isNull);
      expect(B2bStoreContact.digitsOf('+90 (532) 000-00-00'), '905320000000');

      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: B2bStoreContact(
              store: B2bStore(
                id: 's',
                name: 'A',
                monogram: 'A',
                tagline: '',
                description: '',
                categories: [],
                serviceRegions: [],
                productCount: 0,
                campaignCount: 0,
              ),
            ),
          ),
        ),
      );
      await t.pump();
      expect(find.byType(OutlinedButton), findsNothing);
    });

    test('mağaza formu doğrulayıcıları', () {
      expect(SupplierStoreEditScreenValidators.phone(''), isNull);
      expect(SupplierStoreEditScreenValidators.phone('0532 000 00 00'), isNull);
      expect(
        SupplierStoreEditScreenValidators.phone('123'),
        AppStrings.b2bPhoneInvalid,
      );
      expect(SupplierStoreEditScreenValidators.website(''), isNull);
      expect(SupplierStoreEditScreenValidators.website('firma.com'), isNull);
      expect(
        SupplierStoreEditScreenValidators.website('https://firma.com/x'),
        isNull,
      );
      expect(
        SupplierStoreEditScreenValidators.website('firma'),
        AppStrings.b2bWebsiteInvalid,
      );
    });

    testWidgets('mağaza formu iletişim alanlarını gösterir', (t) async {
      await _surface(t, h: 3000);
      await t.pumpWidget(_supplierApp(const SupplierStoreEditScreen()));
      await t.pumpAndSettle();
      for (final k in const [
        'b2b_store_phone',
        'b2b_store_whatsapp',
        'b2b_store_website',
        'b2b_store_address',
      ]) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      expect(find.text(AppStrings.b2bStoreContactPrivacy), findsOneWidget);
    });

    testWidgets(
      'kampanya formu: ürün seçici (serbest metin yok) + bağı kaldır',
      (t) async {
        await _surface(t, h: 3000);
        await t.pumpWidget(_supplierApp(const SupplierCampaignFormScreen()));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('b2b_linked_product_picker')),
          findsOneWidget,
        );
        expect(find.text('Ör. Ekmeklik Un (Tip 650)'), findsNothing);
        final repo = LocalB2bRepository();
        final first = (await repo.listMyProducts()).first;
        await t.ensureVisible(find.text(first.name).first);
        await t.tap(find.text(first.name).first);
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('b2b_linked_product_clear')),
          findsOneWidget,
        );
        await t.tap(find.byKey(const ValueKey('b2b_linked_product_clear')));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('b2b_linked_product_clear')),
          findsNothing,
        );
      },
    );

    testWidgets('ürün kartı Yönet menüsü: Çoğalt + Sil; Sil onay ister', (
      t,
    ) async {
      await _surface(t);
      var deleted = false;
      var duplicated = false;
      final repo = LocalB2bRepository();
      final p = (await repo.listMyProducts()).first;
      await t.pumpWidget(
        _supplierApp(
          Scaffold(
            body: B2bProductCard(
              product: p,
              onEdit: () {},
              onTogglePublish: () {},
              onDuplicate: () => duplicated = true,
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Yönet'));
      await t.pumpAndSettle();
      expect(find.text(AppStrings.b2bMenuDuplicate), findsOneWidget);
      expect(find.text(AppStrings.b2bMenuDelete), findsOneWidget);
      await t.tap(find.text(AppStrings.b2bMenuDuplicate));
      await t.pumpAndSettle();
      expect(duplicated, isTrue);
      await t.tap(find.byTooltip('Yönet'));
      await t.pumpAndSettle();
      await t.tap(find.text(AppStrings.b2bMenuDelete));
      await t.pumpAndSettle();
      expect(deleted, isTrue);
    });

    testWidgets('Talepler: sunucu sayfalama → "Daha fazla" yükler; sayaç', (
      t,
    ) async {
      await _surface(t, h: 2600);
      await t.pumpWidget(
        _supplierApp(
          const Scaffold(body: SupplierRequestsTab()),
          repo: _SmallPageRepo(),
        ),
      );
      await t.pumpAndSettle();
      final loadMore = find.byKey(const ValueKey('sup_req_load_more'));
      expect(loadMore, findsOneWidget);
      final before = find
          .byType(SupplierRequestsTab)
          .evaluate()
          .length; // sanity
      expect(before, 1);
      final cardsBefore = find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith('sup_req_card_'),
          )
          .evaluate()
          .length;
      expect(cardsBefore, 2);
      await t.ensureVisible(loadMore);
      await t.tap(loadMore);
      await t.pumpAndSettle();
      final cardsAfter = find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith('sup_req_card_'),
          )
          .evaluate()
          .length;
      expect(cardsAfter, greaterThan(cardsBefore));
    });

    testWidgets('RPC yokken (fallback) Talepler ve kart listesi çalışır', (
      t,
    ) async {
      await _surface(t, h: 2600);
      await t.pumpWidget(
        _supplierApp(
          const Scaffold(body: SupplierRequestsTab()),
          repo: _NoRpcRepo(),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('sup_req_load_more')), findsNothing);
      expect(find.textContaining('anonim'), findsWidgets);
      expect(find.byKey(const ValueKey('sup_req_card_q1')), findsOneWidget);
    });

    testWidgets('Panel KPI sunucu sayacını kullanır', (t) async {
      await _surface(t, h: 2600);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _WholesalerProfile(ref),
            ),
            totalUnreadMessagesProvider.overrideWith((ref) => 0),
            subscriptionRepositoryProvider.overrideWithValue(
              LocalSubscriptionRepository(plan: BusinessPlan.premium),
            ),
            b2bRepositoryProvider.overrideWithValue(_SmallPageRepo()),
          ],
          child: const MaterialApp(home: RoleDashboardScreen()),
        ),
      );
      await t.pumpAndSettle();
      final tile = find.byKey(const ValueKey('supplier_kpi_requests'));
      expect(
        find.descendant(of: tile, matching: find.text('42')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.text(AppStrings.supPanelKpiNetworkHelper(99)),
        ),
        findsOneWidget,
      );
    });
  });
}
