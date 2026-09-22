import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'ar_frame.dart';
import 'units.dart';

/// Confirmed measurements — placed points, the lines between them, and their
/// labels — are peachRed ("actions: ... placed points"), fixed regardless of
/// theme since this sits on the live camera feed, not the app's own chrome.
const _placed = Palette.peachRed;

/// The reticle and the dashed line reaching for it are seaGreen
/// ("live/tracking elements: reticle dots, ..."), distinguishing what's still
/// live from what's already placed.
const _tracking = Palette.seaGreen;

/// A slight dark shadow under the overlay graphics and text, so they read
/// against any real-world background.
const _shadowColor = Color(0xB312354E); // darkTyrianBlue at ~70% alpha
const _shadowOffset = Offset(0, 1.2);
const _shadowBlur = 1.4;

Paint _shadowOf(Paint base) => Paint()
  ..color = _shadowColor
  ..style = base.style
  ..strokeWidth = base.strokeWidth
  ..strokeCap = base.strokeCap
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _shadowBlur);

/// The reticle's drop shadow: black, softer and wider than [_shadowColor], so
/// the seaGreen dots and white centre hold up against bright walls, windows,
/// and sunlit floors, where a darkTyrianBlue shadow would all but vanish.
const _reticleShadow = Color(0x66000000); // black at 40%
const _reticleShadowOffset = Offset(0, 1.5);
const _reticleShadowBlur = 2.5;

/// Behind every distance label: black at 50%, rounded — dark enough for
/// white text on any camera background, light enough to see through. Also
/// behind the Measure screen's running total.
const labelScrim = Color(0x80000000);

/// One reticle turn every [reticlePeriod] seconds.
@visibleForTesting
const reticlePeriod = 11.0;

/// Draws measurements over the camera feed with as little as possible: small
/// dots for points, hairlines between them, white numbers on a dark pill for
/// each distance, and three dots circling a white centre as the aiming reticle.
class ConstellationPainter extends CustomPainter {
  ConstellationPainter({
    required this.frame,
    required this.time,
    required this.units,
  }) : super(repaint: Listenable.merge([frame, time]));

  final ValueListenable<ArFrame> frame;
  final ValueListenable<double> time;
  final UnitSystem units;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame.value;
    final t = time.value;
    final pts = f.points;
    Offset px(ArPoint p) => Offset(p.screen.dx * size.width, p.screen.dy * size.height);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = _placed;

    final labels = <_Label>[];
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      if (!a.visible || !b.visible) continue;
      final pa = px(a), pb = px(b);
      _drawShadowedLine(canvas, pa, pb, line);
      labels.add(_Label((pa + pb) / 2, formatLength(a.distanceTo(b), units), live: false));
    }

    // Dashed line from the last point to wherever the reticle is aiming.
    final reticle = f.reticle;
    final trackingLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = _tracking;
    if (reticle != null && pts.isNotEmpty && pts.last.visible) {
      final a = px(pts.last), b = px(reticle);
      _dashed(canvas, a, b, trackingLine);
      labels.add(_Label((a + b) / 2, formatLength(pts.last.distanceTo(reticle), units), live: true));
    }

    final marker = Paint()..color = _placed;
    for (final p in pts) {
      if (p.visible) _drawShadowedCircle(canvas, px(p), 6, marker);
    }

    _reticle(canvas, size.center(Offset.zero), t, hit: reticle != null);

    for (final label in labels) {
      if (labelVisible(label.at, size)) _drawLabel(canvas, size, label);
    }
  }

  /// A distance label belongs to the middle of its segment. When that point is
  /// off-screen the label is hidden, rather than pinned to an edge where it
  /// floats unattached (and lands on top of the controls).
  @visibleForTesting
  static bool labelVisible(Offset at, Size size) =>
      at.dx >= 0 && at.dx <= size.width && at.dy >= 0 && at.dy <= size.height;

  /// Three seaGreen dots in an equilateral triangle, turning slowly clockwise
  /// around a white centre dot — the app icon's motif. Solid once the
  /// reticle is on a surface; hollow and faded while it's still searching.
  void _reticle(Canvas canvas, Offset c, double t, {required bool hit}) {
    const ringRadius = 22.0;
    final paint = Paint()
      ..style = hit ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _tracking.withValues(alpha: hit ? 1 : 0.6);
    final spin = t * 2 * math.pi / reticlePeriod;
    for (var k = 0; k < 3; k++) {
      // k = 0 starts straight up, like the icon.
      final p = c + Offset.fromDirection(-math.pi / 2 + spin + k * 2 * math.pi / 3, ringRadius);
      _drawReticleDot(canvas, p, 5, paint);
    }
    _drawReticleDot(canvas, c, 2.6, Paint()..color = Palette.white.withValues(alpha: hit ? 1 : 0.6));
  }

  void _drawReticleDot(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawCircle(
      c + _reticleShadowOffset,
      r,
      Paint()
        ..color = _reticleShadow
        ..style = paint.style
        ..strokeWidth = paint.strokeWidth
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _reticleShadowBlur),
    );
    canvas.drawCircle(c, r, paint);
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final total = (b - a).distance;
    if (total < 1) return;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += 12) {
      _drawShadowedLine(canvas, a + dir * d, a + dir * math.min(d + 6, total), paint);
    }
  }

  void _drawShadowedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    canvas.drawLine(a + _shadowOffset, b + _shadowOffset, _shadowOf(paint));
    canvas.drawLine(a, b, paint);
  }

  void _drawShadowedCircle(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawCircle(c + _shadowOffset, r, _shadowOf(paint));
    canvas.drawCircle(c, r, paint);
  }

  void _drawLabel(Canvas canvas, Size size, _Label label) {
    final tp = TextPainter(
      text: TextSpan(
        text: label.text,
        style: const TextStyle(
          // A canvas TextPainter doesn't inherit the app theme, so the
          // family is set here explicitly.
          fontFamily: showdistFontFamily,
          color: Palette.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          fontFeatures: [...showdistFontFeatures, FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final w = tp.width + 16, h = tp.height + 8;
    final cx = label.at.dx.clamp(w / 2 + 8, size.width - w / 2 - 8);
    final cy = label.at.dy.clamp(h / 2 + 8, size.height - h / 2 - 8);
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(h / 2));

    canvas.drawRRect(rrect, Paint()..color = labelScrim);
    // The live label (last point to reticle) keeps a seaGreen hairline, so
    // it still reads as "still moving" beside the fixed segment labels.
    if (label.live) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _tracking.withValues(alpha: 0.8),
      );
    }
    tp.paint(canvas, rect.topLeft + const Offset(8, 4));
  }

  @override
  bool shouldRepaint(ConstellationPainter old) => old.units != units;
}

class _Label {
  const _Label(this.at, this.text, {required this.live});

  final Offset at;
  final String text;
  final bool live;
}
