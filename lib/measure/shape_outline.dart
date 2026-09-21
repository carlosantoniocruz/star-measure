import 'dart:math' as math;
import 'dart:ui';

import 'recording.dart';

/// Flattens a 3D polyline into the unit square, for a thumbnail.
///
/// Keeps the two axes with the most spread (so a measurement on the floor is
/// seen from above and one up a wall is seen face on), scales uniformly to fit,
/// and centres the result. World-up stays up on screen.
List<Offset> shapeOutline(List<Vec3> pts) {
  if (pts.isEmpty) return const [];

  final axes = <double Function(Vec3)>[(p) => p.x, (p) => p.y, (p) => p.z];
  final mins = [for (final a in axes) pts.map(a).reduce(math.min)];
  final ranges = [for (var i = 0; i < 3; i++) pts.map(axes[i]).reduce(math.max) - mins[i]];

  final chosen = ([0, 1, 2]..sort((a, b) => ranges[b].compareTo(ranges[a]))).take(2).toList();
  // World-up (y) always runs up the thumbnail when it's shown; otherwise we're
  // looking down at the floor and the longer axis runs across.
  final int u, v;
  if (chosen.contains(1)) {
    v = 1;
    u = chosen.firstWhere((a) => a != 1);
  } else {
    u = chosen[0];
    v = chosen[1];
  }
  final span = math.max(ranges[u], ranges[v]);
  if (span < 1e-9) return [for (final _ in pts) const Offset(0.5, 0.5)];

  return [
    for (final p in pts)
      Offset(
        0.5 + (axes[u](p) - mins[u] - ranges[u] / 2) / span,
        0.5 - (axes[v](p) - mins[v] - ranges[v] / 2) / span,
      ),
  ];
}
