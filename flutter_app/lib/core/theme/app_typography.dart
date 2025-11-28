import 'package:flutter/material.dart';

class AppTypography {
  // Font Family
  static const String primaryFont = 'Inter';

  // Font Sizes (px)
  static const double caption = 12;
  static const double body = 14;
  static const double subtitle = 16;
  static const double title = 18;
  static const double heading3 = 20;
  static const double heading2 = 24;
  static const double heading1 = 32;

  // Font Weights
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // Line Heights
  static const double lineHeightTight = 1.4;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.6;
  static const double lineHeightLoose = 1.8;

  // Letter Spacing
  static const double letterSpacingNormal = 0;
  static const double letterSpacingWide = 0.5;

  // Text Styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: heading1,
    fontWeight: bold,
    fontFamily: primaryFont,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: heading2,
    fontWeight: bold,
    fontFamily: primaryFont,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: heading3,
    fontWeight: semibold,
    fontFamily: primaryFont,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: title,
    fontWeight: semibold,
    fontFamily: primaryFont,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: subtitle,
    fontWeight: semibold,
    fontFamily: primaryFont,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: body,
    fontWeight: semibold,
    fontFamily: primaryFont,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: subtitle,
    fontWeight: regular,
    fontFamily: primaryFont,
    height: lineHeightRelaxed,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: body,
    fontWeight: regular,
    fontFamily: primaryFont,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: caption,
    fontWeight: regular,
    fontFamily: primaryFont,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: body,
    fontWeight: medium,
    fontFamily: primaryFont,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: caption,
    fontWeight: medium,
    fontFamily: primaryFont,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: caption,
    fontWeight: semibold,
    fontFamily: primaryFont,
    height: lineHeightTight,
    letterSpacing: letterSpacingWide,
  );
}
