// FırınNet Feed Boundary V1 — classifier + entegrasyon testleri.
//
// Ürün kuralı: Feed sohbet/soru/deneyim alanıdır; net ticari/ilan/satış
// içeriği doğru alana yönlendirilir, normal konuşma ASLA engellenmez.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/feed/services/feed_boundary_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FeedBoundaryResult post(String t) => FeedBoundaryClassifier.classifyPost(t);
  FeedBoundaryResult comment(String t) =>
      FeedBoundaryClassifier.classifyComment(t);

  group('Boundary V1 — NORMAL kullanım daima serbest', () {
    final allowedSamples = <String>[
      'Eleman bulmak artık çok zor',
      'Hamur makinesi alırken nelere dikkat ediyorsunuz?',
      'Un fiyatları arttı, siz ne yapıyorsunuz?',
      'Yeni fırınımızda ilk günümüz, heyecanlıyız!',
      'Makinem bozuldu, çözüm önerisi olan var mı?',
      'Usta bulamıyoruz, siz nasıl çözüyorsunuz?',
      'Bugün ürünler böyle çıktı, yorumlarınızı beklerim',
      'Ekmek fiyatına zam geldi, tartışalım',
      'Çırak yetiştirmek konusunda tavsiyesi olan?',
      'Bu mikserin temizliği nasıl yapılır?',
      'İndirim yapsam mı sizce, kâr marjı çok düştü?',
    ];

    for (final sample in allowedSamples) {
      test('izinli: "$sample"', () {
        final r = post(sample);
        expect(r.allowed, isTrue,
            reason: 'Normal sohbet/soru engellenmemeli: $sample '
                '(category=${r.category}, reason=${r.reason})');
      });
    }

    test('yalnız medya (boş text) → serbest', () {
      expect(post('').allowed, isTrue);
      expect(post('   ').allowed, isTrue);
    });
  });

  group('Boundary V1 — ticari/ilan sinyalleri yönlendirilir', () {
    test('"eleman aranıyor" → jobAd → İş İlanları', () {
      final r = post('Fırınımıza acil eleman aranıyor, maaş dolgundur');
      expect(r.allowed, isFalse);
      expect(r.category, FeedBoundaryCategory.jobAd);
      expect(r.destination, FeedBoundaryDestination.jobListings);
      expect(r.confidence, FeedBoundaryConfidence.high);
    });

    test('"usta aranıyor" → jobAd', () {
      final r = post('Usta aranıyor. İlgilenenler dm');
      expect(r.allowed, isFalse);
      expect(r.category, FeedBoundaryCategory.jobAd);
    });

    test('"iş arıyorum" → jobSeek → İş Arıyorum ilanı (yumuşak)', () {
      final r = post('Merhaba, 10 yıllık ustayım iş arıyorum');
      expect(r.allowed, isFalse);
      expect(r.category, FeedBoundaryCategory.jobSeek);
      expect(r.destination, FeedBoundaryDestination.jobSeekListing);
    });

    test('"fırın satılık" → workplaceSale → İş yeri ilanı', () {
      final r = post('Konya merkezde fırın satılık, ilgilenenlere');
      expect(r.allowed, isFalse);
      expect(r.category, FeedBoundaryCategory.workplaceSale);
      expect(r.destination, FeedBoundaryDestination.workplaceListings);
    });

    test('"devren satılık işyeri" → workplaceSale', () {
      final r = post('Devren satılık işyeri, cadde üstü köşe başı');
      expect(r.category, FeedBoundaryCategory.workplaceSale);
    });

    test('"hamur makinesi satılık" → equipmentSale → Ekipman ilanı', () {
      final r = post('Az kullanılmış hamur makinesi satılık');
      expect(r.allowed, isFalse);
      expect(r.category, FeedBoundaryCategory.equipmentSale);
      expect(r.destination, FeedBoundaryDestination.equipmentListings);
    });

    test('"mikser satıyorum" → equipmentSale', () {
      final r = post('Spiral mikser satıyorum, temiz makina');
      expect(r.category, FeedBoundaryCategory.equipmentSale);
    });

    test('"toptan satış / fiyat listesi" → commercialAd → Pazar', () {
      final r = post('Toptan satış başlamıştır, fiyat listesi için dm');
      expect(r.allowed, isFalse);
      expect(r.category, FeedBoundaryCategory.commercialAd);
      expect(r.destination, FeedBoundaryDestination.market);
      expect(r.confidence, FeedBoundaryConfidence.high);
    });

    test('"sipariş için" reklam → commercialAd', () {
      final r = post('Taze maya geldi, sipariş için arayın');
      expect(r.category, FeedBoundaryCategory.commercialAd);
    });
  });

  group('Boundary V1 — güvenlik (profanity / scam)', () {
    test('ağır küfür → profanity → rewrite (yayınlanmaz)', () {
      final r = post('siktir git buradan şerefsiz');
      expect(r.allowed, isFalse);
      expect(r.category, FeedBoundaryCategory.profanity);
      expect(r.destination, FeedBoundaryDestination.safetyRewrite);
    });

    test('"kaçak ürün" → scamOrIllegal (yayınlanmaz)', () {
      final r = post('Kaçak ürün getirtebilirim, ucuza');
      expect(r.allowed, isFalse);
      expect(r.category, FeedBoundaryCategory.scamOrIllegal);
    });

    test('false-positive guard: "fiziksel" gibi kelimeler küfür değil', () {
      expect(post('Fiziksel yorgunluk had safhada bugün').allowed, isTrue);
      expect(post('Götürü usulü anlaştık tedarikçiyle').allowed, isTrue);
    });
  });

  group('Boundary V1 — saha bypass regresyonları (emülatör kanıtlı)', () {
    test('"eleman aranyor" (yazım hatası) → jobAd yakalanır', () {
      final r = post('eleman aranyor');
      expect(r.allowed, isFalse,
          reason: 'Saha kanıtı: aranıyor yazım hatasıyla bypass edilmişti');
      expect(r.category, FeedBoundaryCategory.jobAd);
    });

    test('ASCII yazım: "eleman araniyor" / "satilik makine" yakalanır', () {
      expect(post('eleman araniyor acil').category,
          FeedBoundaryCategory.jobAd);
      expect(post('satilik hamur makinesi temiz').category,
          FeedBoundaryCategory.equipmentSale);
    });

    test('sesli-düşürülmüş küfür ("skeym") → profanity yakalanır', () {
      final r = post('hepnzn anas n skeym toptan sat');
      expect(r.allowed, isFalse,
          reason: 'Saha kanıtı: obfuscated küfür bypass edilmişti');
      expect(r.category, FeedBoundaryCategory.profanity);
    });

    test('"toptan sat" prefix → commercialAd', () {
      final r = post('un toptan sat elimde bol var');
      expect(r.allowed, isFalse);
      expect(r.category, FeedBoundaryCategory.commercialAd);
    });

    test('İSKELET ÇAKIŞMA GUARD: "sektör" küfür DEĞİL', () {
      // sektör→sktr iskeleti siktir ile çakışır; ağır sesli-düşürme şartı
      // (uzunluk farkı ≤1) normal kelimeyi korur.
      expect(post('Sektörde eleman bulmak çok zor').allowed, isTrue);
      expect(post('sektor genel olarak durgun bu ay').allowed, isTrue);
    });

    test('"satilik araba" — domain dışı çıplak satış → Pazar', () {
      final r = post('satilik araba');
      expect(r.allowed, isFalse,
          reason: 'Saha kanıtı: domain ismi olmayan satış bypass edilmişti');
      expect(r.category, FeedBoundaryCategory.commercialAd);
      expect(r.destination, FeedBoundaryDestination.market);
    });

    test('"anan s-keym ya" — tire ile bölünmüş küfür yakalanır', () {
      final r = post('anan s-keym ya');
      expect(r.allowed, isFalse,
          reason: 'Saha kanıtı: parçalanmış küfür bypass edilmişti');
      expect(r.category, FeedBoundaryCategory.profanity);
    });

    test('fuzzy niyet: "aranıyo"/"satlik" yazımları yakalanır', () {
      expect(post('usta aranıyo acil').category, FeedBoundaryCategory.jobAd);
      expect(post('mikser satlik temiz').category,
          FeedBoundaryCategory.equipmentSale);
    });

    test('leet/tekrar: "s1kt1r" ve "aranııııyor" yakalanır', () {
      expect(post('s1kt1r git').category, FeedBoundaryCategory.profanity);
      expect(
          post('eleman aranııııyor').category, FeedBoundaryCategory.jobAd);
    });

    test('alıcı sorusu serbest: "satılık mikser arıyorum, öneri?"', () {
      expect(
        post('Satılık mikser arıyorum, önerisi olan var mı?').allowed,
        isTrue,
        reason: 'Soru bağlamındaki satılık = alıcı; engellenmemeli',
      );
    });
  });

  group('Boundary V1 — yorum DAR kuralı', () {
    test('yorumda küfür engellenir', () {
      final r = comment('amk ne biçim ekmek bu');
      expect(r.allowed, isFalse);
      expect(r.category, FeedBoundaryCategory.profanity);
    });

    test('yorumda link\'li reklam spam engellenir', () {
      final r = comment('Sipariş için https://ornek.com kampanya!');
      expect(r.allowed, isFalse);
      expect(r.category, FeedBoundaryCategory.commercialAd);
    });

    test('yorumda ticari YÖNLENDİRME yok: "mikser satıyorum" yorumu serbest',
        () {
      // V1 ürün kararı: yorum bağlamı sohbettir; satış cümlesi yorumda
      // engellenmez/yönlendirilmez (yalnız güvenlik + bariz link spam).
      expect(comment('Bende fazladan mikser var satıyorum istersen').allowed,
          isTrue);
    });

    test('normal yorum serbest', () {
      expect(comment('Eline sağlık, harika görünüyor').allowed, isTrue);
    });
  });

  group('Boundary V1 — source contracts', () {
    String src(String p) => File(p).readAsStringSync();

    test('composer: auth guard SONRA boundary, publish ÖNCE', () {
      final s =
          src('lib/features/social/composer/social_composer_page.dart');
      final authIdx = s.indexOf('showAuthRequiredSheet');
      final boundaryIdx =
          s.indexOf('FeedBoundaryClassifier.classifyPost(text)');
      // Header yorumundaki `.addPost(` değil, gerçek çağrı: boundary'den
      // sonraki ilk occurrence aranır.
      final addPostIdx = s.indexOf('.addPost(', boundaryIdx);
      expect(boundaryIdx, greaterThan(authIdx),
          reason: 'Guest önce AuthRequiredSheet görmeli (çakışma yok)');
      expect(addPostIdx, greaterThan(boundaryIdx),
          reason: 'Boundary publish\'ten önce çalışmalı');
      expect(s.contains('showFeedBoundarySheet'), isTrue);
    });

    test('yorum: classifyComment + banner (sheet değil)', () {
      final s = src('lib/features/social/comments/comments_page.dart');
      expect(
          s.contains('FeedBoundaryClassifier.classifyComment(text)'), isTrue);
      expect(s.contains('AppStrings.boundaryCommentBlocked'), isTrue);
    });

    test('sheet: kategori CTA route eşlemesi doğru', () {
      final s = src('lib/features/feed/widgets/feed_boundary_sheet.dart');
      expect(s.contains('AppRoutes.market'), isTrue);
      expect(s.contains('AppRoutes.jobOfferNew'), isTrue);
      expect(s.contains('AppRoutes.jobSeekNew'), isTrue);
      expect(s.contains('AppRoutes.marketListingNew'), isTrue);
      expect(s.contains('AppStrings.boundaryEditCta'), isTrue);
      expect(s.contains('AppStrings.boundaryCancelCta'), isTrue);
      expect(s.contains('AppStrings.boundaryWhyLabel'), isTrue);
    });

    test('copy sabitleri tanımlı (spec metinleri)', () {
      expect(AppStrings.boundaryCommercialTitle,
          'Bu paylaşım Pazar için daha uygun');
      expect(AppStrings.boundaryCommercialCta, 'Pazar\'a git');
      expect(AppStrings.boundaryJobCta, 'İş ilanı oluştur');
      expect(AppStrings.boundaryProfanityTitle,
          'Paylaşımı biraz yumuşatalım');
      expect(AppStrings.boundaryEditCta, 'Metni düzenle');
      expect(AppStrings.boundaryWorkplaceCta, isNotEmpty);
      expect(AppStrings.boundaryEquipmentCta, isNotEmpty);
      expect(AppStrings.boundaryScamTitle, isNotEmpty);
    });
  });
}
