// S3 ekranları — küçük Android (320px) + büyük yazı (1.0/1.3/1.5x) taşma testi.
// Alıcı ve tedarikçi görünümleri ayrı ayrı.

import 'package:firin_defter/features/b2b_market/models/b2b_store.dart';
import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/screens/b2b_shell_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/detail/b2b_store_detail_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/forms/supplier_campaign_form_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/forms/supplier_product_form_screen.dart';
import 'package:firin_defter/features/b2b_market/screens/supplier/forms/supplier_store_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _ContactRepo extends LocalB2bRepository {
  @override
  Future<B2bStore?> storeById(String id) async {
    final s = await super.storeById(id);
    if (s == null) return null;
    return B2bStore(
      id: s.id,
      name: 'Çok Uzun Adlı Anadolu Un ve Maya Toptan Ticaret Limited Şirketi',
      monogram: s.monogram,
      tagline: s.tagline,
      description: s.description,
      categories: s.categories,
      serviceRegions: s.serviceRegions,
      productCount: s.productCount,
      campaignCount: s.campaignCount,
      phone: '0532 000 00 00',
      whatsapp: '0532 000 00 00',
      website: 'www.cok-uzun-bir-alan-adi-anadolu-un-maya.com.tr',
      address:
          'Konya Organize Sanayi Bölgesi, 3. Cadde No: 12, Selçuklu / Konya',
    );
  }
}

Future<void> _surface(WidgetTester t, double scale) async {
  t.view.physicalSize = const Size(320, 3200);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearAllTestValues);
}

List<String> _captureOverflows() {
  final out = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (d) {
    final text = d.exceptionAsString();
    if (text.contains('overflowed')) {
      final s = d.toString();
      final i = s.indexOf('The relevant error-causing widget was');
      out.add(i >= 0 ? s.substring(i, (i + 200).clamp(0, s.length)) : text);
    } else {
      debugPrint('[test] non-overflow error: $text');
      previous?.call(d);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
  return out;
}

Widget _app(
  Widget home, {
  B2bRole role = B2bRole.supplier,
  LocalB2bRepository? repo,
}) => ProviderScope(
  overrides: [
    b2bRoleOverrideProvider.overrideWith((ref) => role),
    b2bRepositoryProvider.overrideWithValue(repo ?? LocalB2bRepository()),
  ],
  child: MaterialApp(home: home),
);

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  final screens = <String, Widget Function()>{
    'tedarikçi · mağaza düzenle (iletişim)': () =>
        _app(const SupplierStoreEditScreen()),
    'tedarikçi · kampanya formu (ürün seçici)': () =>
        _app(const SupplierCampaignFormScreen()),
    'tedarikçi · ürün formu': () => _app(const SupplierProductFormScreen()),
    'tedarikçi · Pazar > Talepler': () =>
        _app(const B2bShellScreen(initialTab: 'talepler')),
    'tedarikçi · Pazar > Mağazam': () =>
        _app(const B2bShellScreen(initialTab: 'magazam')),
    'alıcı · mağaza detayı (iletişim butonları)': () => _app(
      const B2bStoreDetailScreen(storeId: 's1'),
      role: B2bRole.buyer,
      repo: _ContactRepo(),
    ),
    'alıcı · Pazar > Tekliflerim': () => _app(
      const B2bShellScreen(initialTab: 'tekliflerim'),
      role: B2bRole.buyer,
    ),
  };

  for (final scale in const [1.0, 1.3, 1.5]) {
    screens.forEach((name, build) {
      testWidgets('320px · ${scale}x — $name', (t) async {
        await _surface(t, scale);
        final overflows = _captureOverflows();
        await t.pumpWidget(build());
        await t.pumpAndSettle();
        expect(overflows, isEmpty, reason: overflows.join('\n'));
      });
    });
  }
}
