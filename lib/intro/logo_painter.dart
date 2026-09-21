import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The app mark, reduced to three flat shapes: a ring of slim diamond petals,
/// a green planet, and one thin orbit.
class LogoPainter extends CustomPainter {
  LogoPainter({
    required this.scale,
    required this.opacity,
    required this.time,
    this.charge = 0,
    this.showRing = false,
  });

  final double scale, opacity, time, charge;
  final bool showRing;

  static const _petals = 12;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || scale <= 0) return;
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * 0.30 * scale;

    canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    canvas.translate(c.dx, c.dy);

    _ringOfPetals(canvas, r);
    _planet(canvas, r);
    if (showRing || charge > 0) _chargeRing(canvas, r);

    canvas.restore();
  }

  void _ringOfPetals(Canvas canvas, double r) {
    const inner = 0.56, outer = 1.0, half = 0.10;
    const mid = (inner + outer) / 2;
    final petal = Path()
      ..moveTo(r * inner, 0)
      ..lineTo(r * mid, r * half)
      ..lineTo(r * outer, 0)
      ..lineTo(r * mid, -r * half)
      ..close();
    final fill = Paint()..color = Sky.petal;
    final turn = time * 0.03;
    for (var i = 0; i < _petals; i++) {
      canvas
        ..save()
        ..rotate(turn + i * 2 * math.pi / _petals)
        ..drawPath(petal, fill)
        ..restore();
    }
  }

  void _planet(Canvas canvas, double r) {
    final orbit = Rect.fromCenter(center: Offset.zero, width: r * 0.82, height: r * 0.22);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.014
      ..color = Sky.star.withValues(alpha: 0.8);

    canvas.save();
    canvas.rotate(-0.35);
    canvas.drawArc(orbit, math.pi, math.pi, false, line); // behind the planet
    canvas.restore();

    canvas.drawCircle(Offset.zero, r * 0.28, Paint()..color = Sky.planet);

    canvas.save();
    canvas.rotate(-0.35);
    canvas.drawArc(orbit, 0, math.pi, false, line); // in front
    canvas.restore();
  }

  void _chargeRing(Canvas canvas, double r) {
    final radius = r * 1.16;
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Sky.star.withValues(alpha: 0.14),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      -math.pi / 2,
      2 * math.pi * charge,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.5
        ..color = Sky.planet,
    );
  }

  @override
  bool shouldRepaint(LogoPainter old) => true;
}
