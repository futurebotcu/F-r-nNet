import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

final TextStyle premiumFont = const TextStyle(fontFamily: 'Inter');

/// Ortak buton varyantları (tema varsayılanı = birincil sarı CTA).
class AppButtonStyles {
  const AppButtonStyles._();

  /// Geri alınamaz işlem (sil, engelle, hesabı sil): kırmızı zemin + beyaz
  /// metin. Yalnız `backgroundColor: danger` vermek tema mürekkep metnini
  /// kırmızı üstünde bırakıyordu (okunmaz).
  static final ButtonStyle destructive = FilledButton.styleFrom(
    backgroundColor: AppColors.danger,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.danger.withValues(alpha: 0.35),
    disabledForegroundColor: Colors.white70,
  );
}

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
        // Sayfa başlığı her yerde aynı (AppTypography.pageTitle ile eş).
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.15,
          height: 1.15,
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
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
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
        floatingLabelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.3,
        ),
        helperMaxLines: 2,
        errorStyle: const TextStyle(
          color: AppColors.danger,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        errorMaxLines: 2,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
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
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.s),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandInk,
          disabledForegroundColor: AppColors.textMuted,
          // F2F2F2 kenar beyaz zeminde görünmüyordu → ikincil buton
          // "buton" olarak okunmuyordu.
          side: const BorderSide(color: Color(0xFFDDE0E5)),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      // İkon butonlar: görsel ikon 22px, dokunma alanı en az 44px.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(44, 44),
          iconSize: 22,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textPrimary,
        textColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
        minVerticalPadding: 10,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brandInk
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brandLemon
              : const Color(0xFFE5E7EB),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brandInk
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(AppColors.brandLemon),
        side: const BorderSide(color: Color(0xFFB8BEC7), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brandInk
              : const Color(0xFFB8BEC7),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.brandInk,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.brandInk,
        dividerColor: AppColors.borderHairline,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandLemon,
        foregroundColor: AppColors.brandInk,
        elevation: 2,
        highlightElevation: 3,
      ),
      shadowColor: Colors.black,
      // Ortak işlem geri bildirimi: koyu mürekkep zemin + beyaz metin, alttan
      // yüzen kısa bildirim. Beyaz ekran üstünde beyaz snackbar kayboluyordu;
      // 167 çağrı yeri tema üzerinden tek dile geçer (bkz. AppFeedback).
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.brandInk,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        actionTextColor: AppColors.brandLemon,
        closeIconColor: Colors.white70,
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
      ),
      // Popup'lar ham Android dialog gibi görünmesin: beyaz yüzey, yumuşak
      // köşe, tutarlı başlık/gövde tipografisi, tint yok.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: -0.2,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textSecondary,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        elevation: 0,
        modalElevation: 0,
        // showDragHandle global açılmaz: birçok sheet kendi tutamacını çizer.
        dragHandleColor: Color(0xFFD9DCE1),
        dragHandleSize: Size(36, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.l),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      // İmleç/seçim: sarı imleç beyaz alanda görünmüyordu.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.brandInk,
        selectionColor: AppColors.brandLemon.withValues(alpha: 0.45),
        selectionHandleColor: AppColors.brandInk,
      ),
      // Yükleme göstergesi: ince, mürekkep tonu (sarı halka beyazda
      // kayboluyordu); dev kalın spinner yok.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandInk,
        linearTrackColor: AppColors.surfaceLine,
        circularTrackColor: Colors.transparent,
        strokeWidth: 2.4,
      ),
    );
  }
}
