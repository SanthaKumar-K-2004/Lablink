import 'package:flutter/material.dart';

class AppRadius {
  // Border radius values
  static const double xs = 2; // minimal rounding
  static const double sm = 4; // subtle
  static const double md = 6; // cards
  static const double lg = 8; // buttons
  static const double xl = 12; // large components
  static const double full = 9999; // pills, circles

  // Border radius objects for reuse
  static const Radius radiusXs = Radius.circular(xs);
  static const Radius radiusSm = Radius.circular(sm);
  static const Radius radiusMd = Radius.circular(md);
  static const Radius radiusLg = Radius.circular(lg);
  static const Radius radiusXl = Radius.circular(xl);
  static const Radius radiusFull = Radius.circular(full);

  // BorderRadius objects
  static const BorderRadius borderRadiusXs = BorderRadius.all(radiusXs);
  static const BorderRadius borderRadiusSm = BorderRadius.all(radiusSm);
  static const BorderRadius borderRadiusMd = BorderRadius.all(radiusMd);
  static const BorderRadius borderRadiusLg = BorderRadius.all(radiusLg);
  static const BorderRadius borderRadiusXl = BorderRadius.all(radiusXl);
  static const BorderRadius borderRadiusFull = BorderRadius.all(radiusFull);
}
