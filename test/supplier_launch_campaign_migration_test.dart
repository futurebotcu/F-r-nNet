import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('supplier launch campaign migration contract', () {
    const migration =
        'supabase/migrations/20260925090000_supplier_launch_campaign_v1.sql';

    test('kampanya tarihsiz/pasif başlar — tarih uydurulmaz', () {
      final sql = _read(migration);
      expect(
        sql.contains("('supplier_launch_free_start', 'null'::jsonb)"),
        isTrue,
      );
      expect(
        sql.contains("('supplier_launch_free_until', 'null'::jsonb)"),
        isTrue,
      );
      // Operatör config'i migration tekrarında ezilmez.
      expect(sql.contains('on conflict (key) do nothing'), isTrue);
    });

    test('1 takvim yılı açık saat dilimiyle (Europe/Istanbul) hesaplanır', () {
      final sql = _read(migration);
      expect(sql.contains("at time zone 'Europe/Istanbul'"), isTrue);
      expect(sql.contains("interval '1 year'"), isTrue);
    });

    test('hak kontrolü server-side ve yalnız wholesaler', () {
      final sql = _read(migration);
      expect(sql.contains('is_supplier_launch_free_active'), isTrue);
      expect(sql.contains("p.account_type = 'wholesaler'"), isTrue);
      // Mevcut mekanizma genişletilir (paralel sistem yok): tek kapı
      // effective_supplier_plan.
      expect(
        sql.contains(
          'when public.is_supplier_launch_free_active(p_owner_id) '
          "then 'premium'",
        ),
        isTrue,
      );
      expect(sql.contains('security definer'), isTrue);
      expect(sql.contains("set search_path = ''"), isTrue);
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

    test('hatırlatmalar 30g/7g, dedup ve geç katılan koruması', () {
      final sql = _read(migration);
      expect(sql.contains('enqueue_supplier_launch_reminders'), isTrue);
      expect(sql.contains("interval '30 days'"), isTrue);
      expect(sql.contains("interval '7 days'"), isTrue);
      expect(sql.contains("'reminder_30d'"), isTrue);
      expect(sql.contains("'reminder_7d'"), isTrue);
      // Mevcut bildirim altyapısına entegre (in-app zil + push dispatch).
      expect(sql.contains('insert into public.notifications'), isTrue);
      expect(sql.contains("'supplier_launch_reminder'"), isTrue);
      // Metinde kesin fiyat yok.
      expect(sql.contains('TL'), isFalse);
    });

    test('otomatik ücretli abonelik başlatılmaz', () {
      final sql = _read(migration);
      // Kampanya user_entitlements/store tablolarına plan YAZMAZ.
      expect(sql.contains('update public.user_entitlements'), isFalse);
      expect(sql.contains('insert into public.user_entitlements'), isFalse);
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

    test('gerçek tarih zorunlu; placeholder/geri sayım yok', () {
      final src = _read(sheet);
      expect(src.contains('required DateTime freeUntil'), isTrue);
      expect(src.contains('Timer'), isFalse);
      expect(src.contains('countdown'), isFalse);
      // Kampanya pasif/bitmişse gösterilmez.
      expect(
        src.contains(
          'if (!entitlement.supplierLaunchFreeActive || freeUntil == null)',
        ),
        isTrue,
      );
    });

    test('görüldü kaydı kapanış yolundan bağımsız düşer', () {
      final src = _read(sheet);
      expect(src.contains('whenComplete'), isTrue);
      expect(src.contains('hasSeenSupplierLaunchNotice'), isTrue);
      expect(src.contains('markSupplierLaunchNoticeSeen'), isTrue);
    });
  });
}
