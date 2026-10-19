// Uçtan uca alıcı–tedarikçi senaryosu (S1 Panel ↔ S2 Talepler ↔ S3 geçmiş).
// Yerel repo ile: alıcı talep açar → tedarikçi Yeni'de görür, Panel KPI düşer
// → teklif verir → alıcı ilgilenir + kabul eder → tedarikçi Kazanılan'da görür,
// geçmiş RPC kararı 'won', Panel "İlgilenen" KPI'sı artar.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_quote_request.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_replied_request.dart';
import 'package:firin_defter/features/b2b_market/models/supplier_requests_inbox.dart';
import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
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

/// Yerel repo tek süreçte hem alıcı hem tedarikçi rolünü oynar: alıcının
/// talepleri `_myQuoteRequests`'e girer; tedarikçi görünümü için bu talepleri
/// açık listeye de yansıtırız (mock'ta RPC = seed listesi).
class _E2eRepo extends LocalB2bRepository {
  final List<String> _buyerCreated = [];

  @override
  Future<List<B2bQuoteRequest>> listOpenQuoteRequests() async {
    final base = await super.listOpenQuoteRequests();
    final mine = await listMyQuoteRequests();
    return [
      ...mine.where(
        (q) =>
            _buyerCreated.contains(q.id) &&
            !q.hasAcceptedReply &&
            q.status.isActive,
      ),
      ...base,
    ];
  }

  Future<String> buyerCreates() async {
    final q = await addQuoteRequest(
      targetType: 'category',
      category: 'Un',
      quantity: '500 çuval',
      city: 'Konya',
      buyerType: 'Fırın',
    );
    _buyerCreated.add(q.id);
    return q.id;
  }
}

Future<void> _surface(WidgetTester t) async {
  t.view.physicalSize = const Size(360, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<int> _kpi(WidgetTester t, String key) async {
  final tile = find.byKey(ValueKey(key));
  final texts = find.descendant(of: tile, matching: find.byType(Text));
  for (final e in texts.evaluate()) {
    final v = int.tryParse((e.widget as Text).data ?? '');
    if (v != null) return v;
  }
  throw StateError('KPI sayısı bulunamadı: $key');
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets(
    'alıcı talep → tedarikçi teklif → alıcı ilgi + kabul → Kazanılan',
    (t) async {
      await _surface(t);
      final repo = _E2eRepo();
      final overrides = [
        profileControllerProvider.overrideWith(
          (ref) => _WholesalerProfile(ref),
        ),
        totalUnreadMessagesProvider.overrideWith((ref) => 0),
        subscriptionRepositoryProvider.overrideWithValue(
          LocalSubscriptionRepository(plan: BusinessPlan.premium),
        ),
        b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.supplier),
        b2bRepositoryProvider.overrideWithValue(repo),
      ];

      // 0) Başlangıç: Panel KPI'ları.
      await t.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(home: RoleDashboardScreen()),
        ),
      );
      await t.pumpAndSettle();
      final fresh0 = await _kpi(t, 'supplier_kpi_requests');
      final leads0 = await _kpi(t, 'supplier_kpi_leads');

      // 1) Alıcı talep açar (ilk bakışta "yanıt bekleyen" +1).
      final reqId = await repo.buyerCreates();
      final el = t.element(find.byType(RoleDashboardScreen));
      final container = ProviderScope.containerOf(el);
      container.read(b2bMarketControllerProvider.notifier).state++;
      await t.pumpAndSettle();
      expect(await _kpi(t, 'supplier_kpi_requests'), fresh0 + 1);

      // 2) Tedarikçi Talepler > Yeni'de görür ve teklif verir.
      await t.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(home: Scaffold(body: SupplierRequestsTab())),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(ValueKey('sup_req_card_$reqId')), findsOneWidget);
      final el2 = t.element(find.byType(SupplierRequestsTab));
      await ProviderScope.containerOf(el2)
          .read(b2bMarketControllerProvider.notifier)
          .addQuoteReply(
            quoteRequestId: reqId,
            message: 'Haftalık 500 çuval, sabit fiyat.',
          );
      await t.pumpAndSettle();
      expect(find.byKey(ValueKey('sup_req_card_$reqId')), findsNothing);

      // 3) Alıcı: ilgileniyor + bu teklifle ilerle.
      final replies = await repo.repliesFor(reqId);
      expect(replies.length, 1);
      await repo.expressInterestInQuoteReply(
        quoteReplyId: replies.first.id,
        message: 'Numune ile başlayalım',
        phoneShared: true,
        phone: '0532 000 00 00',
      );
      await repo.acceptQuoteReply(replies.first.id);
      ProviderScope.containerOf(
        el2,
      ).read(b2bMarketControllerProvider.notifier).state++;
      await t.pumpAndSettle();

      // 4) Tedarikçi: Kazanılan segmentinde; geçmiş RPC kararı won; lead ilgi.
      final hist = await repo.listMyRepliedRequests();
      final h = hist!.firstWhere((x) => x.request.id == reqId);
      expect(h.decision, B2bReplyDecision.won);
      final box = SupplierRequestsInbox.build(
        openRequests: await repo.listOpenQuoteRequests(),
        myReplies: await repo.listMyQuoteReplies(),
        leads: await repo.leadsForMySupplierShop(),
        history: hist,
        serverCounts: await repo.supplierRequestCounts(),
      );
      expect(box.won.any((i) => i.reply.id == replies.first.id), isTrue);
      expect(
        box.interested.any((l) => l.quoteReplyId == replies.first.id),
        isTrue,
      );
      expect(box.fresh.any((r) => r.id == reqId), isFalse);

      final wonSeg = find.byKey(const ValueKey('sup_req_seg_won'));
      await t.ensureVisible(wonSeg);
      await t.tap(wonSeg);
      await t.pumpAndSettle();
      expect(find.text(AppStrings.supReqWon), findsWidgets);
      expect(find.text('500 çuval'), findsWidgets);

      // 5) Panel: İlgilenen +1, yanıt bekleyen başlangıca döner.
      await t.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(home: RoleDashboardScreen()),
        ),
      );
      await t.pumpAndSettle();
      expect(await _kpi(t, 'supplier_kpi_leads'), leads0 + 1);
      expect(await _kpi(t, 'supplier_kpi_requests'), fresh0);
    },
  );
}
