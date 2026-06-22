// FN-AUDIT-008 — Router root auth guard prefix mantığı.
//
// routeRequiresAuth saf fonksiyon: korumalı (owner/yönetim) prefix'leri auth
// gerektirir; guest/public browse yüzeyleri korunmaz. Yanlış prefix listesi
// guest akışını bozabileceği için davranış burada kilitlenir.

import 'package:firin_defter/app/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('routeRequiresAuth — korumalı yüzeyler', () {
    test('owner/yönetim route\'ları auth gerektirir', () {
      for (final p in [
        '/panel',
        '/panel/bakery',
        '/panel/end-of-day',
        '/dealers',
        '/dealers/drivers',
        '/dealers/assigned/abc',
        '/debt-expense',
        '/pazar/magazam/urun-ekle',
        '/pazar/magazam/kampanya-ekle',
        '/pazar/magazam/duzenle',
        '/wholesale/customers',
      ]) {
        expect(routeRequiresAuth(p), isTrue, reason: '$p korunmalı');
      }
    });
  });

  group('routeRequiresAuth — guest/public browse korunmaz', () {
    test('public/browse + auth/legal route\'ları serbest', () {
      for (final p in [
        '/',
        '/auth',
        '/auth/role-select',
        '/login',
        '/feed',
        '/community',
        '/ilanlar',
        '/pazar', // B2B vitrin (browse) — magazam DEĞİL
        '/pazar/urun/x',
        '/pazar/kampanya/x',
        '/pazar/tedarikciler/x',
        '/pazar/tekliflerim/x',
        '/legal/terms',
        '/legal/privacy',
        '/intro',
        '/u/x',
      ]) {
        expect(routeRequiresAuth(p), isFalse, reason: '$p serbest olmalı');
      }
    });
  });

  group('routeRequiresAuth — sınır davranışı', () {
    test('query string yok sayılır', () {
      expect(
        routeRequiresAuth('/dealers/x/report?period=thisMonth'),
        isTrue,
      );
      expect(routeRequiresAuth('/pazar?seg=urun'), isFalse);
    });

    test('yan-eşleşme yok (prefix sınırı == veya "/")', () {
      expect(routeRequiresAuth('/panelx'), isFalse);
      expect(routeRequiresAuth('/dealersfoo'), isFalse);
      expect(routeRequiresAuth('/pazar/magazamlar'), isFalse);
    });

    test('korumalı prefix listesi beklenen 5 yüzey', () {
      expect(kAuthRequiredPrefixes, containsAll(<String>[
        '/panel',
        '/dealers',
        '/debt-expense',
        '/pazar/magazam',
        '/wholesale',
      ]));
    });
  });
}
