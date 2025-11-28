import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF0891B2); // Teal
  static const Color primaryDark = Color(0xFF065F73);
  static const Color primaryLight = Color(0xFF06D6D0);

  // Secondary Colors
  static const Color secondary = Color(0xFF1E3A8A); // Navy
  static const Color secondaryDark = Color(0xFF1E40AF);
  static const Color secondaryLight = Color(0xFF3B82F6);

  // Success Colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color successDark = Color(0xFF059669);

  // Warning Colors
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningDark = Color(0xFFD97706);

  // Error Colors
  static const Color error = Color(0xFFDC2626); // Rose
  static const Color errorDark = Color(0xFF991B1B);

  // Info Colors
  static const Color info = Color(0xFF0EA5E9); // Sky

  // Neutral Colors
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color neutral200 = Color(0xFFE2E8F0);
  static const Color neutral400 = Color(0xFF94A3B8);
  static const Color neutral600 = Color(0xFF475569);
  static const Color neutral700 = Color(0xFF334155);
  static const Color neutral900 = Color(0xFF0F172A);

  // Semantic Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Status Colors - Badges
  static const Color statusGreen = success;
  static const Color statusYellow = warning;
  static const Color statusOrange = Color(0xFFEA580C);
  static const Color statusRed = error;
  static const Color statusGray = Color(0xFF64748B);
  static const Color statusBlue = info;

  // Text Colors
  static const Color textPrimary = neutral900;
  static const Color textSecondary = neutral600;
  static const Color textTertiary = neutral400;
  static const Color textHint = neutral400;

  // Background Colors
  static const Color backgroundPrimary = white;
  static const Color backgroundSecondary = neutral50;
  static const Color backgroundTertiary = neutral100;

  // Border Colors
  static const Color borderLight = neutral200;
  static const Color borderDefault = neutral200;

  // Overlay Colors
  static const Color overlayDark = Color(0x80000000); // 50% opacity black
  static const Color overlayLight = Color(0x4D000000); // 30% opacity black

  // Disabled State
  static const Color disabled = neutral400;
}
