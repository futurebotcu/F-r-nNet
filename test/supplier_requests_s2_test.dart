// S2 — Tedarikçi Talepler merkezi testleri.
//
// Kapsam: SupplierRequestsInbox (saf hesap), filtre/arama, hedef bağlamı,
// SupplierRequestsTab widget durumları (segmentler, Yeni/Yanıtladıklarım,
// boş durumlar, filtre), Panel KPI'sinin aynı kaynağı kullanması,
// 320px + büyük yazı taşma.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/b2b_market/data/b2b_mock_seed.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_campaign.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_product.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_quote_lead.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_quote_reply.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_quote_request.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_replied_request.dart';
import 'package:firin_defter/features/b2b_market/models/supplier_requests_inbox.dart';
import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/repositories/supabase_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/screens/b2b_shell_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/supplier_requests_tab.dart';
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
  String cat = 'Un',
  String city = 'İstanbul',
  B2bQuoteStatus status = B2bQuoteStatus.waiting,
  String targetType = 'category',
  String? targetId,
}) => B2bQuoteRequest(
  id: id,
  productOrCategory: cat,
  quantity: '10 çuval',
  city: city,
  district: '',
  buyerType: 'Fırın',
  deliveryTime: '',
  note: 'not',
  status: status,
  targetType: targetType,
  targetId: targetId,
);

B2bQuoteReply _rep(
  String id,
  String reqId, {
  bool accepted = false,
  B2bReplyStatus status = B2bReplyStatus.sent,
}) => B2bQuoteReply(
  id: id,
  requestId: reqId,
  supplierName: 'Ben',
  message: 'Teklif mesajı',
  createdAtLabel: 'dün',
  supplierShopId: 's1',
  accepted: accepted,
  status: status,
);

B2bQuoteLead _lead(
  String id,
  String reqId,
  String replyId, {
  bool interested = true,
}) => B2bQuoteLead(
  id: id,
  quoteRequestId: reqId,
  quoteReplyId: replyId,
  supplierShopId: 's1',
  status: interested ? B2bLeadStatus.interested : B2bLeadStatus.rejected,
  requestCategory: 'Maya',
  requestQuantity: '5 koli',
  requestCity: 'Bursa',
);

class _WholesalerProfile extends ProfileController {
  _WholesalerProfile(super.ref) {
    state = const BakeryProfile(
      displayName: 'Anadolu Un',
      accountType: AccountType.wholesaler,
      city: 'Konya',
      roleBadge: 'Toptancı',
      email: 't@t.com',
    );
  }
}

Future<void> _setSurface(
  WidgetTester tester, {
  double width = 360,
  double height = 2000,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

List<FlutterErrorDetails> _captureOverflows() {
  final overflows = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) {
      overflows.add(details);
    } else {
      debugPrint('[test] non-overflow error: ${details.exceptionAsString()}');
      previous?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
  return overflows;
}

/// S3 geçmiş RPC'si olmayan backend (migration uygulanmamış) → S2 fallback.
class _NoHistoryRepo extends LocalB2bRepository {
  @override
  Future<List<B2bRepliedRequest>?> listMyRepliedRequests() async => null;
}

Widget _tab({List<Override> extra = const []}) => ProviderScope(
  overrides: [
    b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.supplier),
    b2bRepositoryProvider.overrideWithValue(LocalB2bRepository()),
    ...extra,
  ],
  child: const MaterialApp(home: Scaffold(body: SupplierRequestsTab())),
);

Future<void> _tapSeg(WidgetTester tester, String name) async {
  final f = find.byKey(ValueKey('sup_req_seg_$name'));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('SupplierRequestsInbox.build', () {
    test('Yeni = aktif açık talepler − yanıtladıklarım; ağ sayısı ayrı', () {
      final open = [
        _req('a'),
        _req('b', status: B2bQuoteStatus.replied),
        _req('c', status: B2bQuoteStatus.closed),
        _req('d'),
      ];
      final box = SupplierRequestsInbox.build(
        openRequests: open,
        myReplies: [_rep('r1', 'b')],
        leads: const [],
      );
      expect(box.fresh.map((r) => r.id), ['a', 'd']);
      expect(box.networkOpenCount, 3); // a, b, d (c kapalı)
      expect(box.replied.length, 1);
      expect(box.replied.first.request?.id, 'b');
      expect(box.replied.first.requestStillOpen, isTrue);
      expect(box.won, isEmpty);
      expect(box.interested, isEmpty);
    });

    test('Yanıtladıklarım: talep açık değilse lead özeti, o da yoksa '
        'requestUnavailable', () {
      final box = SupplierRequestsInbox.build(
        openRequests: const [],
        myReplies: [_rep('r1', 'x'), _rep('r2', 'y')],
        leads: [_lead('l1', 'x', 'r1')],
      );
      final byReply = {for (final i in box.replied) i.reply.id: i};
      expect(byReply['r1']!.requestUnavailable, isFalse);
      expect(byReply['r1']!.title, 'Maya');
      expect(byReply['r1']!.city, 'Bursa');
      expect(byReply['r2']!.requestUnavailable, isTrue);
      expect(byReply['r2']!.title, '');
    });

    test('Kazanılan = accepted cevaplarım; İlgilenenler = interested lead', () {
      final box = SupplierRequestsInbox.build(
        openRequests: const [],
        myReplies: [
          _rep('r1', 'x', accepted: true, status: B2bReplyStatus.accepted),
          _rep('r2', 'y', status: B2bReplyStatus.declined),
        ],
        leads: [
          _lead('l1', 'x', 'r1'),
          _lead('l2', 'y', 'r2', interested: false),
        ],
      );
      expect(box.won.map((i) => i.reply.id), ['r1']);
      expect(box.won.first.won, isTrue);
      expect(box.replied.firstWhere((i) => i.reply.id == 'r2').lost, isTrue);
      expect(box.interested.map((l) => l.id), ['l1']);
    });

    test(
      'Hedef bağlamı: ürünüm / kampanyam / mağazam / başkası / kategori',
      () {
        const p = B2bProduct(
          id: 'p1',
          name: 'Tip 650',
          supplierId: 's1',
          supplierName: 'Ben',
          category: 'Un',
          minOrder: '-',
          deliveryRegion: '-',
        );
        const c = B2bCampaign(
          id: 'c1',
          title: 'Yaz indirimi',
          supplierId: 's1',
          supplierName: 'Ben',
          category: 'Un',
          region: '-',
          minPurchase: '-',
          validUntil: 'Süresiz',
        );
        SupplierRequestTarget t(String type, String? id) =>
            SupplierRequestsInbox.targetOf(
              _req('q', targetType: type, targetId: id),
              myShopId: 's1',
              myProducts: const [p],
              myCampaigns: const [c],
            );
        expect(t('product', 'p1'), SupplierRequestTarget.mine);
        expect(t('product', 'p9'), SupplierRequestTarget.other);
        expect(t('campaign', 'c1'), SupplierRequestTarget.mine);
        expect(t('shop', 's1'), SupplierRequestTarget.mine);
        expect(t('shop', 's2'), SupplierRequestTarget.other);
        expect(t('category', null), SupplierRequestTarget.category);
        expect(t('product', null), SupplierRequestTarget.category);

        expect(
          SupplierRequestsInbox.myTargetLabel(
            _req('q', targetType: 'product', targetId: 'p1'),
            myShopId: 's1',
            myProducts: const [p],
            myCampaigns: const [c],
          ),
          'Tip 650',
        );
        // Başka tedarikçinin ürünü için ad asla üretilmez.
        expect(
          SupplierRequestsInbox.myTargetLabel(
            _req('q', targetType: 'product', targetId: 'p9'),
            myShopId: 's1',
            myProducts: const [p],
            myCampaigns: const [c],
          ),
          isNull,
        );
      },
    );
  });

  group('SupplierRequestFilter', () {
    final rs = [
      _req('a', cat: 'Un', city: 'İstanbul'),
      _req('b', cat: 'Maya', city: 'Bursa'),
      _req('c', cat: 'Un', city: 'İzmir'),
    ];

    test('kategori / il seçenekleri veriden, sıralı ve benzersiz', () {
      expect(SupplierRequestFilter.categoriesOf(rs), ['Maya', 'Un']);
      expect(SupplierRequestFilter.citiesOf(rs), [
        'Bursa',
        'İstanbul',
        'İzmir',
      ]);
    });

    test('kategori + il + Türkçe-duyarlı metin araması', () {
      const f1 = SupplierRequestFilter(category: 'Un');
      expect(rs.where(f1.matchesRequest).map((r) => r.id), ['a', 'c']);
      const f2 = SupplierRequestFilter(category: 'Un', city: 'İzmir');
      expect(rs.where(f2.matchesRequest).map((r) => r.id), ['c']);
      // "İSTANBUL" → plain toLowerCase 'i̇stanbul' olurdu; normalize ile eşleşir.
      const f3 = SupplierRequestFilter(query: 'İSTANBUL');
      expect(rs.where(f3.matchesRequest).map((r) => r.id), ['a']);
      const f4 = SupplierRequestFilter(query: 'maya');
      expect(rs.where(f4.matchesRequest).map((r) => r.id), ['b']);
      expect(const SupplierRequestFilter().isEmpty, isTrue);
    });
  });

  group('Mapper (Supabase satırı → model)', () {
    test(
      'talep: target_type/target_id/created_at; cevap: status/created_at',
      () {
        final r = SupabaseB2bRepository.quoteRequestFromRow({
          'id': 'q',
          'category': 'Un',
          'quantity': '1',
          'city': 'X',
          'status': 'open',
          'target_type': 'product',
          'target_id': 'p1',
          'created_at': '2026-10-16T10:00:00+00:00',
        });
        expect(r.targetType, 'product');
        expect(r.targetId, 'p1');
        expect(r.createdAt, isNotNull);
        final rep = SupabaseB2bRepository.quoteReplyFromRow({
          'id': 'r',
          'quote_request_id': 'q',
          'message': 'm',
          'status': 'declined',
          'accepted': false,
          'created_at': '2026-10-16T10:00:00+00:00',
        });
        expect(rep.status, B2bReplyStatus.declined);
        expect(rep.createdAt, isNotNull);
        expect(B2bReplyStatusX.fromText(null), B2bReplyStatus.sent);
      },
    );
  });

  group('SupplierRequestsTab widget (mock seed)', () {
    testWidgets('segmentler + Yeni listesi = yanıtlanmamış aktif talepler', (
      tester,
    ) async {
      await _setSurface(tester);
      await tester.pumpWidget(_tab());
      await tester.pumpAndSettle();
      for (final s in SupplierRequestsSegment.values) {
        expect(find.byKey(ValueKey('sup_req_seg_${s.name}')), findsOneWidget);
      }
      final repo = LocalB2bRepository();
      final box = SupplierRequestsInbox.build(
        openRequests: await repo.listOpenQuoteRequests(),
        myReplies: await repo.listMyQuoteReplies(),
        leads: await repo.leadsForMySupplierShop(),
      );
      expect(box.fresh, isNotEmpty);
      for (final r in box.fresh) {
        expect(find.byKey(ValueKey('sup_req_card_${r.id}')), findsOneWidget);
      }
      // Kapalı talep (q5) Yeni'de yok.
      expect(find.byKey(const ValueKey('sup_req_card_q5')), findsNothing);
      expect(
        find.text(AppStrings.supReqGiveOffer),
        findsNWidgets(box.fresh.length),
      );
      expect(find.textContaining('anonim'), findsWidgets);
      // Alıcı kimliği hiçbir yerde yok.
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('Yanıtladıklarım (S3 geçmiş RPC yokken): açık olmayan talep '
        'için dürüst "artık açık değil" kartı', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(
        _tab(
          extra: [b2bRepositoryProvider.overrideWithValue(_NoHistoryRepo())],
        ),
      );
      await tester.pumpAndSettle();
      await _tapSeg(tester, 'replied');
      // Seed: s1'in r1 cevabı m1 talebine (açık talepler RPC'sinde değil) →
      // geçmiş RPC yoksa talep ayrıntısı yok.
      expect(find.byKey(const ValueKey('sup_replied_card_r1')), findsOneWidget);
      expect(find.text(AppStrings.supReqClosedUnknown), findsWidgets);
      expect(find.text(AppStrings.supReqMyOffer), findsOneWidget);
      expect(find.text(AppStrings.supReqGiveOffer), findsNothing);
    });

    testWidgets('Yanıtladıklarım (S3 geçmiş RPC varken): kapanmış talebin '
        'ayrıntısı görünür, "artık açık değil" yok', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_tab());
      await tester.pumpAndSettle();
      await _tapSeg(tester, 'replied');
      expect(find.byKey(const ValueKey('sup_replied_card_r1')), findsOneWidget);
      expect(find.text(AppStrings.supReqClosedUnknown), findsNothing);
      expect(find.text('Ekmeklik Un (Tip 650)'), findsWidgets);
    });

    testWidgets(
      'teklif verince talep Yeni\'den çıkar, Yanıtladıklarım\'a girer',
      (tester) async {
        await _setSurface(tester);
        final repo = LocalB2bRepository();
        await tester.pumpWidget(
          _tab(extra: [b2bRepositoryProvider.overrideWithValue(repo)]),
        );
        await tester.pumpAndSettle();
        final first = (await repo.listOpenQuoteRequests()).firstWhere(
          (r) => r.status.isActive,
        );
        expect(
          find.byKey(ValueKey('sup_req_card_${first.id}')),
          findsOneWidget,
        );
        // Repo üzerinden yanıt ver (sheet akışı ayrı test edilir) + tick.
        final el = tester.element(find.byType(SupplierRequestsTab));
        final container = ProviderScope.containerOf(el);
        await container
            .read(b2bMarketControllerProvider.notifier)
            .addQuoteReply(quoteRequestId: first.id, message: 'Verebiliriz');
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('sup_req_card_${first.id}')), findsNothing);
        await _tapSeg(tester, 'replied');
        expect(find.text(first.productOrCategory), findsWidgets);
        expect(find.text(AppStrings.supReqWaiting), findsWidgets);
      },
    );

    testWidgets('kategori chip filtresi + temizle', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_tab());
      await tester.pumpAndSettle();
      final repo = LocalB2bRepository();
      final open = (await repo.listOpenQuoteRequests())
          .where((r) => r.status.isActive)
          .toList();
      final cat = open.first.productOrCategory;
      final expected = open.where((r) => r.productOrCategory == cat).length;
      await tester.tap(find.byKey(ValueKey('sup_req_cat_$cat')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.supReqGiveOffer), findsNWidgets(expected));
      expect(
        find.byKey(const ValueKey('sup_req_filter_clear')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('sup_req_filter_clear')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.supReqGiveOffer), findsNWidgets(open.length));
    });

    testWidgets('arama: eşleşme yoksa filtreli boş durum + temizle CTA', (
      tester,
    ) async {
      await _setSurface(tester);
      await tester.pumpWidget(_tab());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('sup_req_search')),
        'zzzz-yok',
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.supReqEmptyFreshFiltered), findsOneWidget);
      expect(find.text(AppStrings.supReqFilterClear), findsWidgets);
    });

    testWidgets('İlgilenenler ve Kazanılan boş durumları dürüst', (
      tester,
    ) async {
      await _setSurface(tester);
      await tester.pumpWidget(_tab());
      await tester.pumpAndSettle();
      await _tapSeg(tester, 'interested');
      expect(find.text(AppStrings.supReqEmptyInterestedTitle), findsOneWidget);
      await _tapSeg(tester, 'won');
      expect(find.text(AppStrings.supReqEmptyWonTitle), findsOneWidget);
    });

    testWidgets('hata → ErrorRetryState', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(
        _tab(
          extra: [
            b2bOpenQuoteRequestsProvider.overrideWith(
              (ref) async => throw StateError('offline'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.retry), findsOneWidget);
    });

    testWidgets('shell: Talepler sekmesi ?tab=talepler ile açılır', (
      tester,
    ) async {
      await _setSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.supplier),
            b2bRepositoryProvider.overrideWithValue(LocalB2bRepository()),
          ],
          child: const MaterialApp(
            home: B2bShellScreen(initialTab: 'talepler'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SupplierRequestsTab), findsOneWidget);
      expect(find.byKey(const ValueKey('sup_req_seg_fresh')), findsOneWidget);
    });

    for (final scale in const [1.0, 1.3, 1.5]) {
      testWidgets('320px · ${scale}x taşma yok (Yeni + Yanıtladıklarım)', (
        tester,
      ) async {
        await _setSurface(tester, width: 320, height: 2400, textScale: scale);
        final overflows = _captureOverflows();
        await tester.pumpWidget(_tab());
        await tester.pumpAndSettle();
        await _tapSeg(tester, 'replied');
        expect(overflows, isEmpty);
      });
    }
  });

  group('Panel KPI entegrasyonu (S1 ↔ S2 aynı kaynak)', () {
    testWidgets('"Yanıt bekleyen" = yanıtlamadığım açık talep; yardımcı metin '
        'ağ toplamı', (tester) async {
      await _setSurface(tester, width: 360, height: 2400);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _WholesalerProfile(ref),
            ),
            totalUnreadMessagesProvider.overrideWith((ref) => 0),
            subscriptionRepositoryProvider.overrideWithValue(
              LocalSubscriptionRepository(plan: BusinessPlan.premium),
            ),
            b2bRepositoryProvider.overrideWithValue(LocalB2bRepository()),
          ],
          child: const MaterialApp(home: RoleDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final repo = LocalB2bRepository();
      final box = SupplierRequestsInbox.build(
        openRequests: await repo.listOpenQuoteRequests(),
        myReplies: await repo.listMyQuoteReplies(),
        leads: await repo.leadsForMySupplierShop(),
      );
      final tile = find.byKey(const ValueKey('supplier_kpi_requests'));
      expect(
        find.descendant(of: tile, matching: find.text('${box.fresh.length}')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.text(
            AppStrings.supPanelKpiNetworkHelper(box.networkOpenCount),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(AppStrings.supPanelKpiOpenRequests), findsOneWidget);
      // Mock seed sanity: ağ toplamı ile kişisel sayı aynı kavram değil.
      expect(
        B2bMockSeed.openQuoteRequests.length,
        greaterThanOrEqualTo(box.fresh.length),
      );
    });
  });
}
