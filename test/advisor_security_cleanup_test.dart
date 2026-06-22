// PR-5 advisor security cleanup — migration kaynak-assertion.
// 1) trigger-only fonksiyon EXECUTE revoke · 2) bucket listing owner-scoped ·
// 3) inert pg_net trigger drop. Gerçek DB/canlı dokunulmaz.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final mig = File(
    'supabase/migrations/20260623120000_advisor_security_cleanup.sql',
  ).readAsStringSync();
  final ml = mig.toLowerCase();

  group('1) helper/trigger fonksiyon EXECUTE revoke', () {
    test('advisor-flag + tüm trigger-only fonksiyonlar revoke', () {
      for (final fn in [
        'b2b_set_updated_at',
        'bump_conversation_updated_at',
        'calculate_dealer_delivery_item',
        'calculate_recipe_calculation',
        'calculate_waste_entry',
        'compute_dealer_delivery_remaining',
        'feed_guard_server_counters',
        'job_conversations_guard_lifecycle',
        'rls_auto_enable',
        'set_updated_at',
      ]) {
        expect(
          ml.contains('revoke execute on function public.$fn()'),
          isTrue,
          reason: '$fn revoke eksik',
        );
      }
      expect(ml.contains('from public, anon, authenticated'), isTrue);
    });
  });

  group('2) public bucket listing → owner-scoped', () {
    test('4 bucket owner = auth.uid() ile daraltılır', () {
      for (final b in ['avatars', 'feed-media', 'market-media', 'story-media']) {
        expect(
          ml.contains("bucket_id = '$b' and owner = auth.uid()"),
          isTrue,
          reason: '$b owner-scope eksik',
        );
      }
    });

    test('chat-media (private/gated) DEĞİŞMEZ', () {
      // chat-media policy'si veya bucket_id'si migration'da DROP/CREATE edilmez.
      expect(ml.contains('chat_media_storage_select'), isFalse);
      expect(ml.contains("bucket_id = 'chat-media'"), isFalse);
    });
  });

  group('3) inert pg_net trigger temizliği', () {
    test('trigger + fonksiyon drop', () {
      expect(
        ml.contains(
          'drop trigger if exists trg_notifications_push_dispatch on public.notifications',
        ),
        isTrue,
      );
      expect(
        ml.contains('drop function if exists public.dispatch_notification_push()'),
        isTrue,
      );
    });

    test('aktif webhook + dedup tablosu DOKUNULMAZ', () {
      // Webhook trigger DROP edilmez.
      expect(ml.contains('drop trigger if exists push_dispatch_on_notification_insert'),
          isFalse);
      // Hiçbir tablo drop'u / dedup tablosu alter'ı yok.
      expect(ml.contains('drop table'), isFalse);
      expect(ml.contains('alter table public.notification_push_deliveries'), isFalse);
    });
  });
}
