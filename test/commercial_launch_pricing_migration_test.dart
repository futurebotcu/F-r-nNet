import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('commercial launch pricing migration contract', () {
    const migration =
        'supabase/migrations/20260926090000_commercial_launch_pricing_v1.sql';

    test('lansman başlangıcı uydurulmaz; fiyat dönemi sabit config', () {
      final sql = _read(migration);
      expect(
        sql.contains("('commercial_launch_start', 'null'::jsonb)"),
        isTrue,
      );
      expect(
        sql.contains(
          "('commercial_launch_price_until', "
          '\'"2027-10-01T00:00:00+03:00"\'::jsonb)',
        ),
        isTrue,
      );
      expect(sql.contains('on conflict (key) do nothing'), isTrue);
    });

    test('ücretsiz ay: GREATEST(kayıt, lansman) + 1 Istanbul ayı, otomatik', () {
      final sql = _read(migration);
      expect(sql.contains('greatest(v_created, v_launch)'), isTrue);
      expect(sql.contains("interval '1 month'"), isTrue);
      expect(sql.contains("at time zone 'Europe/Istanbul'"), isTrue);
      expect(sql.contains("p.account_type = 'commercial'"), isTrue);
      expect(sql.contains('is_commercial_launch_free_active'), isTrue);
      // Server saatiyle; bitiş hariç.
      expect(sql.contains('return now() < v_until'), isTrue);
    });

    test('effective sıra: ödenmiş → aktif promo → ücretsiz ay → free', () {
      final sql = _read(migration);
      final body = sql.substring(
        sql.indexOf('current_business_plan'),
      );
      final paidIdx = body.indexOf("in ('premium', 'pro')");
      final promoIdx = body.indexOf("promo_status = 'active'");
      final monthIdx = body.indexOf('is_commercial_launch_free_active(x.id)');
      expect(paidIdx, greaterThanOrEqualTo(0));
      expect(promoIdx, greaterThan(paidIdx));
      expect(monthIdx, greaterThan(promoIdx));
    });

    test('ticari CTA yeni promo vermez; tedarikçi dalı ve süre ayarı korunur',
        () {
      final sql = _read(migration);
      expect(sql.contains("in ('wholesaler', 'commercial')"), isTrue);
      expect(
        sql.contains("app_config_int('premium_promo_months', 3)"),
        isTrue,
      );
    });

    test('my_entitlement yeni alanlar sona eklendi (eski uyum)', () {
      final sql = _read(migration);
      expect(sql.contains('free_period_active boolean'), isTrue);
      expect(sql.contains('free_period_started_at timestamptz'), isTrue);
      expect(sql.contains('free_period_ends_at timestamptz'), isTrue);
      expect(sql.contains('free_period_days_left int'), isTrue);
      expect(sql.contains('launch_price_until timestamptz'), isTrue);
      // Eski alanlar korunur (örnekleme).
      expect(sql.contains('supplier_launch_free_active boolean'), isTrue);
      expect(sql.contains('subscription_purchase_allowed boolean'), isTrue);
    });

    test('pop-up ack anahtarları kullanıcı+tür bazında; hatırlatma kapalı', () {
      final sql = _read(migration);
      expect(
        sql.contains(
          "notice_key in ('popup_ack', 'welcome_ack', 'ending_ack', "
          "'ended_ack')",
        ),
        isTrue,
      );
    });

    test('otomatik ücret/abonelik başlatılmaz; geçmiş silinmez', () {
      final sql = _read(migration);
      expect(sql.contains('set plan ='), isFalse);
      expect(sql.contains('store_subscription_transactions'), isFalse);
      expect(sql.contains('delete from'), isFalse);
      expect(sql.contains('drop table'), isFalse);
    });
  });

  group('commercial launch pop-up kontratı', () {
    const sheet =
        'lib/features/subscriptions/widgets/commercial_launch_sheet.dart';

    test('yalnız bilgilendirme: ödeme/abonelik/kart akışı yok', () {
      final src = _read(sheet);
      expect(src.contains('purchase'), isFalse);
      expect(src.contains('Purchases'), isFalse);
      expect(src.contains('paymentServiceProvider'), isFalse);
    });

    test('İstanbul günü; tarih yoksa gösterim yok; tür bazlı kalıcı kayıt',
        () {
      final src = _read(sheet);
      expect(src.contains('formatSupplierLaunchDate'), isTrue);
      expect(src.contains('toLocal()'), isFalse);
      expect(src.contains('if (ends == null) return;'), isTrue);
      expect(src.contains('hasSeenCommercialLaunchNotice'), isTrue);
      expect(src.contains('markCommercialLaunchNoticeSeen'), isTrue);
      expect(src.contains('whenComplete'), isTrue);
      // Kullanıcı+tür bazlı oturum koruması.
      expect(src.contains("'\$userId:\${notice.noticeKey}'"), isTrue);
    });
  });
}
