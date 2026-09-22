import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The app mark: "SHOW" in white over "DIST" in black, on a flat orange
/// background. Used for the launcher icon (see `tool/generate_icons.dart`)
/// and the small badge on the About screen.
///
/// Sized to fit within [maxWidthFraction] × [maxHeightFraction] of the
/// canvas, whichever is tighter — both lines are the same width (JetBrains
/// Mono is monospaced and both words are 4 letters), so the binding
/// constraint is usually height, not width.
class WordmarkPainter extends CustomPainter {
  const WordmarkPainter({
    this.maxWidthFraction = 0.74,
    this.maxHeightFraction = 0.46,
    this.paintBackground = true,
  });

  final double maxWidthFraction, maxHeightFraction;

  /// False draws the text alone (transparent elsewhere) — for an adaptive
  /// icon's foreground layer or a monochrome/themed icon, where the
  /// background is supplied separately.
  final bool paintBackground;

  static const _top = 'SHOW';
  static const _bottom = 'DIST';
  static const _weight = FontWeight.w800;
  static const _refSize = 100.0;

  TextPainter _line(String text, Color color, double fontSize) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontFamily: showdistFontFamily,
            fontWeight: _weight,
            fontSize: fontSize,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (paintBackground) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Hue.neon);
    }

    final refTop = _line(_top, Colors.white, _refSize);
    final refBottom = _line(_bottom, Colors.black, _refSize);
    final refWidth = math.max(refTop.width, refBottom.width);
    final refHeight = refTop.height + refBottom.height;

    final scale = math.min(
      (size.width * maxWidthFraction) / refWidth,
      (size.height * maxHeightFraction) / refHeight,
    );
    final fontSize = _refSize * scale;

    final top = _line(_top, Colors.white, fontSize);
    final bottom = _line(_bottom, Colors.black, fontSize);
    final totalHeight = top.height + bottom.height;
    final startY = (size.height - totalHeight) / 2;
    top.paint(canvas, Offset((size.width - top.width) / 2, startY));
    bottom.paint(canvas, Offset((size.width - bottom.width) / 2, startY + top.height));
  }

  @override
  bool shouldRepaint(WordmarkPainter old) =>
      old.maxWidthFraction != maxWidthFraction ||
      old.maxHeightFraction != maxHeightFraction ||
      old.paintBackground != paintBackground;
}
