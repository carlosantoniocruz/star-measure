import 'dart:ui';

/// The easter-egg "star": a slightly narrow diamond centred on [c].
Path diamondPath(Offset c, double r, {double squash = 0.72}) => Path()
  ..moveTo(c.dx, c.dy - r)
  ..lineTo(c.dx + r * squash, c.dy)
  ..lineTo(c.dx, c.dy + r)
  ..lineTo(c.dx - r * squash, c.dy)
  ..close();
