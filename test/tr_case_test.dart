import 'package:firin_defter/core/utils/tr_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trUpperCase — Türkçe büyük harf', () {
    test('sipariş için kalan gün → SİPARİŞ İÇİN KALAN GÜN', () {
      expect(trUpperCase('sipariş için kalan gün'), 'SİPARİŞ İÇİN KALAN GÜN');
    });

    test('maliyet → MALİYET', () {
      expect(trUpperCase('maliyet'), 'MALİYET');
    });

    test('tahmini ciro → TAHMİNİ CİRO', () {
      expect(trUpperCase('tahmini ciro'), 'TAHMİNİ CİRO');
    });

    test('noktasız ı → I (kıvam → KIVAM)', () {
      expect(trUpperCase('kıvam'), 'KIVAM');
    });

    test('diğer Türkçe harfler doğru (çğöşü)', () {
      expect(trUpperCase('çuval ürün'), 'ÇUVAL ÜRÜN');
      expect(trUpperCase('değer'), 'DEĞER');
    });

    test('zaten büyük harfli metin değişmez (idempotent)', () {
      const upper = 'SİPARİŞ İÇİN';
      expect(trUpperCase(upper), upper);
      // Üst üste iki kez geçmek de güvenli (StatCard yeniden upper-case eder).
      expect(trUpperCase(trUpperCase('için')), 'İÇİN');
    });

    test('standart toUpperCase Türkçe i\'yi bozarken helper korur', () {
      // Regresyon koruması: hata vakası IÇIN üretiyordu.
      expect('için'.toUpperCase(), isNot('İÇİN'));
      expect(trUpperCase('için'), 'İÇİN');
    });
  });
}
