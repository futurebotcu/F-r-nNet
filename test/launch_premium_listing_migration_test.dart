import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('launch premium/listing migration contract', () {
    const migration =
        'supabase/migrations/20260923120000_launch_premium_and_listing_v1.sql';

    test(
      'promo activation is server-side, idempotent and uses server time',
      () {
        final sql = _read(migration);
        expect(sql.contains('activate_launch_premium_promo()'), isTrue);
        expect(sql.contains('security definer'), isTrue);
        expect(sql.contains("promo_status = 'not_started'"), isTrue);
        expect(sql.contains('now()'), isTrue);
        expect(sql.contains('premium_promo_months'), isTrue);
        expect(
          sql.contains(
            'grant execute on function public.activate_launch_premium_promo()',
          ),
          isTrue,
        );
      },
    );

    test('new listings get server-owned max 30 day expiry', () {
      final sql = _read(migration);
      expect(sql.contains("('listing_max_active_days', '30'::jsonb)"), isTrue);
      expect(
        sql.contains(
          'new.expires_at := now() + make_interval(days => v_days);',
        ),
        isTrue,
      );
      expect(
        sql.contains('new.expires_at := coalesce(new.expires_at'),
        isFalse,
      );
      expect(sql.contains('new.expires_at := old.expires_at;'), isTrue);
      expect(sql.contains('expire_old_listings()'), isTrue);
      expect(sql.contains('republish_listing('), isTrue);
    });

    test(
      'launch listing payments are disabled without deleting 50 TL infra',
      () {
        final sql = _read(migration);
        expect(
          sql.contains("('listing_payments_enabled', 'false'::jsonb)"),
          isTrue,
        );
        expect(sql.contains('firinnet_listing_fee_50'), isTrue);
        expect(sql.contains('get_listing_fee_amount_cents'), isTrue);
        expect(sql.contains('return 0;'), isTrue);
      },
    );

    test('legacy Pro products and rows continue as Premium access', () {
      final sql = _read(migration);
      expect(
        sql.contains("coalesce(e.plan, 'free') in ('premium', 'pro')"),
        isTrue,
      );
      expect(
        sql.contains(
          "('firinnet_bakery_pro_monthly',       'commercial', 'premium', 'subscription')",
        ),
        isTrue,
      );
      expect(
        sql.contains(
          "('firinnet_supplier_pro_monthly',     'wholesaler', 'premium', 'subscription')",
        ),
        isTrue,
      );
    });

    test('stale subscription events cannot shorten active paid access', () {
      final sql = _read(migration);
      expect(sql.contains('v_existing_expires_at > p_expires_at'), isTrue);
      expect(sql.contains('ignored_stale_subscription_event'), isTrue);
      expect(
        sql.contains('older event for the same product shorten'),
        isTrue,
      );
    });
  });

  group('RevenueCat listing confirmation hardening', () {
    const fn = 'supabase/functions/revenuecat-confirm-listing-payment/index.ts';

    test('rejects stale/reused consumable transactions', () {
      final src = _read(fn);
      expect(src.contains('created_at'), isTrue);
      expect(src.contains('purchasedAtMs'), isTrue);
      expect(src.contains('intentCreatedMs'), isTrue);
      expect(src.contains('.filter((p) => p.ms >= intentCreatedMs)'), isTrue);
      expect(src.contains('provider_transaction_id'), isTrue);
      expect(src.contains('transaction_already_used'), isTrue);
    });
  });
}
