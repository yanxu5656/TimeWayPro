import 'package:flutter/material.dart';

class AppAtmosphere {
  const AppAtmosphere({
    required this.background,
    required this.backgroundElevated,
    required this.orbs,
    required this.glassFill,
    required this.glassBorder,
    required this.highlight,
    required this.glow,
    required this.dialogFill,
    required this.blurSigma,
  });

  final Color background;
  final Color backgroundElevated;
  final List<Color> orbs;
  final Color glassFill;
  final Color glassBorder;
  final Color highlight;
  final Color glow;
  final Color dialogFill;
  final double blurSigma;

  static const AppAtmosphere glass = AppAtmosphere(
    background: Color(0xFF050914),
    backgroundElevated: Color(0xFF0D1630),
    orbs: <Color>[
      Color(0xFF245BFF),
      Color(0xFF8438E8),
      Color(0xFFE34B88),
      Color(0xFF00A99D),
    ],
    glassFill: Color(0xFF17243B),
    glassBorder: Color(0xFFBFD2FF),
    highlight: Color(0xFFF4F7FF),
    glow: Color(0xFF617DFF),
    dialogFill: Color(0xFF101A2D),
    blurSigma: 24,
  );
}
