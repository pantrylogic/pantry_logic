import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Font helper ─────────────────────────────────────────────────────────────
//
// Wraps GoogleFonts.nunitoSans and adds a system-font fallback chain so Flutter
// never falls through to Noto (which may not be installed), eliminating the
// "Could not find a set of Noto fonts" warning.

/// Font fallback chain appended to every Nunito Sans style.
const List<String> kFontFallback = [
  'NotoColorEmoji',
  'Roboto',
  'Segoe UI',
  'sans-serif',
];

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
    ).copyWith(fontFamilyFallback: kFontFallback);

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
  // 6.23:1 on background, 6.69:1 on surface.
  static const Color textSecondary = Color(0xFF5C5C5C);
  // Informational secondary text. 4.75:1 on background, 5.10:1 on surface.
  static const Color textMuted = Color(0xFF6E6E6E);
  // Placeholders only — intentionally softer than textMuted.
  static const Color hint = Color(0xFF9E9E9E);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFE8A838);
  // Text-safe status colours (≥4.5:1 on background and surface).
  static const Color successText = Color(0xFF2E7D32);
  static const Color warningText = Color(0xFF9A6100);
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
  // 5.81:1 on background, 5.05:1 on surface.
  static const Color textMutedDm = Color(0xFF8F998E);
  static const Color hintDm = Color(0xFF6B736B);
  static const Color successDm = Color(0xFF66BB6A);
  static const Color warningDm = Color(0xFFFFAB40);
  // Dark status colours already clear 4.5:1 on dark surfaces.
  static const Color successTextDm = successDm;
  static const Color warningTextDm = warningDm;
  static const Color errorDm = Color(0xFFEF5350);
  static const Color borderDm = Color(0xFF3A3D3A);
}

/// Brightness-resolved palette. Prefer this over repeating
/// `isDark ? AppColors.xDm : AppColors.x` in widgets.
class AppPalette {
  final bool isDark;
  const AppPalette(this.isDark);

  factory AppPalette.of(BuildContext context) =>
      AppPalette(Theme.of(context).brightness == Brightness.dark);

  Color get primary => isDark ? AppColors.primaryDm : AppColors.primary;
  Color get onPrimary => isDark ? AppColors.backgroundDm : AppColors.surface;
  Color get accentLight =>
      isDark ? AppColors.accentLightDm : AppColors.accentLight;
  Color get accentSoft => isDark ? AppColors.accentSoftDm : AppColors.accentSoft;
  Color get background =>
      isDark ? AppColors.backgroundDm : AppColors.background;
  Color get surface => isDark ? AppColors.surfaceDm : AppColors.surface;
  Color get textPrimary =>
      isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
  Color get textSecondary =>
      isDark ? AppColors.textSecondaryDm : AppColors.textSecondary;
  Color get textMuted => isDark ? AppColors.textMutedDm : AppColors.textMuted;
  Color get hint => isDark ? AppColors.hintDm : AppColors.hint;
  Color get success => isDark ? AppColors.successDm : AppColors.success;
  Color get warning => isDark ? AppColors.warningDm : AppColors.warning;
  Color get successText =>
      isDark ? AppColors.successTextDm : AppColors.successText;
  Color get warningText =>
      isDark ? AppColors.warningTextDm : AppColors.warningText;
  Color get error => isDark ? AppColors.errorDm : AppColors.error;
  Color get border => isDark ? AppColors.borderDm : AppColors.border;
}

// ─── App theme ────────────────────────────────────────────────────────────────

class AppTheme {
  /// Full Material 3 type scale in Nunito Sans, so no widget falls back to
  /// Roboto. Each style names its weight explicitly because google_fonts
  /// registers one font family per weight.
  static TextTheme _buildTextTheme(
    Color primary,
    Color secondary,
    Color muted,
  ) {
    TextStyle s(double size, FontWeight weight, Color color,
            {double? height, double? letterSpacing}) =>
        nsSans(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        );

    return TextTheme(
      // Screen headers 24px Bold
      displayLarge: s(24, FontWeight.w700, primary, height: 1.4),
      displayMedium: s(22, FontWeight.w700, primary, height: 1.3),
      displaySmall: s(20, FontWeight.w700, primary, height: 1.3),
      headlineLarge: s(22, FontWeight.w700, primary, height: 1.3),
      // Section headers 18px SemiBold
      headlineMedium: s(18, FontWeight.w600, primary, height: 1.4),
      headlineSmall: s(17, FontWeight.w700, primary, height: 1.3),
      titleLarge: s(20, FontWeight.w700, primary, height: 1.3),
      titleMedium: s(17, FontWeight.w700, primary, height: 1.3),
      titleSmall: s(15, FontWeight.w600, primary, height: 1.3),
      // List item names 16px Medium
      bodyLarge: s(16, FontWeight.w500, primary, height: 1.5),
      // Secondary text 14px Regular
      bodyMedium: s(14, FontWeight.w400, secondary, height: 1.4),
      // Small labels 12px Medium
      bodySmall: s(12, FontWeight.w500, muted, height: 1.4),
      labelLarge: s(15, FontWeight.w700, primary),
      labelMedium: s(13, FontWeight.w600, secondary),
      labelSmall: s(11, FontWeight.w700, muted, letterSpacing: 0.8),
    );
  }

  static InputDecorationTheme _buildInputTheme(
    Color surface,
    Color border,
    Color primary,
    Color secondary,
    Color hint,
    Color error,
  ) {
    return InputDecorationTheme(
      filled: true,
      fillColor: surface,
      // Single source of truth for field padding — widgets should not
      // override this, so every field and add bar lines up.
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
        color: hint,
      ),
      labelStyle: nsSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      floatingLabelStyle: nsSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      errorStyle: nsSans(fontSize: 12, color: error),
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

  static FilledButtonThemeData _buildFilledButtonTheme(Color bg, Color fg) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: nsSans(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme(Color fg) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: fg,
        textStyle: nsSans(fontSize: 14, fontWeight: FontWeight.w600),
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

  static ChipThemeData _buildChipTheme(AppPalette p) {
    return ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.accentLight,
      disabledColor: p.border,
      checkmarkColor: p.primary,
      showCheckmark: false,
      side: BorderSide(color: p.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      labelStyle: nsSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: p.textSecondary,
      ),
      secondaryLabelStyle: nsSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: p.primary,
      ),
    );
  }

  static SnackBarThemeData _buildSnackBarTheme(AppPalette p) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.isDark ? AppColors.textPrimaryDm : AppColors.textPrimary,
      contentTextStyle: nsSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: p.isDark ? AppColors.backgroundDm : AppColors.surface,
      ),
      actionTextColor: p.isDark ? AppColors.primary : AppColors.accentSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    );
  }

  static BottomSheetThemeData _buildBottomSheetTheme(AppPalette p) {
    return BottomSheetThemeData(
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  static ThemeData _build(AppPalette p) {
    final isDark = p.isDark;
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: nsSans().fontFamily,
      fontFamilyFallback: kFontFallback,
      colorScheme: isDark
          ? const ColorScheme.dark(
              primary: AppColors.primaryDm,
              secondary: AppColors.secondaryDm,
              surface: AppColors.surfaceDm,
              error: AppColors.errorDm,
              onPrimary: AppColors.backgroundDm,
              onSecondary: AppColors.backgroundDm,
              onSurface: AppColors.textPrimaryDm,
              onSurfaceVariant: AppColors.textSecondaryDm,
              outline: AppColors.borderDm,
              onError: Colors.white,
            )
          : const ColorScheme.light(
              primary: AppColors.primary,
              secondary: AppColors.secondary,
              surface: AppColors.surface,
              error: AppColors.error,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: AppColors.textPrimary,
              onSurfaceVariant: AppColors.textSecondary,
              outline: AppColors.border,
              onError: Colors.white,
            ),
      scaffoldBackgroundColor: p.background,
      textTheme: _buildTextTheme(p.textPrimary, p.textSecondary, p.textMuted),
      inputDecorationTheme: _buildInputTheme(
        p.surface,
        p.border,
        p.primary,
        p.textSecondary,
        p.hint,
        p.error,
      ),
      elevatedButtonTheme: _buildElevatedButtonTheme(p.primary, p.onPrimary),
      filledButtonTheme: _buildFilledButtonTheme(p.primary, p.onPrimary),
      textButtonTheme: _buildTextButtonTheme(p.primary),
      outlinedButtonTheme: _buildOutlinedButtonTheme(p.textSecondary, p.border),
      chipTheme: _buildChipTheme(p),
      snackBarTheme: _buildSnackBarTheme(p),
      bottomSheetTheme: _buildBottomSheetTheme(p),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: nsSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
        ),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get light => _build(const AppPalette(false));

  static ThemeData get dark => _build(const AppPalette(true));
}
