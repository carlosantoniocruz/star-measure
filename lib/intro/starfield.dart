import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class Star {
  const Star({
    required this.angle,
    required this.depth,
    required this.size,
    required this.phase,
    required this.speed,
  });

  final double angle, depth, size, phase, speed;
}

List<Star> generateStars(int count, {int seed = 17}) {
  final rnd = math.Random(seed);
  return List.generate(
    count,
    (_) => Star(
      angle: rnd.nextDouble() * 2 * math.pi,
      depth: rnd.nextDouble(),
      size: 0.4 + rnd.nextDouble() * 0.9,
      phase: rnd.nextDouble() * 2 * math.pi,
      speed: 0.6 + rnd.nextDouble() * 0.8,
    ),
  );
}

/// Stars radiating from the centre. [flow] advances them toward the viewer,
/// [streak] stretches them into warp lines (0 = twinkling dots).
class StarfieldPainter extends CustomPainter {
  StarfieldPainter({
    required this.stars,
    required this.time,
    required this.flow,
    required this.streak,
    required this.palette,
  });

  final List<Star> stars;
  final double time, flow, streak;
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.longestSide * 0.72;
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (final s in stars) {
      final d = (s.depth + flow * s.speed) % 1.0;
      final r = maxR * math.pow(d, 1.6).toDouble();
      final dir = Offset(math.cos(s.angle), math.sin(s.angle));
      final p = c + dir * r;
      final twinkle = 0.55 + 0.45 * math.sin(time * 2 + s.phase);
      final alpha = (twinkle * (0.2 + 0.6 * d)).clamp(0.0, 1.0);
      paint.color = palette.onBase.withValues(alpha: alpha);

      if (streak > 0.02) {
        final tail = c + dir * (r * (1 - math.min(0.9, streak * 0.12 * (0.4 + d))));
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.size * (0.6 + d * 1.4);
        canvas.drawLine(tail, p, paint);
      } else {
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(p, s.size * (0.6 + d * 0.9), paint);
      }
    }
  }

  @override
  bool shouldRepaint(StarfieldPainter old) =>
      old.time != time || old.flow != flow || old.streak != streak || old.palette != palette;
}
