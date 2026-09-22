import 'package:flutter/material.dart';

/// The raw Showdist palette. Prefer [Palette] (theme-aware) in UI code —
/// these are the source hues it's built from, plus [Hue.neon], which is used
/// directly for the camera overlay in both themes.
abstract final class Hue {
  static const neon = Color(0xFFFF5F1F);
  static const bright = Color(0xFFFF7A33);
  static const burnt = Color(0xFFB8430F);
  static const deep = Color(0xFF7A2A06);
  static const ink = Color(0xFF111111);
  static const black = Color(0xFF000000);
}

/// JetBrains Mono, bundled under `assets/fonts/` (OFL-1.1 licensed — see
/// `assets/fonts/JetBrainsMono/OFL.txt`). It's the only font used app-wide.
const showdistFontFamily = 'JetBrains Mono';

/// JetBrains Mono's zero is dotted by default; the 'zero' OpenType feature
/// (Flutter's [FontFeature.slashedZero]) switches it to a slashed zero so
/// 0/O and 1/l/I stay unmistakable. Applied to every text style in the app.
const showdistFontFeatures = [FontFeature.slashedZero()];

/// Theme-aware colors, reached via `Palette.of(context)`. Every text/background
/// combination used here is checked against WCAG 4.5:1:
///   Dark:  white on Black                    21:1   Neon on Black       6.9:1
///   Light: #262626 on #9E9E9E (background)   5.7:1   white on #616161  6.2:1
///          white on #757575 (card)           4.6:1
/// A medium grey background (#9E9E9E) is close to the worst case for text
/// contrast against both black and white, which is why Light's numbers have
/// less headroom than Dark's — and why `emphasis` (Deep, a dark muted
/// orange) only clears 3:1 there, enough for icons/graphics but not body
/// text, so nothing in the app sets emphasis as a text color in Light.
/// (Secondary/"muted" tones are solid colors, not opacity, so they can't drift
/// below the ratio a themed screen was checked at; on Light's bar/card,
/// white has so little headroom to begin with that "muted" is just white
/// again — de-emphasis there comes from size/weight only.)
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.background,
    required this.bar,
    required this.card,
    required this.onBase,
    required this.onBaseMuted,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.emphasis,
    required this.alertIcon,
    required this.alertOnCard,
  });

  /// Main scaffold / camera backdrop.
  final Color background;

  /// App bar / header strip.
  final Color bar;

  /// Sheets, dialogs, popup menus.
  final Color card;

  /// Primary text/icon on [background].
  final Color onBase;

  /// Secondary text/icon on [background] (still 4.5:1 solid, not alpha).
  final Color onBaseMuted;

  /// Primary text/icon on [bar] or [card].
  final Color onSurface;

  /// Secondary text/icon on [bar] or [card].
  final Color onSurfaceMuted;

  /// Accent for active/selected/lit state, drawn on [background]. Neon on the
  /// dark theme's black; Burnt (a deeper, muted orange) on the light theme's
  /// grey, since Neon itself has too little contrast against any light
  /// background to use as text/icon color.
  final Color emphasis;

  /// Destructive-action icon tint on [background] (decorative; text stays
  /// [onBase]/[onSurface] so it's never a fresh color to re-check).
  final Color alertIcon;

  /// Destructive-action tint on [card] (e.g. a delete confirmation's button).
  final Color alertOnCard;

  static const dark = Palette(
    background: Hue.black,
    bar: Hue.black,
    card: Color(0xFF12141C),
    onBase: Colors.white,
    onBaseMuted: Color(0xFFB8B8B8),
    onSurface: Colors.white,
    onSurfaceMuted: Color(0xFFB8B8B8),
    emphasis: Hue.neon,
    alertIcon: Color(0xFFFF6B57),
    alertOnCard: Color(0xFFFF6B57),
  );

  // A calmer light theme: light grey rather than a full orange field, dark
  // grey text (not harsh pure black), and Burnt — a deeper, muted orange —
  // standing in for the accent, since Neon has almost no contrast against a
  // light background of any kind.
  static const light = Palette(
    background: Color(0xFF9E9E9E),
    bar: Color(0xFF616161),
    card: Color(0xFF757575),
    onBase: Color(0xFF262626),
    onBaseMuted: Color(0xFF333333),
    onSurface: Colors.white,
    onSurfaceMuted: Colors.white,
    emphasis: Hue.deep,
    alertIcon: Color(0xFFB3261E),
    alertOnCard: Colors.white,
  );

  static Palette of(BuildContext context) => Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith({
    Color? background,
    Color? bar,
    Color? card,
    Color? onBase,
    Color? onBaseMuted,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? emphasis,
    Color? alertIcon,
    Color? alertOnCard,
  }) {
    return Palette(
      background: background ?? this.background,
      bar: bar ?? this.bar,
      card: card ?? this.card,
      onBase: onBase ?? this.onBase,
      onBaseMuted: onBaseMuted ?? this.onBaseMuted,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      emphasis: emphasis ?? this.emphasis,
      alertIcon: alertIcon ?? this.alertIcon,
      alertOnCard: alertOnCard ?? this.alertOnCard,
    );
  }

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    return Palette(
      background: Color.lerp(background, other.background, t)!,
      bar: Color.lerp(bar, other.bar, t)!,
      card: Color.lerp(card, other.card, t)!,
      onBase: Color.lerp(onBase, other.onBase, t)!,
      onBaseMuted: Color.lerp(onBaseMuted, other.onBaseMuted, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      emphasis: Color.lerp(emphasis, other.emphasis, t)!,
      alertIcon: Color.lerp(alertIcon, other.alertIcon, t)!,
      alertOnCard: Color.lerp(alertOnCard, other.alertOnCard, t)!,
    );
  }
}

/// Builds the light or dark [ThemeData], with JetBrains Mono (and its slashed
/// zero) applied to every text-theme role so it reaches plain `TextStyle`s
/// that don't set their own `fontFamily`/`fontFeatures` (see [TextStyle.merge]).
ThemeData buildTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Hue.neon,
    brightness: brightness,
  ).copyWith(surface: palette.card, primary: palette.emphasis);

  final baseTextTheme = (brightness == Brightness.dark ? Typography.whiteMountainView : Typography.blackMountainView)
      .apply(fontFamily: showdistFontFamily);
  final textTheme = _withFontFeatures(baseTextTheme);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    fontFamily: showdistFontFamily,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    extensions: [palette],
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
