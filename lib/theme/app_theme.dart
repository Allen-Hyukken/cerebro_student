import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6B6FC5);
  static const primaryLight = Color(0xFFB8BBE8);
  static const background = Color(0xFFEAEBF5);
  static const cardBg = Color(0xFFD0D3EE);
  static const darkCard = Color(0xFF4A4E9A);
  static const questionCard = Color(0xFF5C5FA8);
  static const confirm = Color(0xFFFF3B6B);
  static const white = Colors.white;
  static const textDark = Color(0xFF2C2C54);
  static const codeCard = Color(0xFF3A3D6B);
  static const correct = Color(0xFF4CAF50);
  static const wrong = Color(0xFFE53935);
}

final appTheme = ThemeData(
  fontFamily: 'Roboto',
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.confirm,
    surface: AppColors.background,
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
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
);
