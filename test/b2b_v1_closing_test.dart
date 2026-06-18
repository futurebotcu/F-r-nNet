// B2B V1 kapanış — status lifecycle + görsel upload alanları testleri.
//
// Kapsam:
//  * B2bQuoteStatus: label / dbValue / isActive / isTerminal (4 durum)
//  * statusFromText map (open/answered/replied/closed/cancelled/null)
//  * Local close/cancel → status güncellenir
//  * storeFromRow logo/cover, product/campaign image_url mapper
//  * Local addProduct/addCampaign/updateStore image alanlarını taşır
//  * B2bMediaUploadService.buildPath + extractStoragePath

import 'package:firin_defter/features/b2b_market/models/b2b_quote_request.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/repositories/supabase_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/services/b2b_media_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('B2bQuoteStatus', () {
    test('label / dbValue / isActive / isTerminal', () {
      expect(B2bQuoteStatus.waiting.label, 'Bekliyor');
      expect(B2bQuoteStatus.replied.label, 'Teklif geldi');
      expect(B2bQuoteStatus.closed.label, 'Kapandı');
      expect(B2bQuoteStatus.cancelled.label, 'İptal edildi');

      expect(B2bQuoteStatus.waiting.dbValue, 'open');
      expect(B2bQuoteStatus.replied.dbValue, 'answered');
      expect(B2bQuoteStatus.closed.dbValue, 'closed');
      expect(B2bQuoteStatus.cancelled.dbValue, 'cancelled');

      expect(B2bQuoteStatus.waiting.isActive, isTrue);
      expect(B2bQuoteStatus.replied.isActive, isTrue);
      expect(B2bQuoteStatus.closed.isActive, isFalse);
      expect(B2bQuoteStatus.cancelled.isActive, isFalse);

      expect(B2bQuoteStatus.closed.isTerminal, isTrue);
      expect(B2bQuoteStatus.cancelled.isTerminal, isTrue);
      expect(B2bQuoteStatus.waiting.isTerminal, isFalse);
    });

    test('statusFromText', () {
      expect(SupabaseB2bRepository.statusFromText('open'), B2bQuoteStatus.waiting);
      expect(SupabaseB2bRepository.statusFromText('answered'),
          B2bQuoteStatus.replied);
      expect(SupabaseB2bRepository.statusFromText('replied'),
          B2bQuoteStatus.replied);
      expect(SupabaseB2bRepository.statusFromText('closed'),
          B2bQuoteStatus.closed);
      expect(SupabaseB2bRepository.statusFromText('cancelled'),
          B2bQuoteStatus.cancelled);
      expect(SupabaseB2bRepository.statusFromText(null), B2bQuoteStatus.waiting);
    });
  });

  group('Local — talep kapat/iptal', () {
    test('closeQuoteRequest → closed', () async {
      final repo = LocalB2bRepository();
      final r = await repo.addQuoteRequest(
        targetType: 'general',
        category: 'Un',
        quantity: '10',
        city: 'İstanbul',
      );
      await repo.closeQuoteRequest(r.id);
      final d = await repo.quoteRequestById(r.id);
      expect(d!.status, B2bQuoteStatus.closed);
    });

    test('cancelQuoteRequest → cancelled', () async {
      final repo = LocalB2bRepository();
      final r = await repo.addQuoteRequest(
        targetType: 'general',
        category: 'Un',
        quantity: '10',
        city: 'İstanbul',
      );
      await repo.cancelQuoteRequest(r.id);
      final d = await repo.quoteRequestById(r.id);
      expect(d!.status, B2bQuoteStatus.cancelled);
    });
  });

  group('Görsel mapper (Supabase)', () {
    test('storeFromRow logo_url / cover_url okur', () {
      final s = SupabaseB2bRepository.storeFromRow({
        'id': 's1',
        'shop_name': 'SMOKE-B2B Tedarikçi',
        'description': '',
        'categories': ['Un'],
        'service_regions': ['Marmara'],
        'owner_id': 'u1',
        'logo_url': 'https://x/logo.jpg',
        'cover_url': 'https://x/cover.jpg',
      }, currentUserId: 'u1');
      expect(s.logoUrl, 'https://x/logo.jpg');
      expect(s.coverUrl, 'https://x/cover.jpg');
      expect(s.isMine, isTrue);
    });

    test('productFromRow image_url okur', () {
      final p = SupabaseB2bRepository.productFromRow({
        'id': 'p1',
        'name': 'SMOKE-B2B Ekmeklik Un',
        'shop_id': 's1',
        'category': 'Un',
        'min_order': '10 çuval',
        'delivery_regions': ['Marmara'],
        'description': '',
        'image_url': 'https://x/p.jpg',
        'published': true,
        'b2b_supplier_shops': {'shop_name': 'Shop', 'owner_id': 'u1'},
      });
      expect(p.imageUrl, 'https://x/p.jpg');
    });

    test('campaignFromRow image_url okur', () {
      final c = SupabaseB2bRepository.campaignFromRow({
        'id': 'c1',
        'title': 'SMOKE-B2B Un Kampanyası',
        'shop_id': 's1',
        'category': 'Un',
        'regions': ['Marmara'],
        'min_order': '100 çuval',
        'valid_until': null,
        'description': '',
        'image_url': 'https://x/c.jpg',
        'published': true,
        'b2b_supplier_shops': {'shop_name': 'Shop', 'owner_id': 'u1'},
      });
      expect(c.imageUrl, 'https://x/c.jpg');
    });
  });

  group('Local — image alanları', () {
    test('addProduct/addCampaign/updateStore image taşır', () async {
      final repo = LocalB2bRepository();
      final p = await repo.addProduct(
        name: 'P',
        category: 'Un',
        minOrder: '10',
        deliveryRegion: 'Marmara',
        imageUrl: 'https://x/p.jpg',
      );
      expect(p.imageUrl, 'https://x/p.jpg');

      final c = await repo.addCampaign(
        title: 'C',
        category: 'Un',
        region: 'Marmara',
        minPurchase: '100',
        validUntil: 'Süresiz',
        imageUrl: 'https://x/c.jpg',
      );
      expect(c.imageUrl, 'https://x/c.jpg');

      final s = await repo.updateStore(
        name: 'S',
        description: '',
        serviceRegions: const ['Marmara'],
        categories: const ['Un'],
        logoUrl: 'https://x/logo.jpg',
        coverUrl: 'https://x/cover.jpg',
      );
      expect(s.logoUrl, 'https://x/logo.jpg');
      expect(s.coverUrl, 'https://x/cover.jpg');
    });
  });

  group('B2bMediaUploadService path', () {
    test('buildPath uid ile başlar (RLS owner-prefix)', () {
      final path = B2bMediaUploadService.buildPath(
        userId: 'u1',
        kind: B2bMediaKind.shopLogo,
        ext: 'JPG',
        timestampMs: 123,
      );
      expect(path, 'u1/b2b/shop-logo_123.jpg');
      expect(path.split('/').first, 'u1');
    });

    test('extractStoragePath public URL → göreceli path', () {
      const url =
          'https://h/storage/v1/object/public/market-media/u1/b2b/product_9.png';
      expect(
        B2bMediaUploadService.extractStoragePath(url),
        'u1/b2b/product_9.png',
      );
      expect(B2bMediaUploadService.extractStoragePath(null), isNull);
      expect(B2bMediaUploadService.extractStoragePath('https://h/other'), isNull);
    });
  });
}
