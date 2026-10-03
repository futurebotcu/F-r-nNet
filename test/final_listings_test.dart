// Final ilanlar/ödeme cilası — widget testleri.
//
//   * Market kartı / iş kartı / market detay / iş detay / formlar / Paketler /
//     satın alma aksiyonları / hızlı tahsilat: 320/360/390/430 genişlik ×
//     1.0/1.3/1.5 yazı ölçeğinde taşma yok.
//   * Hızlı tahsilat sheet'i klavye inset'i (300px) ile taşmaz; onay tuşu
//     görünür ve dokunulabilir.
//   * Tam ekran galeri yükleniyor durumu koyu yüzey kullanır (açık gri yok).
//   * Ürün kartında sakin "İncele" ipucu var.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/app_network_image.dart';
import 'package:firin_defter/core/widgets/listing_phone_cta.dart';
import 'package:firin_defter/core/widgets/premium/job_opportunity_card.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/widgets/quick_payment_sheet.dart';
import 'package:firin_defter/features/jobs/screens/job_offer_form_screen.dart';
import 'package:firin_defter/features/jobs/screens/jobs_screen.dart';
import 'package:firin_defter/features/marketplace/models/market_listing.dart';
import 'package:firin_defter/features/marketplace/providers/market_listing_providers.dart';
import 'package:firin_defter/features/marketplace/repositories/local_market_listing_repository.dart';
import 'package:firin_defter/features/marketplace/screens/market_listing_form_screen.dart';
import 'package:firin_defter/features/marketplace/screens/marketplace_detail_screen.dart';
import 'package:firin_defter/features/marketplace/widgets/marketplace_listing_card.dart';
import 'package:firin_defter/features/payments/data/fake_payment_service.dart';
import 'package:firin_defter/features/payments/providers/payment_providers.dart';
import 'package:firin_defter/features/payments/widgets/plan_purchase_actions.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:firin_defter/features/subscriptions/screens/plans_screen.dart';
import 'package:firin_defter/features/worker/screens/job_seek_post_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _widths = <double>[320, 360, 390, 430];
const _scales = <double>[1.0, 1.3, 1.5];

const _longTitle =
    'Çok uzun bir ilan başlığı: Taş fırın ustası ve hamur ustası aranıyor, '
    'gece vardiyası, sigortalı, yemek ve yol dahil, hemen başlanacak';
const _longCity = 'Afyonkarahisar';
const _longDistrict = 'Sandıklı Merkez Mahallesi Çok Uzun İlçe Adı';
const _longOwner =
    'Kahramanmaraş Geleneksel Taş Fırın ve Unlu Mamuller Sanayi Ticaret Ltd';

class _SeededProfile extends ProfileController {
  _SeededProfile(super.ref, AccountType account) {
    state = BakeryProfile(
      displayName: 'Ayşe Nur Kaya Uzun İsimli Fırıncı',
      accountType: account,
      city: 'Konya',
      roleBadge: 'Fırıncı',
      email: 't@t.com',
    );
  }
}

class _FixedMarketRepo extends LocalMarketListingRepository {
  _FixedMarketRepo(this.existing);
  final MarketListing? existing;

  @override
  Future<MarketListing?> getListing(String id) async => existing;
}

MarketListing _longListing({String type = 'bakery_transfer'}) => MarketListing(
  id: 'm1',
  ownerId: 'owner-1',
  title: _longTitle,
  category: type == 'bakery_transfer' ? 'devren_firin' : 'ekipman',
  listingType: type,
  city: _longCity,
  district: _longDistrict,
  price: type == 'bakery_transfer' ? null : 1250000,
  unit: type == 'bakery_transfer' ? null : 'adet',
  transferPrice: type == 'bakery_transfer' ? 12500000 : null,
  rentPrice: type == 'bakery_transfer' ? 85000 : null,
  negotiable: true,
  areaM2: 240,
  hasLicense: true,
  description: 'Açıklama ' * 40,
  authorName: _longOwner,
  contactPreference: 'phone',
  contactPhone: '05321234567',
  contactWhatsapp: '05321234567',
  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
);

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required double width,
  required double scale,
  double height = 900,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp(
        builder: (ctx, w) => MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: w!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _scroll(Widget child) => Scaffold(
  body: SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: child,
  ),
);

Future<LocalDealerRepository> _dealerRepo() async {
  final repo = LocalDealerRepository(seed: false);
  await repo.upsertDealer(
    Dealer(id: 'd1', name: _longOwner, createdAt: DateTime(2026, 1, 1)),
  );
  return repo;
}

Widget _quickPayHost() => Scaffold(
  body: Builder(
    builder: (context) => Center(
      child: ElevatedButton(
        child: const Text('open'),
        onPressed: () => QuickPaymentSheet.show(
          context: context,
          dealerId: 'd1',
          dealerName: _longOwner,
          currentBalance: 1234567.89,
        ),
      ),
    ),
  ),
);

void main() {
  for (final w in _widths) {
    for (final s in _scales) {
      group('${w.toInt()}px × ${s}x', () {
        testWidgets('market kartı (fırın devri + ekipman)', (tester) async {
          await _pump(
            tester,
            _scroll(
              Column(
                children: [
                  MarketplaceListingCard(
                    listing: _longListing(),
                    onTap: () {},
                    onToggleSave: () {},
                  ),
                  MarketplaceListingCard(
                    listing: _longListing(type: 'equipment_sale'),
                    onTap: () {},
                    onToggleSave: () {},
                  ),
                ],
              ),
            ),
            width: w,
            scale: s,
            height: 2000,
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('market_card_cta')),
            findsNWidgets(2),
          );
        });

        testWidgets('iş kartı (personel aranıyor + iş arıyor)', (tester) async {
          await _pump(
            tester,
            _scroll(
              Column(
                children: [
                  JobOpportunityCard(
                    kind: JobListingKind.hiring,
                    title: _longTitle,
                    keyFact: '₺ 125.000 – 180.000',
                    location: '$_longCity · $_longDistrict',
                    owner: _longOwner,
                    timeLabel: '12 dk önce',
                    tags: const ['Tecrübe şartı aranmaz', 'Vardiyalı (gece)'],
                    onMore: () {},
                    onApply: () {},
                    applyLabel: offerPrimaryCtaLabel,
                    secondaryAction: const ListingPhoneCta(
                      phone: '05321234567',
                      compact: true,
                    ),
                  ),
                  JobOpportunityCard(
                    kind: JobListingKind.seeking,
                    title: _longTitle,
                    keyFact: AppStrings.listingsSalaryNegotiable,
                    location: _longCity,
                    timeLabel: '3 gün önce',
                    tags: const ['Usta Fırıncı', '12 yıl'],
                    onApply: () {},
                    applyLabel: seekPrimaryCtaLabel,
                    applyIcon: Icons.chat_bubble_outline_rounded,
                  ),
                ],
              ),
            ),
            width: w,
            scale: s,
            height: 2000,
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('job_badge_hiring')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('job_badge_seeking')),
            findsOneWidget,
          );
        });

        testWidgets('market detay (ziyaretçi)', (tester) async {
          await _pump(
            tester,
            const MarketplaceDetailScreen(listingId: 'm1'),
            width: w,
            scale: s,
            overrides: [
              currentAuthUserProvider.overrideWith((_) => null),
              marketListingRepositoryProvider.overrideWith(
                (ref) => _FixedMarketRepo(_longListing()),
              ),
            ],
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('market_detail_primary')),
            findsOneWidget,
          );
        });

        testWidgets('iş ilanı detay', (tester) async {
          await _pump(
            tester,
            Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: JobListingDetailView(
                  kind: JobListingKind.hiring,
                  title: _longTitle,
                  keyFact: '₺ 125.000 – 180.000',
                  location: '$_longCity · $_longDistrict',
                  ownerName: _longOwner,
                  rows: const [
                    MapEntry(AppStrings.listingsDetailRole, 'Usta Fırıncı'),
                    MapEntry(AppStrings.listingsDetailShift, '—'),
                  ],
                  description: 'Açıklama ' * 30,
                  createdAt: DateTime(2026, 9, 1),
                  primaryLabel: offerPrimaryCtaLabel,
                  onPrimary: () {},
                  phone: '05321234567',
                ),
              ),
            ),
            width: w,
            scale: s,
          );
          expect(tester.takeException(), isNull);
          // Anlamsız satır ("—") çizilmez.
          expect(find.text('—'), findsNothing);
          expect(
            find.byKey(const ValueKey('job_detail_primary')),
            findsOneWidget,
          );
        });

        testWidgets('formlar (market + personel + iş arıyorum)', (
          tester,
        ) async {
          await _pump(
            tester,
            const MarketListingFormScreen(initialListingType: 'equipment_sale'),
            width: w,
            scale: s,
            overrides: [
              profileControllerProvider.overrideWith(
                (ref) => _SeededProfile(ref, AccountType.individual),
              ),
              marketListingRepositoryProvider.overrideWith(
                (ref) => _FixedMarketRepo(null),
              ),
            ],
          );
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('market_form_submit')), findsOne);

          await _pump(
            tester,
            const JobOfferFormScreen(),
            width: w,
            scale: s,
            overrides: [
              profileControllerProvider.overrideWith(
                (ref) => _SeededProfile(ref, AccountType.commercial),
              ),
              currentAuthUserProvider.overrideWith((_) => null),
            ],
          );
          expect(tester.takeException(), isNull);

          await _pump(
            tester,
            const JobSeekPostFormScreen(),
            width: w,
            scale: s,
            overrides: [
              profileControllerProvider.overrideWith(
                (ref) => _SeededProfile(ref, AccountType.individual),
              ),
            ],
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('Paketler + satın alma aksiyonları', (tester) async {
          await _pump(
            tester,
            const PlansScreen(),
            width: w,
            scale: s,
            height: 2600,
            overrides: [
              profileControllerProvider.overrideWith(
                (ref) => _SeededProfile(ref, AccountType.commercial),
              ),
              subscriptionRepositoryProvider.overrideWithValue(
                LocalSubscriptionRepository(plan: BusinessPlan.free),
              ),
            ],
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('plans_legal_links')), findsOne);
          expect(find.text(AppStrings.legalTermsTitle), findsOneWidget);
          expect(find.text(AppStrings.legalPrivacyTitle), findsOneWidget);

          await _pump(
            tester,
            const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: PlanPurchaseActions(account: AccountType.commercial),
              ),
            ),
            width: w,
            scale: s,
            overrides: [
              currentAuthUserProvider.overrideWithValue(
                const AuthUser(id: 'u1', email: 'u@test.local'),
              ),
              paymentServiceProvider.overrideWithValue(
                FakePaymentService(available: true),
              ),
            ],
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('buy_premium_yearly')), findsOne);
          expect(find.byKey(const ValueKey('restore_purchases')), findsOne);
        });

        testWidgets('hızlı tahsilat sheet', (tester) async {
          final repo = await _dealerRepo();
          await _pump(
            tester,
            _quickPayHost(),
            width: w,
            scale: s,
            height: 760,
            overrides: [
              dealerRepositoryProvider.overrideWithValue(repo),
              profileControllerProvider.overrideWith(
                (ref) => _SeededProfile(ref, AccountType.commercial),
              ),
            ],
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('quick_payment_sheet')), findsOne);
        });
      });
    }
  }

  group('Hızlı tahsilat — klavye inset', () {
    for (final s in _scales) {
      testWidgets('viewInsets 300 → taşma yok, onay tuşu görünür @${s}x', (
        tester,
      ) async {
        final repo = await _dealerRepo();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await _pump(
          tester,
          _quickPayHost(),
          width: 320,
          scale: s,
          height: 800,
          overrides: [
            dealerRepositoryProvider.overrideWithValue(repo),
            profileControllerProvider.overrideWith(
              (ref) => _SeededProfile(ref, AccountType.commercial),
            ),
          ],
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final sheet = find.byKey(const ValueKey('quick_payment_sheet'));
        expect(sheet, findsOneWidget);
        // Sheet klavyenin üstünde kalır.
        expect(tester.getRect(sheet).bottom, lessThanOrEqualTo(800 - 300 + 1));
        final submit = find.byKey(const Key('cashier.calculator.submit'));
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        expect(submit.hitTestable(), findsOneWidget);
        final r = tester.getRect(submit);
        expect(r.top, lessThan(800 - 300));
      });
    }
  });

  group('Tam ekran galeri', () {
    testWidgets('yükleniyor durumu koyu yüzey + küçük gösterge', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: AppImageState.loading(dark: true),
            ),
          ),
        ),
      );
      final state = find.byKey(const ValueKey('app_image_loading_dark'));
      expect(state, findsOneWidget);
      final box = tester.widget<Container>(
        find.descendant(of: state, matching: find.byType(Container)).first,
      );
      expect(box.color, AppImageState.darkSurface);
      expect(box.color, isNot(AppImageState.surface));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hata durumu koyu zeminde açık etiket', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: AppImageState.error(
                label: 'Görsel yüklenemedi',
                dark: true,
              ),
            ),
          ),
        ),
      );
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('app_image_error')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(box.color, AppImageState.darkSurface);
      expect(find.text('Görsel yüklenemedi'), findsOneWidget);
    });

    test('galeri tam ekranı koyu yüzeyi kullanır (kaynak sözleşmesi)', () {
      final src = File(
        'lib/features/marketplace/widgets/marketplace_image_gallery.dart',
      ).readAsStringSync();
      expect(
        src.contains('backgroundColor: AppImageState.darkSurface'),
        isTrue,
      );
      expect(src.contains('dark: true'), isTrue);
    });
  });
}
