// PR-3 hardening — kaynak-assertion'lar.
// FN-AUDIT-007/020 (finansal sessiz hata), FN-AUDIT-017 (çift-submit),
// FN-AUDIT-010 (recognizer dispose) + FN-AUDIT-008 redirect wiring.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('FN-AUDIT-008 — router redirect wiring', () {
    final s = _read('lib/app/router/app_router.dart');
    test('createRouter isAuthed + redirect', () {
      expect(s.contains('redirect:'), isTrue);
      expect(s.contains('routeRequiresAuth(state.matchedLocation)'), isTrue);
      expect(s.contains('isAuthed'), isTrue);
    });
    test('app.dart local mod enforcement kapalı + refresh', () {
      final a = _read('lib/app/app.dart');
      expect(a.contains('!AppConfig.supabaseEnabled'), isTrue);
      expect(a.contains('createRouter('), isTrue);
      expect(a.contains('_router.refresh()'), isTrue);
    });
  });

  group('FN-AUDIT-007/020 — finansal sessiz hata görünür', () {
    test('şoför bayi detayı bakiye hatası + retry', () {
      final s = _read(
        'lib/features/dealers/screens/driver_dealer_detail_screen.dart',
      );
      expect(s.contains('ErrorRetryState'), isTrue);
      expect(s.contains('Bakiye yüklenemedi'), isTrue);
      expect(s.contains('invalidate(balanceSummaryProvider'), isTrue);
    });
    test('borç-gider özet + hareket hatası + retry', () {
      final s = _read(
        'lib/features/debt_expense/screens/debt_expense_overview_tab.dart',
      );
      expect(s.contains('ErrorRetryState'), isTrue);
      expect(s.contains('Özet yüklenemedi'), isTrue);
      expect(s.contains('Hareketler yüklenemedi'), isTrue);
    });
  });

  group('FN-AUDIT-017 — B2B form çift-submit guard', () {
    test('B2bSaveButton onTap nullable (disable destekli)', () {
      final s = _read('lib/features/b2b_market/widgets/b2b_form_field.dart');
      expect(s.contains('final VoidCallback? onTap;'), isTrue);
    });
    test('kampanya + ürün formu _saving + guard + disabled buton', () {
      for (final f in [
        'lib/features/b2b_market/screens/supplier/forms/'
            'supplier_campaign_form_screen.dart',
        'lib/features/b2b_market/screens/supplier/forms/'
            'supplier_product_form_screen.dart',
      ]) {
        final s = _read(f);
        expect(s.contains('bool _saving = false'), isTrue, reason: f);
        expect(s.contains('if (_saving) return;'), isTrue, reason: f);
        expect(s.contains('onTap: _saving ? null : _save'), isTrue, reason: f);
      }
    });
  });

  group('FN-AUDIT-010 — TapGestureRecognizer dispose', () {
    test('legal_footer Stateful + recognizer dispose', () {
      final s = _read('lib/features/auth/widgets/legal_footer.dart');
      expect(s.contains('extends StatefulWidget'), isTrue);
      expect(s.contains('_termsTap.dispose()'), isTrue);
      expect(s.contains('_privacyTap.dispose()'), isTrue);
      // build içinde inline recognizer kalmamalı.
      expect(s.contains('recognizer: _termsTap'), isTrue);
    });
    test('create_profile yasal checkbox recognizer dispose', () {
      final s = _read(
        'lib/features/profile/screens/create_profile_screen.dart',
      );
      expect(s.contains('_LegalAcceptCheckboxState'), isTrue);
      expect(s.contains('_termsTap.dispose()'), isTrue);
      expect(s.contains('_privacyTap.dispose()'), isTrue);
    });
  });
}
