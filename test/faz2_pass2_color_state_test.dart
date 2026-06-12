// FırınNet Faz 2 Pass 2 — Bayi renk kalıntısı temizliği + tema segment tutarlılığı
// + hata standardı sözleşmeleri.

import 'dart:io';

import 'package:firin_defter/app/theme/app_colors.dart';
import 'package:firin_defter/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('Tema — SegmentedButton tutarlılığı (mat altın remnant gitti)', () {
    test('SegmentedButton seçili = parlak lemon (brandLemon), primary buton ile aynı',
        () {
      final theme = AppTheme.lightTheme();
      final style = theme.segmentedButtonTheme.style;
      expect(style, isNotNull);
      final selectedBg = style!.backgroundColor!.resolve({WidgetState.selected});
      final unselectedBg = style.backgroundColor!.resolve(<WidgetState>{});
      expect(selectedBg, AppColors.brandLemon,
          reason: 'Seçili segment parlak lemon olmalı (mat altın değil)');
      expect(unselectedBg, AppColors.surface);
      // Filled (primary) buton da aynı parlak lemon → tutarlı.
      final filledBg = theme.filledButtonTheme.style!.backgroundColor!
          .resolve(<WidgetState>{});
      expect(filledBg, AppColors.brandLemon);
    });

    test('secondaryContainer açıkça pale lemon (lavanta/mat altın değil)', () {
      final theme = AppTheme.lightTheme();
      expect(theme.colorScheme.secondaryContainer, AppColors.brandLemonPale);
    });
  });

  group('Bayi renk kalıntısı temizliği', () {
    test('dealer_pulse_card eski sıcak bej (0xFFEFE6DB) kaldırıldı', () {
      final src =
          _read('lib/features/dealers/widgets/dealer_pulse_card.dart');
      expect(src.contains('0xFFEFE6DB'), isFalse,
          reason: 'Eski sıcak bej divider kalmamalı');
    });

    test('DealerAvatar copper palette okunur ink harf kullanır', () {
      final src = _read('lib/features/dealers/widgets/dealer_avatar.dart');
      // copper case'inde foreground artık brandInk (lemon-on-lemon değil).
      final i = src.indexOf('case DealerAvatarPalette.copper:');
      final block = src.substring(i, i + 500);
      expect(block.contains('foreground: AppColors.brandInk'), isTrue);
    });
  });

  group('Mesajlar listesi — okunur rozet + sıcak avatar', () {
    test('unread rozet ink-on-lemon (beyaz-on-lemon değil); avatar pale lemon',
        () {
      final src =
          _read('lib/features/messages/screens/messages_list_screen.dart');
      // Rozet artık brandLemon zemin + brandInk metin.
      expect(src.contains('color: AppColors.brandLemon'), isTrue);
      expect(src.contains('color: AppColors.brandInk'), isTrue);
      // Avatar sıcak pale lemon zemin.
      expect(src.contains('color: AppColors.brandLemonPale'), isTrue);
    });
  });

  group('Gruplar liste hata durumu ortak component', () {
    test('groups_list ErrorRetryState kullanır (ad-hoc _GroupsErrorState yok)',
        () {
      final src = _read(
          'lib/features/social_groups/screens/groups_list_screen.dart');
      expect(src.contains('ErrorRetryState'), isTrue);
      expect(src.contains('class _GroupsErrorState'), isFalse);
    });
  });

  group('Hata standardı — ham exception app genelinde sızmaz', () {
    test('recipe_detail + dealer_picker_sheet ErrorRetryState kullanır', () {
      expect(
        _read('lib/features/bakery_panel/screens/recipe_detail_screen.dart')
            .contains('ErrorRetryState'),
        isTrue,
      );
      final picker =
          _read('lib/features/dealers/widgets/dealer_picker_sheet.dart');
      expect(picker.contains('ErrorRetryState'), isTrue);
      expect(picker.contains("Text('Hata: \${"), isFalse);
    });
  });
}
