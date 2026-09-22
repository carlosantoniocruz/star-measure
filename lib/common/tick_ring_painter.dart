import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The app icon: a black field, a Neon ring (the brand pink), and black tick
/// marks notched across it at regular intervals, like a gauge dial. No
/// lettering.
///
/// Sized so the ring's outer edge sits at [outerFraction] of the canvas's
/// shorter side, whichever icon layer it's rendered into (adaptive
/// foreground, legacy, monochrome, or the full-bleed `docs/logo.png`).
class TickRingPainter extends CustomPainter {
  const TickRingPainter({
    this.outerFraction = 0.42,
    this.ringWidthFraction = 0.16,
    this.tickCount = 32,
    this.majorEvery = 4,
    this.paintBackground = true,
  });

  final double outerFraction, ringWidthFraction;
  final int tickCount, majorEvery;

  /// False paints the ring and ticks alone (transparent elsewhere) — for an
  /// adaptive icon's foreground layer or a monochrome/themed icon, where the
  /// background is supplied separately.
  final bool paintBackground;

  @override
  void paint(Canvas canvas, Size size) {
    if (paintBackground) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Hue.black);
    }

    final c = size.center(Offset.zero);
    final outer = size.shortestSide * outerFraction;
    final ringWidth = size.shortestSide * ringWidthFraction;
    final inner = outer - ringWidth;
    final ringCentre = (outer + inner) / 2;

    canvas.drawCircle(
      c,
      ringCentre,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..color = Hue.neon,
    );

    // Black ticks notch across the ring, alternating longer (major) and
    // shorter (minor) — the pink/black alternation the ring reads as.
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..color = Hue.black;
    for (var i = 0; i < tickCount; i++) {
      final angle = 2 * math.pi * i / tickCount;
      final isMajor = i % majorEvery == 0;
      tickPaint.strokeWidth = ringWidth * (isMajor ? 0.34 : 0.14);
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(c + dir * (inner - 1), c + dir * (outer + 1), tickPaint);
    }

    // A solid centre, echoing the AR reticle's dot.
    canvas.drawCircle(c, inner * 0.34, Paint()..color = Hue.neon);
  }

  @override
  bool shouldRepaint(TickRingPainter old) =>
      old.outerFraction != outerFraction ||
      old.ringWidthFraction != ringWidthFraction ||
      old.tickCount != tickCount ||
      old.majorEvery != majorEvery ||
      old.paintBackground != paintBackground;
}
