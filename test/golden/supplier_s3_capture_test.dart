// S3 — görsel çıktılar (PNG → docs/audits/s3). Golden karşılaştırması yok;
// CI 'golden' tag'ini hariç tutar. Yerelde:
//   flutter test test/golden/supplier_s3_capture_test.dart
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:firin_defter/app/theme/app_theme.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_replied_request.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_store.dart';
import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/screens/detail/b2b_store_detail_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/forms/supplier_campaign_form_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/forms/supplier_store_edit_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/supplier_requests_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _captureKey = Key('s3-capture');
const _outDir = 'docs/audits/s3';

/// Başka tedarikçinin iletişimli mağazası (alıcı görünümü).
class _ContactRepo extends LocalB2bRepository {
  @override
  Future<B2bStore?> storeById(String id) async {
    final s = await super.storeById(id);
    if (s == null) return null;
    return B2bStore(
      id: s.id,
      name: s.name,
      monogram: s.monogram,
      tagline: s.tagline,
      description: s.description,
      categories: s.categories,
      serviceRegions: s.serviceRegions,
      productCount: s.productCount,
      campaignCount: s.campaignCount,
      isMine: false,
      logoUrl: s.logoUrl,
      coverUrl: s.coverUrl,
      phone: '0532 000 00 00',
      whatsapp: '0532 000 00 00',
      website: 'www.anadoluun.com.tr',
      address: 'Konya OSB, 3. Cadde No: 12',
    );
  }
}

/// Küçük sayfa → "Daha fazla yükle".
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
}

Future<void> _loadFonts() async {
  final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
  final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
  for (final family in const ['Inter', 'Ahem', 'Roboto']) {
    await (FontLoader(family)
          ..addFont(Future<ByteData>.value(regular))
          ..addFont(Future<ByteData>.value(bold)))
        .load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future<ByteData>.value(icons))).load();
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(390, 1400),
  LocalB2bRepository? repo,
  B2bRole role = B2bRole.supplier,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        b2bRoleOverrideProvider.overrideWith((ref) => role),
        b2bRepositoryProvider.overrideWithValue(repo ?? LocalB2bRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: RepaintBoundary(key: _captureKey, child: home),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await _loadFonts();
  });

  testWidgets('S3 mağaza detayı — alıcı görünümü, iletişim aksiyonları', (
    tester,
  ) async {
    await _pump(
      tester,
      const B2bStoreDetailScreen(storeId: 's1'),
      repo: _ContactRepo(),
      role: B2bRole.buyer,
      size: const Size(390, 1500),
    );
    await _save(tester, 'store_detail_contact_390');
  });

  testWidgets('S3 mağaza düzenle — iletişim alanları', (tester) async {
    await _pump(
      tester,
      const SupplierStoreEditScreen(),
      size: const Size(390, 1900),
    );
    await _save(tester, 'store_edit_contact_390');
  });

  testWidgets('S3 kampanya formu — ürün seçici', (tester) async {
    await _pump(
      tester,
      const SupplierCampaignFormScreen(),
      size: const Size(390, 1700),
    );
    await _save(tester, 'campaign_form_product_picker_390');
  });

  testWidgets('S3 Talepler — Daha fazla yükle', (tester) async {
    await _pump(
      tester,
      const Scaffold(body: SupplierRequestsTab()),
      repo: _SmallPageRepo(),
      size: const Size(390, 1200),
    );
    await _save(tester, 'requests_load_more_390');
  });

  testWidgets('S3 Talepler — Yanıtladıklarım (geçmiş RPC ile tam bağlam)', (
    tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(body: SupplierRequestsTab()),
      size: const Size(390, 1000),
    );
    final f = find.byKey(const ValueKey('sup_req_seg_replied'));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
    await _save(tester, 'requests_replied_history_390');
  });
}
