// B2B Pazar — repository seçim (provider fallback) testleri.
//
// b2bRepositoryFor saf fonksiyonu: auth + Supabase hazırsa Supabase, aksi
// halde Local; Supabase oluşturma hatasında Local fallback. Ayrıca provider
// guest ortamında (Supabase yok) Local döndürür → Pazar boş kalmaz.

import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('b2bRepositoryFor — seçim mantığı', () {
    B2bRepository local() => LocalB2bRepository();

    test('Supabase kapalı + auth var → Local', () {
      var supabaseCalled = false;
      final r = b2bRepositoryFor(
        supabaseEnabled: false,
        userId: 'u1',
        makeSupabase: () {
          supabaseCalled = true;
          return local();
        },
        makeLocal: local,
      );
      expect(supabaseCalled, isFalse);
      expect(r, isA<LocalB2bRepository>());
    });

    test('Supabase açık + auth YOK (guest) → Local', () {
      var supabaseCalled = false;
      final r = b2bRepositoryFor(
        supabaseEnabled: true,
        userId: null,
        makeSupabase: () {
          supabaseCalled = true;
          return local();
        },
        makeLocal: local,
      );
      expect(supabaseCalled, isFalse);
      expect(r, isA<LocalB2bRepository>());
    });

    test('Supabase açık + auth var → Supabase factory çağrılır', () {
      var supabaseCalled = false;
      b2bRepositoryFor(
        supabaseEnabled: true,
        userId: 'u1',
        makeSupabase: () {
          supabaseCalled = true;
          return local();
        },
        makeLocal: local,
      );
      expect(supabaseCalled, isTrue);
    });

    test('Supabase oluşturma hatası → Local fallback (çökmez)', () {
      final r = b2bRepositoryFor(
        supabaseEnabled: true,
        userId: 'u1',
        makeSupabase: () => throw StateError('client hazır değil'),
        makeLocal: local,
      );
      expect(r, isA<LocalB2bRepository>());
    });
  });

  group('b2bRepositoryProvider — guest ortamı', () {
    test('Supabase yokken (test env) provider Local döndürür', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      // Test ortamında AppConfig.supabaseEnabled=false + auth yok → Local.
      expect(c.read(b2bRepositoryProvider), isA<LocalB2bRepository>());
    });
  });
}
