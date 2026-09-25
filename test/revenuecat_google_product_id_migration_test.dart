import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('revenuecat google product id migration contract', () {
    const migration =
        'supabase/migrations/20260927090000_revenuecat_google_product_id_v1.sql';

    test('normalizasyon: ilk \':\' öncesi, mapping ve apply bunu kullanır', () {
      final sql = _read(migration);
      expect(sql.contains('store_normalize_product_id'), isTrue);
      expect(sql.contains("split_part(p_product_id, ':', 1)"), isTrue);
      expect(
        sql.contains(
          'm.product_id = public.store_normalize_product_id(p_product_id)',
        ),
        isTrue,
      );
      expect(
        sql.contains(
          'v_product_id text := public.store_normalize_product_id',
        ),
        isTrue,
      );
    });

    test('legacy id\'ler ve listing fee mapping\'te korunur', () {
      final sql = _read(migration);
      for (final id in [
        'firinnet_premium_monthly',
        'firinnet_premium_yearly',
        'firinnet_bakery_pro_monthly',
        'firinnet_bakery_premium_monthly',
        'firinnet_supplier_pro_monthly',
        'firinnet_supplier_premium_monthly',
      ]) {
        expect(sql.contains("('$id',"), isTrue, reason: id);
      }
      expect(
        sql.contains("('firinnet_listing_fee_50',           null,         "
            "null,      'listing_fee')"),
        isTrue,
      );
    });

    test('tekillik/sıralama: satır anahtarı normalize kimlik', () {
      final sql = _read(migration);
      expect(
        sql.contains('where user_id = p_user_id and product_id = v_product_id'),
        isTrue,
      );
      expect(sql.contains('on conflict (user_id, product_id)'), isTrue);
      expect(sql.contains('s.product_id <> v_product_id'), isTrue);
      // Ham (suffix'li) kimlik satır anahtarı olarak KULLANILMAZ.
      expect(
        sql.contains('and product_id = p_product_id'),
        isFalse,
      );
    });

    test('backfill güvenli: yalnız hedef satır yoksa normalize eder', () {
      final sql = _read(migration);
      expect(sql.contains("position(':' in t.product_id) > 0"), isTrue);
      expect(sql.contains('and not exists'), isTrue);
    });

    test('grant hijyeni: apply yalnız service_role', () {
      final sql = _read(migration);
      expect(
        sql.contains('from public, anon, authenticated'),
        isTrue,
      );
      expect(sql.contains('to service_role'), isTrue);
    });
  });
}
