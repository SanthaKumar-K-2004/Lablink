import 'package:flutter/material.dart';

class AppShadows {
  // Subtle shadow
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color.fromARGB(13, 0, 0, 0), // rgba(0,0,0,0.05)
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  // Small shadow
  static const List<BoxShadow> small = [
    BoxShadow(
      color: Color.fromARGB(26, 0, 0, 0), // rgba(0,0,0,0.1)
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color.fromARGB(15, 0, 0, 0), // rgba(0,0,0,0.06)
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -1,
    ),
  ];

  // Medium shadow
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color.fromARGB(26, 0, 0, 0), // rgba(0,0,0,0.1)
      offset: Offset(0, 10),
      blurRadius: 15,
      spreadRadius: -3,
    ),
    BoxShadow(
      color: Color.fromARGB(13, 0, 0, 0), // rgba(0,0,0,0.05)
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -2,
    ),
  ];

  // Large shadow
  static const List<BoxShadow> large = [
    BoxShadow(
      color: Color.fromARGB(26, 0, 0, 0), // rgba(0,0,0,0.1)
      offset: Offset(0, 20),
      blurRadius: 25,
      spreadRadius: -5,
    ),
    BoxShadow(
      color: Color.fromARGB(10, 0, 0, 0), // rgba(0,0,0,0.04)
      offset: Offset(0, 10),
      blurRadius: 10,
      spreadRadius: -5,
    ),
  ];

  // Extra shadow
  static const List<BoxShadow> extra = [
    BoxShadow(
      color: Color.fromARGB(64, 0, 0, 0), // rgba(0,0,0,0.25)
      offset: Offset(0, 25),
      blurRadius: 50,
      spreadRadius: -12,
    ),
  ];

  // No shadow
  static const List<BoxShadow> none = [];
}
