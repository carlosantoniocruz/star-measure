import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../common/diamond.dart';
import '../theme.dart';
import 'ar_frame.dart';
import 'units.dart';

/// Overlay color for every camera-drawn measurement: same neon in both
/// themes, since it sits on the live camera feed, not the app's own chrome.
const _overlay = Hue.neon;

/// A slight dark shadow under the overlay graphics and text, so the neon
/// reads against any real-world background.
const _shadowColor = Color(0x99000000);
const _shadowOffset = Offset(0, 1.2);
const _shadowBlur = 1.4;

Paint _shadowOf(Paint base) => Paint()
  ..color = _shadowColor
  ..style = base.style
  ..strokeWidth = base.strokeWidth
  ..strokeCap = base.strokeCap
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _shadowBlur);

const _labelShadow = [Shadow(color: _shadowColor, blurRadius: 3, offset: Offset(0, 1))];

/// Draws measurements over the camera feed with as little as possible: small
/// diamonds for points, hairlines between them, a quiet pill for each
/// distance, and four tiny diamonds as the aiming reticle.
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
      ..color = _overlay;

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
    if (reticle != null && pts.isNotEmpty && pts.last.visible) {
      final a = px(pts.last), b = px(reticle);
      _dashed(canvas, a, b, line);
      labels.add(_Label((a + b) / 2, formatLength(pts.last.distanceTo(reticle), units), live: true));
    }

    final marker = Paint()..color = _overlay;
    for (final p in pts) {
      if (p.visible) _drawShadowedPath(canvas, diamondPath(px(p), 6), marker);
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

  void _reticle(Canvas canvas, Offset c, double t, {required bool hit}) {
    const ringRadius = 22.0;
    final paint = Paint()
      ..style = hit ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _overlay.withValues(alpha: hit ? 1 : 0.5);
    for (var k = 0; k < 4; k++) {
      final p = c + Offset.fromDirection(t * 0.4 + k * math.pi / 2, ringRadius);
      _drawShadowedPath(canvas, diamondPath(p, 4.5), paint);
    }
    _drawShadowedCircle(canvas, c, 1.8, Paint()..color = Colors.white.withValues(alpha: hit ? 0.95 : 0.5));
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

  void _drawShadowedPath(Canvas canvas, Path path, Paint paint) {
    canvas.drawPath(path.shift(_shadowOffset), _shadowOf(paint));
    canvas.drawPath(path, paint);
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
          color: _overlay,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          fontFeatures: [...showdistFontFeatures, FontFeature.tabularFigures()],
          shadows: _labelShadow,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final w = tp.width + 16, h = tp.height + 8;
    final cx = label.at.dx.clamp(w / 2 + 8, size.width - w / 2 - 8);
    final cy = label.at.dy.clamp(h / 2 + 8, size.height - h / 2 - 8);
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(h / 2));

    canvas.drawRRect(rrect, Paint()..color = const Color(0xB3000000));
    if (label.live) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _overlay.withValues(alpha: 0.8),
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
