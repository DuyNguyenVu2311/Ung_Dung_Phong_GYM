import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';

class AppColors {
  static Color get background =>
      AppSettingsService.isLight ? Color(0xFFF5F7FB) : Color(0xFF08111F);
  static Color get surface =>
      AppSettingsService.isLight ? Color(0xFFFFFFFF) : Color(0xFF101B2D);
  static Color get surfaceElevated =>
      AppSettingsService.isLight ? Color(0xFFEDF2F8) : Color(0xFF17243A);
  static Color get surfaceBright =>
      AppSettingsService.isLight ? Color(0xFFE0E8F2) : Color(0xFF20304A);

  static Color get primary =>
      AppSettingsService.isLight ? Color(0xFF16805C) : Color(0xFF67E0B1);
  static const Color primaryDark = Color(0xFF2DBE88);
  static Color get secondary =>
      AppSettingsService.isLight ? Color(0xFF2766B4) : Color(0xFF77AFFF);
  static const Color accent = Color(0xFFFF8A7A);
  static const Color accentPurple = Color(0xFFB69CFF);

  static Color get textPrimary =>
      AppSettingsService.isLight ? Color(0xFF142033) : Color(0xFFFFFFFF);
  static Color get textSecondary =>
      AppSettingsService.isLight ? Color(0xFF3C4D65) : Color(0xFFC4D0E3);
  static Color get textMuted =>
      AppSettingsService.isLight ? Color(0xFF586B85) : Color(0xFF95A6BF);
  static const Color textInverse = Color(0xFF07121E);

  static const Color success = Color(0xFF67E0B1);
  static const Color warning = Color(0xFFFFC96B);
  static const Color error = Color(0xFFFF7F87);
  static const Color info = Color(0xFF77AFFF);

  static Color get divider =>
      AppSettingsService.isLight ? Color(0xFFCCD6E4) : Color(0xFF2A3952);
  static const Color shadow = Color(0x1A000000);
}

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF67E0B1), Color(0xFF77AFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get surface => LinearGradient(
    colors: [AppColors.surfaceBright, AppColors.surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glass = LinearGradient(
    colors: [Color(0x3DFFFFFF), Color(0x1AFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient muscleChest = LinearGradient(
    colors: [Color(0xFF00FF87), Color(0xFF00B36E)],
  );
  static const LinearGradient muscleBack = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0099B3)],
  );
  static const LinearGradient muscleLegs = LinearGradient(
    colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
  );
  static const LinearGradient muscleShoulders = LinearGradient(
    colors: [Color(0xFFFF006E), Color(0xFFD5006E)],
  );
  static const LinearGradient muscleArms = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
  );
  static const LinearGradient muscleCore = LinearGradient(
    colors: [Color(0xFFFF4757), Color(0xFFFF6B8B)],
  );
}

class AppTextTheme {
  static const String font = 'BeVietnamPro';

  static TextStyle get displayLarge => TextStyle(
    fontFamily: font,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
    height: 1.45,
  );
  static TextStyle get displayMedium => TextStyle(
    fontFamily: font,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
    height: 1.45,
  );
  static TextStyle get headlineLarge => TextStyle(
    fontFamily: font,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.45,
  );
  static TextStyle get headlineMedium => TextStyle(
    fontFamily: font,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.5,
  );
  static TextStyle get titleLarge => TextStyle(
    fontFamily: font,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
    height: 1.5,
  );
  static TextStyle get titleMedium => TextStyle(
    fontFamily: font,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
    height: 1.5,
  );
  static TextStyle get bodyLarge => TextStyle(
    fontFamily: font,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  static TextStyle get bodyMedium => TextStyle(
    fontFamily: font,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.6,
  );
  static TextStyle get bodySmall => TextStyle(
    fontFamily: font,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );
  static TextStyle get labelLarge => TextStyle(
    fontFamily: font,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
    height: 1.4,
  );
  static TextStyle get labelMedium => TextStyle(
    fontFamily: font,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
    height: 1.4,
  );
  static TextStyle get caption => TextStyle(
    fontFamily: font,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    letterSpacing: 0.2,
    height: 1.4,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTextTheme.font,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryDark,
        brightness: Brightness.light,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: Color(0xFFF4F7FA),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFF4F7FA),
        foregroundColor: Color(0xFF111827),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTextTheme.font,

      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.textInverse,
        onSecondary: AppColors.textInverse,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textPrimary,
        brightness: Brightness.dark,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        scrolledUnderElevation: 0,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(
          fontFamily: AppTextTheme.font,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppTextTheme.font,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textInverse,
          disabledBackgroundColor: AppColors.divider,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontFamily: AppTextTheme.font,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
          fontFamily: AppTextTheme.font,
          fontSize: 14,
          color: AppColors.textMuted,
        ),
        labelStyle: TextStyle(
          fontFamily: AppTextTheme.font,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        space: 1,
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: TextStyle(
          fontFamily: AppTextTheme.font,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
