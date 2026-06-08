// Visual North Star Sprint 1A — AppTypography token unit testleri.
//
// 10 token tanımlı; fontSize/weight/letterSpacing/height değerleri
// dokümante edilen tasarım sistemiyle uyumlu.

import 'package:firin_defter/app/theme/app_colors.dart';
import 'package:firin_defter/app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTypography — Display', () {
    test('displayLarge 32pt w800 letterSpacing -0.5', () {
      expect(AppTypography.displayLarge.fontSize, 32);
      expect(AppTypography.displayLarge.fontWeight, FontWeight.w800);
      expect(AppTypography.displayLarge.letterSpacing, -0.5);
      expect(AppTypography.displayLarge.color, AppColors.textPrimary);
    });

    test('displayMedium 26pt w800 letterSpacing -0.4', () {
      expect(AppTypography.displayMedium.fontSize, 26);
      expect(AppTypography.displayMedium.fontWeight, FontWeight.w800);
      expect(AppTypography.displayMedium.letterSpacing, -0.4);
    });
  });

  group('AppTypography — Headline + Title', () {
    test('headlineSmall 22pt w800', () {
      expect(AppTypography.headlineSmall.fontSize, 22);
      expect(AppTypography.headlineSmall.fontWeight, FontWeight.w800);
    });

    test('titleLarge 19pt w800', () {
      expect(AppTypography.titleLarge.fontSize, 19);
      expect(AppTypography.titleLarge.fontWeight, FontWeight.w800);
    });

    test('titleMedium 16pt w700', () {
      expect(AppTypography.titleMedium.fontSize, 16);
      expect(AppTypography.titleMedium.fontWeight, FontWeight.w700);
    });
  });

  group('AppTypography — Body', () {
    test('bodyLarge 15.5pt w500 line height 1.52', () {
      expect(AppTypography.bodyLarge.fontSize, 15.5);
      expect(AppTypography.bodyLarge.fontWeight, FontWeight.w500);
      expect(AppTypography.bodyLarge.height, 1.52);
    });

    test('bodyMedium 14pt w500', () {
      expect(AppTypography.bodyMedium.fontSize, 14);
      expect(AppTypography.bodyMedium.fontWeight, FontWeight.w500);
    });

    test('bodySmall 12.5pt w500 textMuted', () {
      expect(AppTypography.bodySmall.fontSize, 12.5);
      expect(AppTypography.bodySmall.color, AppColors.textMuted);
    });
  });

  group('AppTypography — Label', () {
    test('labelLarge 12.5pt w700 letterSpacing 0.25', () {
      expect(AppTypography.labelLarge.fontSize, 12.5);
      expect(AppTypography.labelLarge.fontWeight, FontWeight.w700);
      expect(AppTypography.labelLarge.letterSpacing, 0.25);
    });

    test('labelSmall 11pt w700 letterSpacing 0.6 textMuted', () {
      expect(AppTypography.labelSmall.fontSize, 11);
      expect(AppTypography.labelSmall.fontWeight, FontWeight.w700);
      expect(AppTypography.labelSmall.letterSpacing, 0.6);
      expect(AppTypography.labelSmall.color, AppColors.textMuted);
    });
  });
}
