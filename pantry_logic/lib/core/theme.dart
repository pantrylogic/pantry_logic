import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Font helper ─────────────────────────────────────────────────────────────
//
// Wraps GoogleFonts.nunitoSans and adds a system-font fallback chain so Flutter
// never falls through to Noto (which may not be installed), eliminating the
// "Could not find a set of Noto fonts" warning.

/// Nunito Sans with a system-font fallback chain.
/// Use this instead of GoogleFonts.nunitoSans() throughout the app.
TextStyle nsSans({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  TextDecoration? decoration,
  Color? decorationColor,
}) =>
    GoogleFonts.nunitoSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: decorationColor,
    ).copyWith(
      fontFamilyFallback: const [
        'NotoColorEmoji',
        'Roboto',
        'Segoe UI',
        'sans-serif',
      ],
    );

// ─── Brand colours ───────────────────────────────────────────────────────────

class AppColors {
  // Light mode
  static const Color primary = Color(0xFF2D5A27);
  static const Color primaryDark = Color(0xFF1E3D1A);
  static const Color secondary = Color(0xFF7A9E77);
  static const Color accentLight = Color(0xFFC5D8C2);
  static const Color accentSoft = Color(0xFFD4E2A5);
  static const Color background = Color(0xFFF7F7F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2C2C2C);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFF9E9E9E);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFE8A838);
  static const Color error = Color(0xFFC75450);
  static const Color border = Color(0xFFE8E8E4);

  // Dark mode
  static const Color primaryDm = Color(0xFF7FB87A);
  static const Color primaryDarkDm = Color(0xFF2D5A27);
  static const Color secondaryDm = Color(0xFF5A8A56);
  static const Color accentLightDm = Color(0xFF3A4D38);
  static const Color accentSoftDm = Color(0xFFA3C78F);
  static const Color backgroundDm = Color(0xFF1A1C1A);
  static const Color surfaceDm = Color(0xFF252825);
  static const Color textPrimaryDm = Color(0xFFE8E8E4);
  static const Color textSecondaryDm = Color(0xFF9EAA9C);
  static const Color textMutedDm = Color(0xFF6B736B);
  static const Color successDm = Color(0xFF66BB6A);
  static const Color warningDm = Color(0xFFFFAB40);
  static const Color errorDm = Color(0xFFEF5350);
  static const Color borderDm = Color(0xFF3A3D3A);
}

// ─── App theme ────────────────────────────────────────────────────────────────

class AppTheme {
  static TextTheme _buildTextTheme(
    Color primary,
    Color secondary,
    Color muted,
  ) {
    return TextTheme(
      // Screen headers 24px Bold
      displayLarge: nsSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.4,
      ),
      // Section headers 18px SemiBold
      headlineMedium: nsSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.4,
      ),
      // List item names 16px Medium
      bodyLarge: nsSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primary,
        height: 1.5,
      ),
      // Secondary text 14px Regular
      bodyMedium: nsSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.4,
      ),
      // Small labels 12px Medium
      bodySmall: nsSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: muted,
        height: 1.4,
      ),
      labelLarge: nsSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
    );
  }

  static InputDecorationTheme _buildInputTheme(
    Color surface,
    Color border,
    Color primary,
    Color muted,
    Color error,
  ) {
    return InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error, width: 1.5),
      ),
      hintStyle: nsSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      errorStyle: nsSans(fontSize: 12),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme(
    Color bg,
    Color fg,
  ) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: nsSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        elevation: 0,
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(
    Color fg,
    Color border,
  ) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border, width: 2),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: nsSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
    );
  }

  // ─── Light ──────────────────────────────────────────────────────────────────

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: _buildTextTheme(
      AppColors.textPrimary,
      AppColors.textSecondary,
      AppColors.textMuted,
    ),
    inputDecorationTheme: _buildInputTheme(
      AppColors.surface,
      AppColors.border,
      AppColors.primary,
      AppColors.textMuted,
      AppColors.error,
    ),
    elevatedButtonTheme: _buildElevatedButtonTheme(
      AppColors.primary,
      Colors.white,
    ),
    outlinedButtonTheme: _buildOutlinedButtonTheme(
      AppColors.textSecondary,
      AppColors.border,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: nsSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
  );

  // ─── Dark ───────────────────────────────────────────────────────────────────

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryDm,
      secondary: AppColors.secondaryDm,
      surface: AppColors.surfaceDm,
      error: AppColors.errorDm,
      onPrimary: AppColors.backgroundDm,
      onSecondary: AppColors.backgroundDm,
      onSurface: AppColors.textPrimaryDm,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDm,
    textTheme: _buildTextTheme(
      AppColors.textPrimaryDm,
      AppColors.textSecondaryDm,
      AppColors.textMutedDm,
    ),
    inputDecorationTheme: _buildInputTheme(
      AppColors.surfaceDm,
      AppColors.borderDm,
      AppColors.primaryDm,
      AppColors.textMutedDm,
      AppColors.errorDm,
    ),
    elevatedButtonTheme: _buildElevatedButtonTheme(
      AppColors.primaryDm,
      AppColors.backgroundDm,
    ),
    outlinedButtonTheme: _buildOutlinedButtonTheme(
      AppColors.textSecondaryDm,
      AppColors.borderDm,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceDm,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderDm, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.backgroundDm,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: nsSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryDm,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimaryDm),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderDm,
      thickness: 1,
      space: 1,
    ),
  );
}
