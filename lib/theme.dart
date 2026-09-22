import 'package:flutter/material.dart';

/// Showdist's fixed, app-wide colour palette — drawn from Sanzo Wada's
/// *A Dictionary of Color Combinations*. There is no light/dark variant: the
/// app always looks the same, regardless of the system theme setting. Every
/// screen is built from these eight colours only.
///
/// Roles (see call sites for exact usage):
/// - [darkTyrianBlue] — main background (landing, settings, licences).
/// - [olympicBlue] — secondary accents (selection/toggle state).
/// - [lightMauve] — the wordmark and large headings.
/// - [darkCitrine] — small decorative details (ruler ticks, the app icon).
/// - [peachRed] — actions: the capture button, placed measurement points.
/// - [seaGreen] — live/tracking elements: reticle dots, the leveler liquid.
/// - [warmGray] — the leveler's background, and muted/secondary text.
/// - [white] — body text, live numbers, the reticle's centre dot.
///
/// Every text pairing actually used in the app clears WCAG's 4.5:1 for
/// normal text: white on [darkTyrianBlue] is 12.8:1, [warmGray] on
/// [darkTyrianBlue] is 5.0:1, and [darkTyrianBlue] on [warmGray] (the
/// leveler's own text) is 5.0:1. The saturated accents ([olympicBlue],
/// [lightMauve], [darkCitrine], [peachRed]) sit closer to 3.2-3.8:1 against
/// [darkTyrianBlue] — enough for icons, strokes, and large text (which is
/// all they're ever used for; small running text always stays white or
/// warmGray). [seaGreen] is the one accent strong enough for small text too,
/// at 4.9:1.
abstract final class Palette {
  static const darkTyrianBlue = Color(0xFF12354E);
  static const olympicBlue = Color(0xFF5A82B3);
  static const lightMauve = Color(0xFF9A72AA);
  static const darkCitrine = Color(0xFF8B835B);
  static const peachRed = Color(0xFFF15A30);
  static const seaGreen = Color(0xFF00B49B);
  static const warmGray = Color(0xFFA1A39A);
  static const white = Colors.white;
}

/// JetBrains Mono, bundled under `assets/fonts/` (OFL-1.1 licensed — see
/// `assets/fonts/JetBrainsMono/OFL.txt`). It's the only font used app-wide.
const showdistFontFamily = 'JetBrains Mono';

/// JetBrains Mono's zero is dotted by default; the 'zero' OpenType feature
/// (Flutter's [FontFeature.slashedZero]) switches it to a slashed zero so
/// 0/O and 1/l/I stay unmistakable. Applied to every text style in the app.
const showdistFontFeatures = [FontFeature.slashedZero()];

/// Builds the app's one fixed [ThemeData], with JetBrains Mono (and its
/// slashed zero) applied to every text-theme role so it reaches plain
/// `TextStyle`s that don't set their own `fontFamily`/`fontFeatures` (see
/// [TextStyle.merge]).
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.peachRed,
    brightness: Brightness.dark,
  ).copyWith(surface: Palette.darkTyrianBlue, primary: Palette.peachRed);

  final baseTextTheme = Typography.whiteMountainView.apply(fontFamily: showdistFontFamily);
  final textTheme = _withFontFeatures(baseTextTheme);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.darkTyrianBlue,
    fontFamily: showdistFontFamily,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
  );
}

TextTheme _withFontFeatures(TextTheme t) {
  TextStyle? apply(TextStyle? s) => s?.copyWith(fontFeatures: showdistFontFeatures);
  return t.copyWith(
    displayLarge: apply(t.displayLarge),
    displayMedium: apply(t.displayMedium),
    displaySmall: apply(t.displaySmall),
    headlineLarge: apply(t.headlineLarge),
    headlineMedium: apply(t.headlineMedium),
    headlineSmall: apply(t.headlineSmall),
    titleLarge: apply(t.titleLarge),
    titleMedium: apply(t.titleMedium),
    titleSmall: apply(t.titleSmall),
    bodyLarge: apply(t.bodyLarge),
    bodyMedium: apply(t.bodyMedium),
    bodySmall: apply(t.bodySmall),
    labelLarge: apply(t.labelLarge),
    labelMedium: apply(t.labelMedium),
    labelSmall: apply(t.labelSmall),
  );
}
