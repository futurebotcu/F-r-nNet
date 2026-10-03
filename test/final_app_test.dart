// Final uygulama turu — hitap birliği, bağlamlı hata metinleri, dar ekran.
//
// Kapsam:
//   1. app_strings.dart'ta resmî "siz" kalıpları ("deneyin", "ediniz",
//      "giriniz") kalmadı (yasal metin sabitleri hariç).
//   2. Auth hata çevirici bilinmeyen hatada bağlamlı kısa metin döner; ham
//      backend mesajı ve "Beklenmeyen" genel metni kullanıcıya gitmez.
//   3. Panel / Ayarlar / Giriş / B2B liste / Bayi listesi 320-430px
//      genişlikte 1.0/1.3/1.5 yazı ölçeğinde taşmadan çizilir.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/screens/auth_entry_screen.dart';
import 'package:firin_defter/features/auth/utils/auth_error_translator.dart';
import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/screens/b2b_shell_screen.dart';
import 'package:firin_defter/features/branches/providers/branch_providers.dart';
import 'package:firin_defter/features/branches/repositories/local_branch_repository.dart';
import 'package:firin_defter/features/dashboard/screens/role_dashboard_screen.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_list_screen.dart';
import 'package:firin_defter/features/messaging/providers/messaging_providers.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/settings/screens/settings_screen.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

Future<void> _setSurface(
  WidgetTester tester, {
  required double width,
  required double textScale,
  double height = 2400,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// Çizim sırasında oluşan TÜM Flutter hatalarını (taşma dahil) toplar; test
/// sonunda liste boş olmalı. Hata metni `reason` olarak raporlanır.
void Function(FlutterErrorDetails)? _previousHandler;

List<String> _captureOverflows() {
  final errors = <String>[];
  _previousHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString().split('\n').first);
  };
  return errors;
}

/// Önce orijinal hata işleyicisini geri yükler (yoksa başarısız expect test
/// bağlayıcısını kilitler), sonra hata listesinin boş olduğunu doğrular.
void _expectNoErrors(List<String> errors) {
  FlutterError.onError = _previousHandler;
  expect(errors, isEmpty, reason: errors.join(' | '));
}

Future<LocalDealerRepository> _dealerRepo() async {
  final repo = LocalDealerRepository(seed: false);
  await repo.upsertDealer(
    Dealer(
      id: 'd1',
      name: 'Hamdi Bakkal ve Şarküteri Uzun İsimli Bayi',
      area: 'Kadıköy Merkez Mahallesi',
      createdAt: DateTime(2026, 1, 1),
    ),
  );
  await repo.upsertDealer(
    Dealer(
      id: 'd2',
      name: 'Köşe Pide',
      isActive: false,
      createdAt: DateTime(2026, 1, 1),
    ),
  );
  await repo.addTransaction(
    DealerTransaction(
      id: 't1',
      dealerId: 'd1',
      type: DealerTransactionType.delivery,
      amount: 1234567,
      createdAt: DateTime(2026, 5, 1),
    ),
  );
  return repo;
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('Hitap birliği — "sen" dili', () {
    test('app_strings.dart: resmî "deneyin/ediniz/giriniz" kalmadı', () {
      final lines = File(
        'lib/core/constants/app_strings.dart',
      ).readAsLinesSync();
      // Yasal metinler (gizlilik/koşullar) resmî kalabilir.
      final legal = RegExp(
        r'\b(legal|privacy|terms|kvkk)\w*\s*=',
        caseSensitive: false,
      );
      final formal = RegExp(r'(deneyin|ediniz|giriniz|seçiniz|yapınız)');
      final hits = <String>[];
      for (final l in lines) {
        if (l.trimLeft().startsWith('//')) continue;
        if (legal.hasMatch(l)) continue;
        if (formal.hasMatch(l)) hits.add(l.trim());
      }
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    test('dönüştürülen örnek metinler "sen" dilinde', () {
      expect(AppStrings.branchInviteFnIdRequired, contains('kontrol et.'));
      expect(AppStrings.partnersApplySuccess, contains('seninle'));
      expect(AppStrings.supplierLaunchGiftAssurance, startsWith('Onayın '));
      expect(AppStrings.supportContactSection, 'Bize ulaş');
    });
  });

  group('Auth hata çevirici — bağlamlı metin', () {
    test('bilinmeyen hata → "Giriş yapılamadı…" (Beklenmeyen yok)', () {
      final out = translateAuthError(Exception('boom'));
      expect(out, AppStrings.finalAuthErrorGeneric);
      expect(out, isNot(contains('Beklenmeyen')));
      expect(out, startsWith('Giriş yapılamadı'));
    });

    test('tanınmayan AuthApiException ham backend mesajı sızdırmaz', () {
      final out = translateAuthError(
        AuthApiException('some_internal_backend_error xyz', code: 'weird'),
      );
      expect(out, AppStrings.finalAuthErrorGeneric);
      expect(out, isNot(contains('xyz')));
      expect(out, isNot(contains('Sunucu hatası:')));
    });

    test('genel AuthException ham İngilizce mesaj göstermez', () {
      final out = translateAuthError(
        const AuthException('Auth session missing!'),
      );
      expect(out, isNot(contains('session')));
      expect(out, AppStrings.finalAuthErrorGeneric);
    });

    test('bağlantı hatası özel metni korunur', () {
      expect(
        translateAuthError(Exception('SocketException: Failed host lookup')),
        'İnternet bağlantısı yok. Bağlantını kontrol et.',
      );
    });
  });

  group('Dar ekran + büyük yazı — taşma yok', () {
    for (final width in const [320.0, 360.0, 390.0, 430.0]) {
      for (final scale in const [1.0, 1.3, 1.5]) {
        final tag = '${width.toInt()}px · ${scale}x';

        testWidgets('Panel (ticari) $tag', (tester) async {
          await _setSurface(tester, width: width, textScale: scale);
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
          _expectNoErrors(overflows);
        });

        testWidgets('Ayarlar $tag', (tester) async {
          await _setSurface(
            tester,
            width: width,
            textScale: scale,
            height: 3200,
          );
          final overflows = _captureOverflows();
          await tester.pumpWidget(
            const ProviderScope(child: MaterialApp(home: SettingsScreen())),
          );
          await tester.pumpAndSettle();
          expect(find.text(AppStrings.settingsSignOut), findsOneWidget);
          _expectNoErrors(overflows);
        });

        testWidgets('Giriş (AuthEntry) $tag', (tester) async {
          await _setSurface(tester, width: width, textScale: scale);
          final overflows = _captureOverflows();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [authRepositoryProvider.overrideWithValue(null)],
              child: MaterialApp(
                theme: ThemeData(platform: TargetPlatform.android),
                home: const AuthEntryScreen(),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.text(AppStrings.authEntryHeroTitle), findsOneWidget);
          await tester.pump(const Duration(seconds: 4));
          _expectNoErrors(overflows);
        });

        for (final role in const [B2bRole.buyer, B2bRole.supplier]) {
          testWidgets('B2B liste (${role.name}) $tag', (tester) async {
            await _setSurface(tester, width: width, textScale: scale);
            final overflows = _captureOverflows();
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  b2bRoleOverrideProvider.overrideWith((ref) => role),
                ],
                child: const MaterialApp(home: B2bShellScreen()),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            expect(find.byType(B2bShellScreen), findsOneWidget);
            _expectNoErrors(overflows);
          });
        }

        testWidgets('Bayi listesi $tag', (tester) async {
          await _setSurface(tester, width: width, textScale: scale);
          final overflows = _captureOverflows();
          final repo = await _dealerRepo();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                dealerRepositoryProvider.overrideWithValue(repo),
                profileControllerProvider.overrideWith(
                  (ref) => _FixedProfile(ref, AccountType.commercial),
                ),
              ],
              child: MaterialApp.router(
                routerConfig: GoRouter(
                  initialLocation: '/dealers',
                  routes: [
                    GoRoute(
                      path: '/dealers',
                      builder: (_, __) => const DealerListScreen(),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(DealerListScreen), findsOneWidget);
          _expectNoErrors(overflows);
        });
      }
    }
  });
}
