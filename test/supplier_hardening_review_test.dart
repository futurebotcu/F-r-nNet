// 2026-10-23 bağımsız inceleme bulgularının regresyon testleri.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_quote_request.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_replied_request.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_store.dart';
import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/repositories/supabase_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/screens/b2b_shell_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/forms/supplier_store_edit_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/supplier_requests_tab.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

B2bQuoteRequest _r(String id) => B2bQuoteRequest(
  id: id,
  productOrCategory: 'Un',
  quantity: '1',
  city: 'Bursa',
  district: '',
  buyerType: 'Fırın',
  deliveryTime: '',
  note: '',
  status: B2bQuoteStatus.waiting,
);

/// Sayfa 1: a,b · sayfa 2 (offset 2): b (tekrar), c · sonra boş sayfa.
/// total 10 (sunucu sayısı "yanlış" kalsa bile boş sayfa listeyi bitirmeli).
class _OverlapRepo extends LocalB2bRepository {
  int calls = 0;
  @override
  Future<B2bOpenRequestsPage?> listOpenQuoteRequestsPage({
    List<String>? categories,
    List<String>? cities,
    bool excludeReplied = true,
    int limit = 20,
    int offset = 0,
  }) async {
    calls++;
    if (offset == 0) {
      return B2bOpenRequestsPage(items: [_r('a'), _r('b')], totalCount: 10);
    }
    if (offset == 2) {
      return B2bOpenRequestsPage(items: [_r('b'), _r('c')], totalCount: 10);
    }
    return const B2bOpenRequestsPage(items: [], totalCount: 10);
  }
}

class _FailingStoreRepo extends LocalB2bRepository {
  @override
  Future<B2bStore> myStore() async => throw StateError('offline');
}

class _NoContactRepo extends LocalB2bRepository {
  @override
  bool get supportsStoreContact => false;
}

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

Future<void> _surface(WidgetTester t, {double h = 2600}) async {
  t.view.physicalSize = Size(360, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Iterable<String> _cardIds() => find
    .byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('sup_req_card_'),
    )
    .evaluate()
    .map((e) => (e.widget.key! as ValueKey<String>).value);

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('WhatsApp numarası (wa.me uluslararası format)', () {
    test('TR yerel biçimleri 90… olur; zaten uluslararası olan korunur', () {
      expect(B2bStoreContact.whatsappNumber('0532 000 00 00'), '905320000000');
      expect(B2bStoreContact.whatsappNumber('532 000 00 00'), '905320000000');
      expect(
        B2bStoreContact.whatsappNumber('+90 532 000 00 00'),
        '905320000000',
      );
      expect(
        B2bStoreContact.whatsappNumber('0090 532 000 00 00'),
        '905320000000',
      );
      expect(
        B2bStoreContact.whatsappNumber('+49 151 2345 6789'),
        '4915123456789',
      );
    });
  });

  group('Şema geri düşüşü (S3 migration öncesi sunucu)', () {
    test('kolon yok hataları tanınır; diğerleri tanınmaz', () {
      expect(
        SupabaseB2bRepository.isMissingColumn(
          const sb.PostgrestException(message: 'x', code: '42703'),
        ),
        isTrue,
      );
      expect(
        SupabaseB2bRepository.isMissingColumn(
          const sb.PostgrestException(message: 'x', code: 'PGRST204'),
        ),
        isTrue,
      );
      expect(
        SupabaseB2bRepository.isMissingColumn(
          const sb.PostgrestException(
            message: 'permission denied',
            code: '42501',
          ),
        ),
        isFalse,
      );
      expect(LocalB2bRepository().supportsStoreContact, isTrue);
    });
  });

  group('Pazar sekmesi: rol geç yüklenince ?tab= korunur', () {
    testWidgets('buyer → supplier dönüşünde Talepler seçili kalır', (t) async {
      await _surface(t);
      final role = StateProvider<B2bRole>((ref) => B2bRole.buyer);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            b2bRoleProvider.overrideWith((ref) => ref.watch(role)),
            b2bRepositoryProvider.overrideWithValue(LocalB2bRepository()),
          ],
          child: const MaterialApp(
            home: B2bShellScreen(initialTab: 'talepler'),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(SupplierRequestsTab), findsNothing);
      final el = t.element(find.byType(B2bShellScreen));
      ProviderScope.containerOf(el).read(role.notifier).state =
          B2bRole.supplier;
      await t.pumpAndSettle();
      expect(find.byType(SupplierRequestsTab), findsOneWidget);
    });
  });

  group('Talepler sayfalama', () {
    testWidgets(
      'tekrar eden kayıt ayıklanır, boş sayfada "Daha fazla" kalkar',
      (t) async {
        await _surface(t);
        final repo = _OverlapRepo();
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.supplier),
              b2bRepositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SupplierRequestsTab()),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(_cardIds().toSet(), {'sup_req_card_a', 'sup_req_card_b'});

        final more = find.byKey(const ValueKey('sup_req_load_more'));
        await t.ensureVisible(more);
        await t.tap(more);
        await t.pumpAndSettle();
        final ids = _cardIds().toList();
        expect(ids.length, ids.toSet().length, reason: 'tekrar eden kart var');
        expect(ids.toSet(), {
          'sup_req_card_a',
          'sup_req_card_b',
          'sup_req_card_c',
        });

        await t.ensureVisible(find.byKey(const ValueKey('sup_req_load_more')));
        await t.tap(find.byKey(const ValueKey('sup_req_load_more')));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('sup_req_load_more')), findsNothing);
      },
    );
  });

  group('Mağaza formu', () {
    testWidgets('yükleme hatası: yeniden dene görünür, kaydet kapalı', (
      t,
    ) async {
      await _surface(t, h: 3200);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.supplier),
            b2bRepositoryProvider.overrideWithValue(_FailingStoreRepo()),
          ],
          child: const MaterialApp(home: SupplierStoreEditScreen()),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('b2b_store_edit_load_error')),
        findsOneWidget,
      );
      final btn = t.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Mağazayı kaydet'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('sunucu iletişim kolonlarını desteklemiyorsa bölüm gizli', (
      t,
    ) async {
      await _surface(t, h: 3200);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.supplier),
            b2bRepositoryProvider.overrideWithValue(_NoContactRepo()),
          ],
          child: const MaterialApp(home: SupplierStoreEditScreen()),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('b2b_store_phone')), findsNothing);
      expect(find.text(AppStrings.b2bStoreContactPrivacy), findsNothing);
    });

    testWidgets('telefon alanı sunucu sınırıyla (32) kısıtlı', (t) async {
      await _surface(t, h: 3200);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.supplier),
            b2bRepositoryProvider.overrideWithValue(LocalB2bRepository()),
          ],
          child: const MaterialApp(home: SupplierStoreEditScreen()),
        ),
      );
      await t.pumpAndSettle();
      final field = find.descendant(
        of: find.byKey(const ValueKey('b2b_store_phone')),
        matching: find.byType(TextField),
      );
      expect(t.widget<TextField>(field).maxLength, 32);
    });
  });

  group('Panel ürün KPI', () {
    testWidgets('değer taslaklar dahil toplam ürün (sunucu kotasıyla aynı)', (
      t,
    ) async {
      await _surface(t);
      final repo = LocalB2bRepository();
      final total = (await repo.listMyProducts()).length;
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
            b2bRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: RoleDashboardScreen()),
        ),
      );
      await t.pumpAndSettle();
      final tile = find.byKey(const ValueKey('supplier_kpi_products'));
      expect(
        find.descendant(of: tile, matching: find.text('$total')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.textContaining(AppStrings.supPanelKpiPublished),
        ),
        findsOneWidget,
      );
    });
  });

  test('B2bRepliedRequest import kullanımı (derleme)', () {
    expect(B2bReplyDecision.values.length, 4);
  });
}
