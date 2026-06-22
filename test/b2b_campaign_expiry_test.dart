// FN-AUDIT-006 — Kampanya geçerlilik tarihi: DatePicker + expiry filtresi.
// FN-AUDIT-015 — mükerrer teklif graceful mesaj (repo).
//
// campaignFromRow + B2bDateField.formatTr saf-Dart; query filtresi + form
// DatePicker kaynak-assertion ile kilitlenir.

import 'dart:io';

import 'package:firin_defter/features/b2b_market/repositories/supabase_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/widgets/b2b_form_field.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _campaignRow({dynamic validUntil}) => {
      'id': 'c1',
      'shop_id': 's1',
      'title': 'Sezon Fırsatı',
      'category': 'Un',
      'regions': <String>['Marmara'],
      'min_order': '100 çuval',
      'valid_until': validUntil,
      'description': '',
      'image_url': null,
      'published': true,
      'b2b_supplier_shops': {'shop_name': 'Aksoy Un', 'owner_id': 'o1'},
    };

void main() {
  group('campaignFromRow — valid_until etiketi', () {
    test('null → Süresiz', () {
      final c = SupabaseB2bRepository.campaignFromRow(_campaignRow());
      expect(c.validUntil, 'Süresiz');
    });

    test('tarih → ISO etiketi', () {
      final c = SupabaseB2bRepository.campaignFromRow(
        _campaignRow(validUntil: '2026-12-31'),
      );
      expect(c.validUntil, '2026-12-31');
    });
  });

  group('B2bDateField.formatTr — TR gösterim', () {
    test('dd.MM.yyyy sıfır dolgulu', () {
      expect(B2bDateField.formatTr(DateTime(2026, 6, 5)), '05.06.2026');
      expect(B2bDateField.formatTr(DateTime(2026, 11, 20)), '20.11.2026');
    });
  });

  group('Kaynak-assertion — form DatePicker + repo filtresi', () {
    test('kampanya formu serbest metin yerine DatePicker kullanır', () {
      final f = File(
        'lib/features/b2b_market/screens/supplier/forms/'
        'supplier_campaign_form_screen.dart',
      ).readAsStringSync();
      expect(f.contains('showDatePicker'), isTrue);
      expect(f.contains('B2bDateField'), isTrue);
      expect(f.contains('_validUntilDate'), isTrue);
      // Eski serbest-metin hint'i kalmamalı.
      expect(f.contains('Ör. 30 Haziran 2026'), isFalse);
    });

    test('repo listCampaigns/campaignsForStore expiry filtresi + dedup mesajı',
        () {
      final r = File(
        'lib/features/b2b_market/repositories/supabase_b2b_repository.dart',
      ).readAsStringSync();
      // Süresi geçmiş kampanyalar gizlenir (null = süresiz → görünür).
      expect(
        r.contains('valid_until.is.null,valid_until.gte.'),
        isTrue,
      );
      // FN-AUDIT-015 unique violation → anlaşılır mesaj.
      expect(r.contains("'23505'"), isTrue);
      expect(r.contains('Bu talebe zaten teklif verdiniz.'), isTrue);
    });
  });
}
