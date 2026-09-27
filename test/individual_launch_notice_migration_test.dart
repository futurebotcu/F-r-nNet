import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('individual launch notice migration contract', () {
    const migration =
        'supabase/migrations/20260928090000_individual_launch_notice_v1.sql';

    test('bitiş tarihi tek kaynak config; mevcut değer korunur', () {
      final sql = _read(migration);
      expect(
        sql.contains("('individual_launch_free_until', "
            '\'"2027-10-01T00:00:00+03:00"\'::jsonb)'),
        isTrue,
      );
      expect(sql.contains('on conflict (key) do nothing'), isTrue);
      expect(
        sql.contains(
          "app_config_timestamptz('individual_launch_free_until', null)",
        ),
        isTrue,
      );
    });

    test('my_entitlement: yeni kolon SONDA; bireysel satın alma her koşulda '
        'kapalı; iş hesaplarında null', () {
      final sql = _read(migration);
      // Kolon listesi individual_free_until ile biter (eski sıra korunur).
      expect(
        RegExp(r'individual_free_until timestamptz\s*\)').hasMatch(sql),
        isTrue,
      );
      // subscription_purchase_allowed formülü DEĞİŞMEDİ (else false).
      expect(sql.contains("when me.acct = 'commercial' then true"), isTrue);
      expect(sql.contains('else false'), isTrue);
      // individual_free_until yalnız iş hesabı DEĞİLSE dolu.
      expect(
        sql.contains("me.acct is distinct from 'commercial'"),
        isTrue,
      );
      expect(
        sql.contains("me.acct is distinct from 'wholesaler'"),
        isTrue,
      );
    });

    test('ack için yeni policy GEREKMEZ: popup_ack mevcut policy kapsamında',
        () {
      final sql = _read(migration);
      // Bu migration user_campaign_notices policy'sine DOKUNMAZ (yalnız
      // açıklama yorumunda adı geçer; DDL yoktur).
      expect(sql.contains('create policy'), isFalse);
      expect(sql.contains('drop policy'), isFalse);
      expect(sql.contains('alter table public.user_campaign_notices'), isFalse);
      // Client tarafı campaign_key kontratı.
      final repo = _read(
        'lib/features/subscriptions/data/supabase_subscription_repository.dart',
      );
      expect(repo.contains("'individual_launch_v1'"), isTrue);
      expect(repo.contains('hasSeenIndividualLaunchNotice'), isTrue);
      expect(repo.contains('markIndividualLaunchNoticeSeen'), isTrue);
    });

    test('grant hijyeni: yeni fonksiyonlar anon/public kapalı', () {
      final sql = _read(migration);
      expect(
        sql.contains('revoke execute on function '
            'public.individual_launch_free_until()'),
        isTrue,
      );
      expect(
        sql.contains(
          'revoke execute on function public.my_entitlement() '
          'from public, anon',
        ),
        isTrue,
      );
    });
  });

  group('individual launch pop-up kontratı', () {
    test('yalnız bilgilendirme: satın alma/abonelik/kart akışı yok', () {
      final sheet = _read(
        'lib/features/subscriptions/widgets/individual_launch_sheet.dart',
      );
      expect(sheet.contains('Navigator.of(context).pop()'), isTrue);
      // Ödeme API'lerine hiçbir çağrı yok (doc yorumundaki
      // subscription_purchase_allowed sözcüğü hariç tutulur).
      for (final forbidden in [
        'purchasePlan',
        'purchaseProduct',
        'Purchases.',
        'PurchaseParams',
        'RevenueCat',
        'paymentService',
        'restorePurchases',
      ]) {
        expect(sheet.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('gerçek tarih zorunlu; İstanbul günü; görüldü kaydı kullanıcı bazlı',
        () {
      final sheet = _read(
        'lib/features/subscriptions/widgets/individual_launch_sheet.dart',
      );
      expect(sheet.contains('formatSupplierLaunchDate'), isTrue);
      expect(sheet.contains('freeUntil == null'), isTrue);
      expect(sheet.contains('_sessionAttemptedUserId'), isTrue);
      expect(sheet.contains('hasSeenIndividualLaunchNotice'), isTrue);
      expect(sheet.contains('markIndividualLaunchNoticeSeen'), isTrue);
    });
  });
}
