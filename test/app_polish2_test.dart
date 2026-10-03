// Uygulama polish 2 — onay dialogları, geri bildirim, dar ekran / büyük yazı.
//
// Kapsam:
//   1. Kapsamdaki onaylar ortak showAppConfirmDialog'u kullanır ("Vazgeç" +
//      eylemi adlandıran CTA; belirsiz "Tamam/Evet/Hayır" yok).
//   2. Temsilî akışlar AppFeedback (app_feedback_success) ile bildirilir.
//   3. Panel, Paketler, Ayarlar 320px genişlikte 1.0/1.3/1.5 yazı ölçeğinde
//      taşmadan çizilir; paywall sheet 320/1.5'te taşmaz.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/dirty_form_guard.dart';
import 'package:firin_defter/features/branches/providers/branch_providers.dart';
import 'package:firin_defter/features/branches/repositories/local_branch_repository.dart';
import 'package:firin_defter/features/dashboard/screens/role_dashboard_screen.dart';
import 'package:firin_defter/features/debt_expense/models/debt_expense_entry.dart';
import 'package:firin_defter/features/debt_expense/providers/debt_expense_providers.dart';
import 'package:firin_defter/features/debt_expense/repositories/local_debt_expense_repository.dart';
import 'package:firin_defter/features/debt_expense/screens/debt_expense_list_tab.dart';
import 'package:firin_defter/features/messaging/providers/messaging_providers.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/settings/screens/settings_screen.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/models/feature_lock.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:firin_defter/features/subscriptions/screens/plans_screen.dart';
import 'package:firin_defter/features/subscriptions/widgets/paywall_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FixedProfile extends ProfileController {
  _FixedProfile(super.ref, AccountType account) {
    state = BakeryProfile(
      displayName: 'Ayşe Nur Kaya Uzun İsimli Fırıncı',
      accountType: account,
      city: 'İstanbul',
      roleBadge: 'Fırın Sahibi / Usta Başı Ekmek ve Pasta Bölümü',
      email: 't@t.com',
    );
  }
}

String _read(String p) => File(p).readAsStringSync();

Future<void> _setSurface(
  WidgetTester tester, {
  double width = 320,
  double height = 900,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// Taşma (RenderFlex overflow) hatalarını toplar; başka hatalar aynen fırlar.
List<FlutterErrorDetails> _captureOverflows() {
  final overflows = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      overflows.add(details);
    } else {
      previous?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
  return overflows;
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('Onay dialogları — ortak showAppConfirmDialog', () {
    testWidgets('kaydedilmemiş değişiklik: Vazgeç + "Değişiklikleri sil"', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold();
            },
          ),
        ),
      );
      final result = showDiscardChangesDialog(ctx);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app_confirm_dialog')), findsOneWidget);
      expect(find.text(AppStrings.polishDiscardTitle), findsOneWidget);
      expect(find.text('Vazgeç'), findsOneWidget);
      expect(find.text('Değişiklikleri sil'), findsOneWidget);
      expect(find.text('Tamam'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('app_confirm_cancel')));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('Ayarlar → Çıkış yap onay ister; Vazgeç oturumu korur', (
      tester,
    ) async {
      await _setSurface(tester, width: 600, height: 2400);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsScreen())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.settingsSignOut));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app_confirm_dialog')), findsOneWidget);
      expect(find.text(AppStrings.polishSignOutTitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('app_confirm_ok')),
          matching: find.text(AppStrings.polishSignOutCta),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('app_confirm_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app_confirm_dialog')), findsNothing);
      // Hâlâ Ayarlar'dayız.
      expect(find.text(AppStrings.settingsTitle), findsOneWidget);
    });

    testWidgets(
      'Borç/Gider kaydı silme: yıkıcı onay → "Kayıt silindi" geri bildirimi',
      (tester) async {
        await _setSurface(tester, width: 400, height: 900);
        final repo = LocalDebtExpenseRepository();
        await repo.addEntry(
          DebtExpenseEntry(
            id: '',
            kind: DebtExpenseKind.expense,
            title: 'Elektrik faturası',
            totalAmount: 1200,
            createdAt: DateTime(2026, 9, 1),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [debtExpenseRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: DebtExpenseListTab(kind: DebtExpenseKind.expense),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elektrik faturası'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.polishDelete));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('app_confirm_dialog')),
          findsOneWidget,
        );
        expect(find.text(AppStrings.polishDebtDeleteTitle), findsOneWidget);
        expect(find.text('Vazgeç'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('app_confirm_ok')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('app_feedback_success')),
          findsOneWidget,
        );
        expect(find.text(AppStrings.polishDebtDeleted), findsOneWidget);
        expect(await repo.listEntries(), isEmpty);
      },
    );

    test('kapsamdaki onaylar ortak dialogu kullanır (kaynak sözleşmesi)', () {
      const files = <String>[
        'lib/core/widgets/dirty_form_guard.dart',
        'lib/features/bakery_panel/screens/recipe_detail_screen.dart',
        'lib/features/branches/screens/branch_detail_screen.dart',
        'lib/features/b2b_market/screens/buyer/buyer_quote_detail_screen.dart',
        'lib/features/dealers/screens/dealer_detail_screen.dart',
        'lib/features/dealers/screens/dealer_transaction_history_screen.dart',
        'lib/features/debt_expense/screens/debt_expense_list_tab.dart',
        'lib/features/safety/widgets/block_user_dialog.dart',
        'lib/features/settings/screens/settings_screen.dart',
        'lib/features/worker/screens/worker_experiences_screen.dart',
      ];
      for (final f in files) {
        final src = _read(f);
        expect(src.contains('showAppConfirmDialog('), isTrue, reason: f);
        expect(src.contains('AlertDialog('), isFalse, reason: f);
      }
    });

    test('hesap silme: anahtar kelime adımı korunur, butonlar ortak dilde', () {
      final src = _read('lib/features/auth/services/auth_actions.dart');
      expect(src.contains('accountDeleteConfirmKeyword'), isTrue);
      expect(src.contains('AppButtonStyles.destructive'), isTrue);
      expect(src.contains("ValueKey('delete_account_cancel')"), isTrue);
    });
  });

  group('AppFeedback — temsilî akışlar', () {
    test('B2B ürün/kampanya/mağaza/teklif + reçete + bayi hareketi', () {
      const files = <String>[
        'lib/features/b2b_market/screens/supplier/forms/supplier_product_form_screen.dart',
        'lib/features/b2b_market/screens/supplier/forms/supplier_campaign_form_screen.dart',
        'lib/features/b2b_market/screens/supplier/forms/supplier_store_edit_screen.dart',
        'lib/features/b2b_market/widgets/b2b_offer_bottom_sheet.dart',
        'lib/features/bakery_panel/screens/recipe_detail_screen.dart',
        'lib/features/dealers/screens/dealer_transaction_history_screen.dart',
        'lib/features/safety/widgets/block_user_dialog.dart',
      ];
      for (final f in files) {
        final src = _read(f);
        expect(src.contains('AppFeedback.'), isTrue, reason: f);
        expect(src.contains('ScaffoldMessenger.of'), isFalse, reason: f);
      }
    });

    test('genel "İşlem başarısız" / "Tekrar deneyin" metinleri kalmadı', () {
      const files = <String>[
        'lib/features/b2b_market/screens/buyer/buyer_quote_detail_screen.dart',
        'lib/features/dealers/screens/driver_home_screen.dart',
        'lib/features/dealers/screens/dealer_transaction_history_screen.dart',
        'lib/features/dealers/screens/driver_assign_dealers_screen.dart',
      ];
      for (final f in files) {
        final src = _read(f);
        expect(src.contains('İşlem başarısız'), isFalse, reason: f);
        expect(src.contains('Tekrar deneyin'), isFalse, reason: f);
      }
    });
  });

  group('Dar ekran + büyük yazı — taşma yok', () {
    for (final scale in const [1.0, 1.3, 1.5]) {
      testWidgets('Panel (ticari) 320px · ${scale}x', (tester) async {
        await _setSurface(tester, textScale: scale, height: 2400);
        final overflows = _captureOverflows();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              branchRepositoryProvider.overrideWithValue(
                LocalBranchRepository(),
              ),
              profileControllerProvider.overrideWith(
                (ref) => _FixedProfile(ref, AccountType.commercial),
              ),
              totalUnreadMessagesProvider.overrideWith((ref) => 3),
              subscriptionRepositoryProvider.overrideWithValue(
                LocalSubscriptionRepository(plan: BusinessPlan.free),
              ),
            ],
            child: const MaterialApp(home: RoleDashboardScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RoleDashboardScreen), findsOneWidget);
        expect(overflows, isEmpty);
      });

      testWidgets('Paketler 320px · ${scale}x', (tester) async {
        await _setSurface(tester, textScale: scale, height: 2400);
        final overflows = _captureOverflows();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileControllerProvider.overrideWith(
                (ref) => _FixedProfile(ref, AccountType.commercial),
              ),
              subscriptionRepositoryProvider.overrideWithValue(
                LocalSubscriptionRepository(plan: BusinessPlan.free),
              ),
            ],
            child: const MaterialApp(home: PlansScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('plan_tile_premium')), findsOneWidget);
        expect(overflows, isEmpty);
      });

      testWidgets('Ayarlar 320px · ${scale}x', (tester) async {
        await _setSurface(tester, textScale: scale, height: 3200);
        final overflows = _captureOverflows();
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: SettingsScreen())),
        );
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.settingsSignOut), findsOneWidget);
        expect(overflows, isEmpty);
      });
    }

    testWidgets('Paywall sheet 320px · 1.5x', (tester) async {
      await _setSurface(tester, textScale: 1.5, height: 640);
      final overflows = _captureOverflows();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(
              LocalSubscriptionRepository(
                plan: BusinessPlan.free,
                launchPriceUntil: DateTime.parse('2027-10-01T00:00:00+03:00'),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showPaywallSheet(context, FeatureLock.dealerBook),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paywall_sheet')), findsOneWidget);
      expect(find.byKey(const ValueKey('paywall_not_now')), findsOneWidget);
      expect(overflows, isEmpty);
    });
  });
}
