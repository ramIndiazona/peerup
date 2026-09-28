import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF5B5FF7);
  static const Color secondary = Color(0xFF7C4DFF);
  static const Color accent = Color(0xFF00E5C3);
  static const Color warning = Color(0xFFFFB74D);
  static const Color danger = Color(0xFFEF5350);
  static const Color success = Color(0xFF66BB6A);

  static const Color bgLight = Color(0xFFF7F7FF);
  static const Color surfaceLight = Colors.white;

  static const Color bgDark = Color(0xFF0F1020);
  static const Color surfaceDark = Color(0xFF1A1B2E);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B5FF7), Color(0xFF9C4DFF)],
  );
}
