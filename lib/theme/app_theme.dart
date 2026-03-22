import 'package:flutter/material.dart';

// ── Brand colors (always the same in light and dark) ─────────────────────────
class AppColors {
  static const Color primary      = Color(0xFF6B6FC5);
  static const Color primaryLight = Color(0xFF9B9FE0);
  static const Color darkCard     = Color(0xFF4A4E9A);
  static const Color correct      = Color(0xFF4CAF50);
  static const Color wrong        = Color(0xFFE53935);
  static const Color confirm      = Color(0xFFFF3B6B);
  static const Color codeCard     = Color(0xFF1E1E2E);

  // Light mode colors
  static const Color background   = Color(0xFFEAEBF5);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color textDark     = Color(0xFF2D2D3A);
  static const Color cardBg       = Color(0xFFD0D3EE);

  // Dark mode colors
  static const Color darkBg       = Color(0xFF0F0F1A);
  static const Color darkSurface  = Color(0xFF1A1A2E);
  static const Color darkCard2    = Color(0xFF222236);
  static const Color darkInput    = Color(0xFF2A2A42);
  static const Color darkText     = Color(0xFFE8E8F5);
  static const Color darkSubText  = Color(0xFF9898B8);
  static const Color darkDivider  = Color(0xFF2A2A42);
}

// ── Theme-aware color helper ──────────────────────────────────────────────────
// Use this everywhere instead of hardcoded AppColors
class TC {
  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkBg : AppColors.background;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface : AppColors.white;

  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkCard2 : AppColors.cardBg;

  static Color input(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkInput : AppColors.white;

  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkText : AppColors.textDark;

  static Color subText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSubText : Colors.grey;

  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkDivider : Colors.grey.shade200;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}

// ── Light theme ───────────────────────────────────────────────────────────────
final lightTheme = ThemeData(
  brightness: Brightness.light,
  fontFamily: 'Roboto',
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.confirm,
    surface: AppColors.white,
  ),
  cardColor: AppColors.white,
  dividerColor: Color(0xFFE0E0E0),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.textDark,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  dialogBackgroundColor: AppColors.white,
  bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.white),
);

// ── Dark theme ────────────────────────────────────────────────────────────────
final darkTheme = ThemeData(
  brightness: Brightness.dark,
  fontFamily: 'Roboto',
  scaffoldBackgroundColor: AppColors.darkBg,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.confirm,
    surface: AppColors.darkSurface,
  ),
  cardColor: AppColors.darkCard2,
  dividerColor: AppColors.darkDivider,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.darkBg,
    foregroundColor: AppColors.darkText,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkInput,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: TextStyle(color: AppColors.darkSubText),
  ),
  dialogBackgroundColor: AppColors.darkSurface,
  bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.darkSurface),
  textTheme: const TextTheme(
    bodyLarge:  TextStyle(color: AppColors.darkText),
    bodyMedium: TextStyle(color: AppColors.darkText),
    bodySmall:  TextStyle(color: AppColors.darkSubText),
  ),
);