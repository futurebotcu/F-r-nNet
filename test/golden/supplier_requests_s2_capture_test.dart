// S2 — Talepler ekranı görsel çıktıları (PNG → docs/audits/s2). Golden
// karşılaştırması yapmaz; CI 'golden' tag'ini hariç tutar. Yerelde:
//   flutter test test/golden/supplier_requests_s2_capture_test.dart
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:firin_defter/app/theme/app_theme.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_quote_lead.dart';
import 'package:firin_defter/features/b2b_market/models/b2b_quote_reply.dart';
import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/screens/b2b_shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _captureKey = Key('s2-capture');
const _outDir = 'docs/audits/s2';

/// Mock seed + "Kazanılan / İlgilenenler" örnekleri (seed'de lead yok).
class _RichRepo extends LocalB2bRepository {
  @override
  Future<List<B2bQuoteReply>> listMyQuoteReplies() async {
    final base = await super.listMyQuoteReplies();
    return [
      ...base,
      B2bQuoteReply(
        id: 'r_won',
        requestId: 'q_won',
        supplierName: 'Anadolu Un & Maya',
        supplierShopId: 's1',
        message: 'Haftalık 40 koli yaş maya, soğuk zincirle.',
        createdAtLabel: '3 gün önce',
        priceHint: '≈ ₺95 / koli',
        accepted: true,
        status: B2bReplyStatus.accepted,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  @override
  Future<List<B2bQuoteLead>> leadsForMySupplierShop() async => [
    const B2bQuoteLead(
      id: 'l1',
      quoteRequestId: 'q_won',
      quoteReplyId: 'r_won',
      supplierShopId: 's1',
      status: B2bLeadStatus.interested,
      buyerMessage: 'Numune ile başlayalım, uygunsa aylık devam.',
      phoneShared: true,
      sharedPhone: '0532 000 00 00',
      createdAtLabel: '2 gün önce',
      requestCategory: 'Yaş Maya',
      requestQuantity: '40 koli',
      requestCity: 'Kocaeli',
      replyAccepted: true,
    ),
  ];
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

Future<void> _pump(WidgetTester tester, Size size, double textScale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.supplier),
        b2bRepositoryProvider.overrideWithValue(_RichRepo()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const RepaintBoundary(
          key: _captureKey,
          child: B2bShellScreen(initialTab: 'talepler'),
        ),
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

Future<void> _seg(WidgetTester tester, String name) async {
  final f = find.byKey(ValueKey('sup_req_seg_$name'));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await _loadFonts();
  });

  testWidgets('S2 Talepler — Yeni (390x1400)', (tester) async {
    await _pump(tester, const Size(390, 1400), 1.0);
    await _save(tester, 'requests_fresh_390');
  });

  testWidgets('S2 Talepler — Yanıtladıklarım', (tester) async {
    await _pump(tester, const Size(390, 1100), 1.0);
    await _seg(tester, 'replied');
    await _save(tester, 'requests_replied_390');
  });

  testWidgets('S2 Talepler — İlgilenenler', (tester) async {
    await _pump(tester, const Size(390, 900), 1.0);
    await _seg(tester, 'interested');
    await _save(tester, 'requests_interested_390');
  });

  testWidgets('S2 Talepler — Kazanılan', (tester) async {
    await _pump(tester, const Size(390, 900), 1.0);
    await _seg(tester, 'won');
    await _save(tester, 'requests_won_390');
  });

  testWidgets('S2 Talepler — 320px 1.3x Yeni', (tester) async {
    await _pump(tester, const Size(320, 1500), 1.3);
    await _save(tester, 'requests_fresh_320_x1_3');
  });
}
