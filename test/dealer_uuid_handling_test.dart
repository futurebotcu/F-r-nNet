import 'package:firin_defter/features/dealers/repositories/supabase_dealer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V1.3.5 — SupabaseDealerRepository.looksLikeUuid', () {
    test('uuid v4 formatı true döner', () {
      expect(
        SupabaseDealerRepository.looksLikeUuid(
            'abf96b42-0d17-40b1-9b0f-cbf910f9e2a4'),
        isTrue,
      );
      expect(
        SupabaseDealerRepository.looksLikeUuid(
            'ABF96B42-0D17-40B1-9B0F-CBF910F9E2A4'),
        isTrue,
        reason: 'Büyük harf hex de geçerli',
      );
    });

    test('client-generated d_<microseconds> formatı false döner', () {
      // AddDealerScreen'in ürettiği gerçek format
      expect(
        SupabaseDealerRepository.looksLikeUuid('d_1778669329154623'),
        isFalse,
      );
    });

    test('local seed dealer ID\'leri false döner (d_hamdi vs.)', () {
      expect(SupabaseDealerRepository.looksLikeUuid('d_hamdi'), isFalse);
      expect(SupabaseDealerRepository.looksLikeUuid('d_pasif'), isFalse);
    });

    test('boş string ve random text false', () {
      expect(SupabaseDealerRepository.looksLikeUuid(''), isFalse);
      expect(SupabaseDealerRepository.looksLikeUuid('not-a-uuid'), isFalse);
      expect(SupabaseDealerRepository.looksLikeUuid('12345'), isFalse);
    });

    test('uuid benzeri ama format hatalı false', () {
      // Tire eksik
      expect(
        SupabaseDealerRepository.looksLikeUuid(
            'abf96b420d1740b19b0fcbf910f9e2a4'),
        isFalse,
      );
      // Tire fazla
      expect(
        SupabaseDealerRepository.looksLikeUuid(
            'abf96b42-0d17-40b1-9b0f-cbf910f9e2a4-extra'),
        isFalse,
      );
      // Hex olmayan karakter
      expect(
        SupabaseDealerRepository.looksLikeUuid(
            'gggggggg-0d17-40b1-9b0f-cbf910f9e2a4'),
        isFalse,
      );
    });

    // upsertDealer'ın gerçek branching'ini test etmek için Supabase client
    // mock'u gerekirdi; pure validator testi yeterli — branching mantığı:
    //   if (!looksLikeUuid(id)) → INSERT direkt
    //   else → eq lookup + insert/update
    // Validator doğru çalışıyorsa branching de doğru çalışır.
  });
}
