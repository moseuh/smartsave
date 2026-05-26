import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color financeGreen    = Color(0xFF1B6631);
  static const Color financeGreenV2  = Color(0xFF2D8A47);
  static const Color financeGreenV3  = Color(0xFF51AA44);

  static const Color coreWhite   = Color(0xFFFFFFFF);
  static const Color coreWhiteW1 = Color(0xFFF2F7F2);
  static const Color coreWhiteW2 = Color(0xFFE5EFE5);

  static const Color coreDark    = Color(0xFF252525);
  static const Color coreDarkD1  = Color(0xFF3A3A3A);
  static const Color coreDarkD2  = Color(0xFF4F4F4F);

  static const Color success = Color(0xFF51AA44);
  static const Color warning = Color(0xFFF5A623);
  static const Color error   = Color(0xFFE53E3E);
  static const Color info    = Color(0xFF3182CE);
}

class AppTheme {
  AppTheme._();

  static const Color primaryColor    = AppColors.financeGreen;
  static const Color primaryDark     = AppColors.financeGreen;
  static const Color primaryLight    = AppColors.financeGreenV3;
  static const Color accentColor     = AppColors.financeGreenV3;
  static const Color accentLight     = AppColors.financeGreenV2;

  static const Color successColor    = AppColors.success;
  static const Color warningColor    = AppColors.warning;
  static const Color errorColor      = AppColors.error;
  static const Color infoColor       = AppColors.info;

  static const Color backgroundLight = AppColors.coreWhiteW1;
  static const Color cardLight       = AppColors.coreWhite;
  static const Color coreWhiteField  = AppColors.coreWhite;
  static const Color textPrimary     = AppColors.coreDark;
  static const Color textSecondary   = AppColors.coreDarkD2;
  static const Color textLight       = AppColors.coreWhite;

  static const Color backgroundDark  = AppColors.coreDark;
  static const Color cardDark        = AppColors.coreDarkD1;

  static const Duration slowAnimation   = Duration(milliseconds: 800);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Curve defaultCurve       = Curves.easeInOut;

  static final List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: AppColors.financeGreen.withValues(alpha: 0.18),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: AppColors.coreDark.withValues(alpha: 0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [AppColors.financeGreen, AppColors.financeGreenV3],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [AppColors.financeGreenV2, AppColors.financeGreenV3],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [AppColors.financeGreen, AppColors.financeGreenV2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [AppColors.coreDark, AppColors.coreDarkD1],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── LIGHT THEME ──────────────────────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      error: errorColor,
      surface: cardLight,
      onPrimary: textLight,
      onSecondary: textLight,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: primaryColor,
      foregroundColor: textLight,
      iconTheme: IconThemeData(color: textLight),
      titleTextStyle: TextStyle(color: textLight, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardLight,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: textLight,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: coreWhiteField,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: TextStyle(color: AppColors.coreDarkD2.withValues(alpha: 0.55)),
    ),
    iconTheme: const IconThemeData(color: primaryColor, size: 24),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.bold,   color: textPrimary),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,   color: textPrimary),
      displaySmall:  TextStyle(fontSize: 24, fontWeight: FontWeight.bold,   color: textPrimary),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600,   color: textPrimary),
      headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.w600,   color: textPrimary),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,   color: textPrimary),
      titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600,   color: textPrimary),
      titleMedium:   TextStyle(fontSize: 14, fontWeight: FontWeight.w600,   color: textPrimary),
      bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: textPrimary),
      bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textPrimary),
      bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: textSecondary),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.coreDarkD2.withValues(alpha: 0.2),
      thickness: 1,
      space: 16,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accentColor : AppColors.coreDarkD2),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
          ? AppColors.financeGreenV2.withValues(alpha: 0.4)
          : AppColors.coreDarkD2.withValues(alpha: 0.2)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: accentColor,
      linearTrackColor: AppColors.coreWhiteW2,
    ),
  );

  // ── DARK THEME ───────────────────────────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: accentColor,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: accentColor,
      secondary: primaryColor,
      error: errorColor,
      surface: cardDark,
      onPrimary: textLight,
      onSecondary: textLight,
      onSurface: textLight,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: backgroundDark,
      foregroundColor: textLight,
      iconTheme: IconThemeData(color: textLight),
      titleTextStyle: TextStyle(color: textLight, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardDark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: textLight,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accentColor,
        side: const BorderSide(color: accentColor, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.coreWhite.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.coreWhite.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: AppColors.coreWhite.withValues(alpha: 0.7)),
      hintStyle: TextStyle(color: AppColors.coreWhite.withValues(alpha: 0.4)),
    ),
    iconTheme: const IconThemeData(color: accentColor, size: 24),
    textTheme: TextTheme(
      displayLarge:  const TextStyle(fontSize: 32, fontWeight: FontWeight.bold,   color: textLight),
      displayMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,   color: textLight),
      displaySmall:  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold,   color: textLight),
      headlineLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600,   color: textLight),
      headlineMedium:const TextStyle(fontSize: 20, fontWeight: FontWeight.w600,   color: textLight),
      headlineSmall: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600,   color: textLight),
      titleLarge:    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,   color: textLight),
      titleMedium:   const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,   color: textLight),
      bodyLarge:     const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: textLight),
      bodyMedium:    const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textLight),
      bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.coreWhite.withValues(alpha: 0.65)),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.coreWhite.withValues(alpha: 0.15),
      thickness: 1,
      space: 16,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accentColor,
      linearTrackColor: AppColors.coreWhite.withValues(alpha: 0.15),
    ),
  );
}
