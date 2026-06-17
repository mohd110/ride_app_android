import 'package:flutter/material.dart';

/// Design tokens extracted from Figma file nxsa7j2xQLxJEqZ1hx7z6u
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFDB3416);
  static const Color primaryDark = Color(0xFF281714);
  static const Color primaryLight = Color(0xFFFFB4A5);

  static const Color background = Color(0xFFFFF8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFFFF0EE);
  static const Color surfaceAccent = Color(0xFFFFE9E5);

  static const Color border = Color(0xFFFFE2DC);
  static const Color borderLight = Color(0xFFFBDCD6);

  static const Color textPrimary = Color(0xFF1E1E1E);
  static const Color textSecondary = Color(0xFF6B5E5A);
  static const Color textMuted = Color(0xFF9E8E88);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFFACC15);
  static const Color error = Color(0xFFDB3416);

  static const Color navInactive = Color(0xFF9E8E88);
  static const Color offlineBadge = Color(0xFFE5E2E1);
  static const Color goOnlineButton = Color(0xFF1E1E1E);

  static const Color chartBar = Color(0xFFF2D3CD);
  static const Color chartBarActive = Color(0xFFDB3416);

  static const LinearGradient profileGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDB3416), Color(0xFFB82A10)],
  );
}
