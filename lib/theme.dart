import 'package:flutter/material.dart';

/// "Night sky" palette: near-black space, cold star-white, an exoplanet green,
/// and warm cinnamon / sunflower amber for the logo.
abstract final class Sky {
  static const space = Color(0xFF04050B);
  static const star = Color(0xFFEAF1FF);
  static const dust = Color(0xFF8A94B5);
  static const planet = Color(0xFF63E6A1);
  static const planetDeep = Color(0xFF0F7A54);
  static const petal = Color(0xFFFFD98A);
  static const bun = Color(0xFFE9974F);
  static const bunDeep = Color(0xFF9A5426);
  static const icing = Color(0xFFFFF1D0);

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: planet,
      brightness: Brightness.dark,
    ).copyWith(surface: space);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: space,
      fontFamily: 'Roboto',
    );
  }
}
