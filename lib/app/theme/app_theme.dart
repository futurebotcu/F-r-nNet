import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Tema: açık krem zemin + açık kartlar + zengin bakır vurgu.
/// %75 krem, %20 sıcak destek, %5 koyu kahve vurgu.
///
/// Color Polish Sprint: copper derinleştirildi (#A8632C, beyaz yazı ~4.7:1
/// WCAG AA), bu yüzden primary üstündeki yazı artık BEYAZ (onPrimary) —
/// buton temaları ile sistem genel uyumu. Light kart üstündeki vurgu metni
/// hâlâ softGold (deep brown).
class AppTheme {
  const AppTheme._();

  // Eski API'lerle uyum için radius sabitleri.
  static const double radiusLg = AppRadius.l;
  static const double radiusMd = AppRadius.m;
  static const double radiusSm = AppRadius.s;

  /// Eski `darkTheme()` çağrı yerlerini bozmamak için aynı isim;
  /// içeriği artık açık tema.
  static ThemeData darkTheme() => _bakeryTheme();

  /// Asıl tema fabrikası — açık, sıcak, samimi.
  static ThemeData _bakeryTheme() {
    const colorScheme = ColorScheme.light(
      primary: AppColors.copper,
      // Color Polish Sprint: zengin copper üstünde beyaz (FAB, segmented vb.
      // primary yüzeyleri buton standardıyla aynı dile bağlanır).
      onPrimary: Colors.white,
      primaryContainer: AppColors.copperMuted,
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.softGold,
      onSecondary: AppColors.textPrimary,
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.card,
      outline: AppColors.borderHairline,
      outlineVariant: AppColors.surfaceLine,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      splashFactory: NoSplash.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
            fontFamily: 'Roboto',
          )
          .copyWith(
            displayLarge: base.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
            displayMedium: base.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            headlineLarge: base.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            headlineSmall: base.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.1,
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            bodyLarge: base.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(
              fontSize: 14.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
            bodySmall: base.textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: AppColors.textMuted,
              letterSpacing: 0.2,
            ),
            labelLarge: base.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.1,
            ),
            labelMedium: base.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        toolbarHeight: 60,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: 22,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.copper,
          // P0 Design Tokens — FırınNet primary copper button standardı:
          // yazı her yerde BEYAZ (referans + ekranların çoğu zaten beyaz).
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.copper.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.copper,
          // P0 Design Tokens — copper primary button yazısı beyaz (standart).
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // Deep amber foreground — light krem üzerinde okunabilir.
          foregroundColor: AppColors.softGold,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(
            color: AppColors.softGold.withValues(alpha: 0.55),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.softGold,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(
            color: AppColors.borderHairline,
            width: 0.6,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(
            color: AppColors.borderHairline,
            width: 0.6,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(color: AppColors.softGold, width: 1.4),
        ),
      ),
      // P0 Design Tokens — FırınNet chip standardı.
      // Kanonik filter/segment chip widget'ı: `DealerFilterChip`
      // (core ölçü: seçili = copper border 1.2 + copper@0.18 bg + softGold
      // w800; pasif = card bg + hairline 0.6 + textSecondary w600; radius
      // pill; font 12.5; ikon 16). ChipThemeData `side`'ı seçime göre
      // değiştiremediği için ekranlar bu kanonik widget'ı kullanmalı; tema
      // default'u o standarda yaklaşacak şekilde hizalandı (raw ChoiceChip
      // için en yakın görünüm).
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.copper.withValues(alpha: 0.18),
        side: const BorderSide(color: AppColors.borderHairline, width: 0.6),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
        // Seçili chip: softGold (deep amber) w800 — kanonik standartla aynı.
        secondaryLabelStyle: const TextStyle(
          color: AppColors.softGold,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        showCheckmark: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceLine,
        thickness: 0.6,
        space: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            letterSpacing: 0.2,
            color: states.contains(WidgetState.selected)
                ? AppColors.softGold
                : AppColors.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.softGold
                : AppColors.textMuted,
            size: 24,
          ),
        ),
        height: 70,
      ),
      snackBarTheme: SnackBarThemeData(
        // Light tema — snackbar da kart hissi, koyu kahve text.
        backgroundColor: AppColors.elevatedCard,
        contentTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 22,
      ),
    );
  }
}
