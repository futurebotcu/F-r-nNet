import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('supplier launch campaign migration contract', () {
    const migration =
        'supabase/migrations/20260925090000_supplier_launch_campaign_v1.sql';

    test('bitiş SABİT config değeri; start+1yıl türetimi YOK', () {
      final sql = _read(migration);
      expect(
        sql.contains(
          "('supplier_launch_free_until', "
          '\'"2027-10-01T00:00:00+03:00"\'::jsonb)',
        ),
        isTrue,
      );
      expect(sql.contains("interval '1 year'"), isFalse);
      // Operatör config'i migration tekrarında ezilmez.
      expect(sql.contains('on conflict (key) do nothing'), isTrue);
    });

    test('başlangıç tanımsız + start boşken kampanya/hatırlatma pasif', () {
      final sql = _read(migration);
      expect(
        sql.contains("('supplier_launch_free_start', 'null'::jsonb)"),
        isTrue,
      );
      expect(
        sql.contains('if v_start is null or v_until is null then'),
        isTrue,
      );
    });

    test('hak kontrolü server-side ve yalnız wholesaler', () {
      final sql = _read(migration);
      expect(sql.contains('is_supplier_launch_free_active'), isTrue);
      expect(sql.contains("p.account_type = 'wholesaler'"), isTrue);
      expect(sql.contains('security definer'), isTrue);
      expect(sql.contains("set search_path = ''"), isTrue);
    });

    test('kişisel promo tedarikçi haklarını açamaz ve başlatılamaz', () {
      final sql = _read(migration);
      // Kampanya dışında yalnız ÖDENMİŞ abonelik premium açar.
      expect(sql.contains('paid_business_plan'), isTrue);
      // Tedarikçi promo başlatma engeli.
      expect(sql.contains("if v_acct = 'wholesaler' then"), isTrue);
      // Ortak promo süresi ayarına dokunulmaz (ticari akış aynen).
      expect(
        sql.contains("app_config_int('premium_promo_months', 3)"),
        isTrue,
      );
    });

    test('satın alma uygunluğu server kararı olarak yayınlanır', () {
      final sql = _read(migration);
      expect(sql.contains('subscription_purchase_allowed'), isTrue);
      expect(sql.contains('supplier_paid_packages_published'), isTrue);
    });

    test('my_entitlement kampanya alanlarını sona ekler', () {
      final sql = _read(migration);
      expect(sql.contains('supplier_launch_free_active boolean'), isTrue);
      expect(sql.contains('supplier_launch_free_until timestamptz'), isTrue);
    });

    test('pop-up görüldü kaydı kalıcı ve kullanıcı+kampanya bazlı', () {
      final sql = _read(migration);
      expect(sql.contains('user_campaign_notices'), isTrue);
      expect(
        sql.contains('primary key (user_id, campaign_key, notice_key)'),
        isTrue,
      );
      expect(
        sql.contains("user_id = auth.uid() and notice_key = 'popup_ack'"),
        isTrue,
      );
    });

    test('hatırlatmalar 30g/7g, dedup, geç katılan ve açık bitiş metni', () {
      final sql = _read(migration);
      expect(sql.contains('enqueue_supplier_launch_reminders'), isTrue);
      expect(sql.contains("interval '30 days'"), isTrue);
      expect(sql.contains("interval '7 days'"), isTrue);
      expect(sql.contains("'reminder_30d'"), isTrue);
      expect(sql.contains("'reminder_7d'"), isTrue);
      // Mevcut bildirim altyapısına entegre (in-app zil + push dispatch).
      expect(sql.contains('insert into public.notifications'), isTrue);
      expect(sql.contains("'supplier_launch_reminder'"), isTrue);
      // Son ÜCRETSİZ GÜN, İstanbul saatine göre.
      expect(sql.contains("at time zone 'Europe/Istanbul'"), isTrue);
      expect(sql.contains('günü sonunda sona eriyor'), isTrue);
      // Metinde kesin fiyat yok.
      expect(sql.contains('TL'), isFalse);
    });

    test('otomatik ücretli abonelik başlatılmaz', () {
      final sql = _read(migration);
      // Kampanya user_entitlements/store tablolarına plan YAZMAZ (promo
      // fonksiyonundaki mevcut ticari promo update'leri hariç — onlar
      // 20260923 davranışının birebir kopyasıdır ve plan kolonuna dokunmaz).
      expect(sql.contains('set plan ='), isFalse);
      expect(sql.contains('store_subscription_transactions'), isFalse);
    });
  });

  group('supplier launch pop-up kontratı', () {
    const sheet =
        'lib/features/subscriptions/widgets/supplier_launch_gift_sheet.dart';

    test('yalnız bilgilendirme: satın alma/abonelik/kart akışı yok', () {
      final src = _read(sheet);
      expect(src.contains('purchase'), isFalse);
      expect(src.contains('Purchases'), isFalse);
      expect(src.contains('paymentServiceProvider'), isFalse);
      // Buton yalnız kapatır.
      expect(src.contains('Navigator.of(context).pop()'), isTrue);
    });

    test('gerçek tarih zorunlu; placeholder/geri sayım yok; İstanbul günü', () {
      final src = _read(sheet);
      expect(src.contains('required DateTime freeUntil'), isTrue);
      expect(src.contains('Timer'), isFalse);
      expect(src.contains('countdown'), isFalse);
      // Cihaz saat diliminden bağımsız İstanbul günü (UTC+3 sabit).
      expect(src.contains('toLocal()'), isFalse);
      expect(src.contains('Duration(hours: 3)'), isTrue);
      // Kampanya pasif/bitmişse gösterilmez.
      expect(
        src.contains(
          'if (!entitlement.supplierLaunchFreeActive || freeUntil == null)',
        ),
        isTrue,
      );
    });

    test('görüldü kaydı kalıcı + kullanıcı bazlı oturum koruması', () {
      final src = _read(sheet);
      expect(src.contains('whenComplete'), isTrue);
      expect(src.contains('hasSeenSupplierLaunchNotice'), isTrue);
      expect(src.contains('markSupplierLaunchNoticeSeen'), isTrue);
      // Hesap değişiminde ikinci kullanıcı görebilsin.
      expect(src.contains('_sessionAttemptedUserId'), isTrue);
    });
  });
}
