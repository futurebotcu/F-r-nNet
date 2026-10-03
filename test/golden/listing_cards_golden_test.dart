// Görsel QA — ilan kartları (personel arıyor / iş arıyor / görselli-görselsiz
// market). Windows'ta üretilen baseline; CI 'golden' tag'ini hariç tutar.
@Tags(['golden'])
library;

import 'package:firin_defter/app/theme/app_theme.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/premium/job_opportunity_card.dart';
import 'package:firin_defter/features/marketplace/models/market_listing.dart';
import 'package:firin_defter/features/marketplace/widgets/marketplace_listing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _loadGoldenFont() async {
  final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
  final materialIcons = await rootBundle.load(
    'fonts/MaterialIcons-Regular.otf',
  );
  await Future.wait(<Future<void>>[
    (FontLoader('Inter')
          ..addFont(Future<ByteData>.value(regular))
          ..addFont(Future<ByteData>.value(bold)))
        .load(),
    (FontLoader('Ahem')
          ..addFont(Future<ByteData>.value(regular))
          ..addFont(Future<ByteData>.value(bold)))
        .load(),
    (FontLoader('Roboto')
          ..addFont(Future<ByteData>.value(regular))
          ..addFont(Future<ByteData>.value(bold)))
        .load(),
    (FontLoader(
      'MaterialIcons',
    )..addFont(Future<ByteData>.value(materialIcons))).load(),
  ]);
}

void main() {
  testWidgets('ilan kartları görsel baseline', (tester) async {
    await _loadGoldenFont();
    await initializeDateFormatting('tr_TR');
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        home: RepaintBoundary(
          key: const Key('cards'),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  JobOpportunityCard(
                    kind: JobListingKind.hiring,
                    title: 'Gece vardiyası için hamur ustası aranıyor',
                    keyFact: '₺ 35.000 – 42.000',
                    location: 'İzmir · Bornova',
                    owner: 'Ege Taş Fırın',
                    timeLabel: '12 dk önce',
                    tags: const ['Gece vardiyası', '3+ yıl tecrübe'],
                    onApply: () {},
                    applyLabel: AppStrings.jobsApply,
                    onMore: () {},
                  ),
                  const SizedBox(height: 12),
                  JobOpportunityCard(
                    kind: JobListingKind.seeking,
                    title: "İzmir'de iş arayan pişirici usta",
                    keyFact: AppStrings.listingsSalaryNegotiable,
                    location: 'İzmir',
                    owner: 'Pişirici usta',
                    timeLabel: 'dün',
                    tags: const ['8 yıl tecrübe'],
                    onApply: () {},
                    applyLabel: AppStrings.jobsApply,
                    onMore: () {},
                  ),
                  const SizedBox(height: 12),
                  MarketplaceListingCard(
                    listing: MarketListing(
                      id: 'm1',
                      ownerId: 'u1',
                      title: '2. el spiral mikser 120 kg',
                      category: 'ekipman',
                      listingType: 'equipment_sale',
                      city: 'Konya',
                      district: 'Selçuklu',
                      price: 145000,
                      negotiable: true,
                      authorName: 'Anadolu Fırın Ekipman',
                      createdAt: now.subtract(const Duration(days: 3)),
                    ),
                    onTap: () {},
                    onToggleSave: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('cards')),
      matchesGoldenFile('goldens/listing_cards.png'),
    );
  });
}
