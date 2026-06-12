import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

final TextStyle premiumFont = const TextStyle(fontFamily: 'Inter');

class AppTheme {
  const AppTheme._();

  static const double radiusLg = AppRadius.l;
  static const double radiusMd = AppRadius.m;
  static const double radiusSm = AppRadius.s;

  static ThemeData lightTheme() => _socialTheme();
  static ThemeData darkTheme() => _socialTheme();

  static ThemeData _socialTheme() {
    const colorScheme = ColorScheme.light(
      primary: AppColors.brandLemon,
      onPrimary: AppColors.brandInk,
      secondary: AppColors.brandLemonPressed,
      onSecondary: AppColors.brandInk,
      // Faz 2 P2 — secondaryContainer açıkça PALE LEMON. Eskiden boş bırakılınca
      // M3 default'u (lavanta) veya secondary'nin mat altın tonu (E6C84A)
      // segment/chip seçili zeminlerinde "eski/kahverengi" his veriyordu.
      secondaryContainer: AppColors.brandLemonPale,
      onSecondaryContainer: AppColors.brandInk,
      surface: AppColors.surface,
      onSurface: AppColors.brandInk,
      outline: AppColors.borderHairline,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      surfaceContainerLowest: AppColors.surface,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
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
            fontFamily: 'Inter',
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
              fontSize: 19,
              letterSpacing: 0.1,
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              letterSpacing: 0.1,
            ),
            bodyLarge: base.textTheme.bodyLarge?.copyWith(
              fontSize: 15.5,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(
              fontSize: 14.25,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
            bodySmall: base.textTheme.bodySmall?.copyWith(
              fontSize: 12.25,
              color: AppColors.textMuted,
              letterSpacing: 0.2,
            ),
            labelLarge: base.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              letterSpacing: 0.25,
            ),
            labelMedium: base.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              color: AppColors.textSecondary,
              letterSpacing: 0.25,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
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
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.brandInk,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        indicatorColor: AppColors.brandLemonPale,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: 0.2,
            color: states.contains(WidgetState.selected)
                ? AppColors.brandInk
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.brandInk
                : AppColors.textSecondary,
            size: 24,
          ),
        ),
        height: 70,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.brandInk,
          disabledBackgroundColor: AppColors.brandLemonPale,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
      // Faz 2 P2 — SegmentedButton tek tip: seçili = parlak lemon + ink,
      // pasif = beyaz + ikincil metin. Eskiden tema default'u mat altın/lavanta
      // veriyordu (bayi "Çalışma tipi", düzeltme yönü vb. eski his). Artık
      // birincil buton ile aynı parlak lemon.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.brandLemon
                : AppColors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.brandInk
                : AppColors.textSecondary,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.brandInk
                : AppColors.textSecondary,
          ),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.borderHairline, width: 0.8),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.brandInk,
          disabledBackgroundColor: AppColors.brandLemonPale,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: premiumFont.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        disabledColor: AppColors.surface,
        selectedColor: AppColors.brandLemonPale,
        secondarySelectedColor: AppColors.brandLemonPale,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        labelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.brandInk,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderHairline,
        thickness: 0.6,
        space: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(
            color: AppColors.borderHairline,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(
            color: AppColors.borderHairline,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(
            color: AppColors.brandLemonPressed,
            width: 1.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandInk,
          disabledForegroundColor: AppColors.textMuted,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandInk,
          disabledForegroundColor: AppColors.textMuted,
          side: const BorderSide(color: AppColors.warmBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      shadowColor: Colors.black,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
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
    );
  }
}
