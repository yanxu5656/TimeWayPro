import 'package:flutter/material.dart';

class AppAtmosphere {
  const AppAtmosphere({
    required this.background,
    required this.orbs,
    required this.glassFill,
    required this.glassBorder,
    required this.highlight,
    required this.glow,
    required this.dialogFill,
    required this.blurSigma,
  });

  final Color background;
  final List<Color> orbs;
  final Color glassFill;
  final Color glassBorder;
  final Color highlight;
  final Color glow;
  final Color dialogFill;
  final double blurSigma;

  static const AppAtmosphere glass = AppAtmosphere(
    background: Color(0xFFF1F5FF),
    orbs: <Color>[
      Color(0xFF9CC8FF),
      Color(0xFFD4B5FF),
      Color(0xFFFFC9BC),
      Color(0xFFA8E8D6),
    ],
    glassFill: Color(0xB8FFFFFF),
    glassBorder: Color(0xA6FFFFFF),
    highlight: Color(0xFFFFFFFF),
    glow: Color(0x6689AEFF),
    dialogFill: Color(0xEFF7FAFF),
    blurSigma: 18,
  );
}
