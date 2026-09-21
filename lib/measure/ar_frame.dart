import 'dart:math' as math;
import 'dart:ui';

enum TrackingStatus { stopped, tracking, lost }

enum TrackingIssue { none, badState, tooDark, tooFast, fewFeatures, cameraUnavailable }

/// A point in the world (metres) and where it lands on screen (0..1, top-left origin).
class ArPoint {
  const ArPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.screen,
    required this.visible,
  });

  final double x, y, z;
  final Offset screen;
  final bool visible;

  double distanceTo(ArPoint other) {
    final dx = x - other.x, dy = y - other.y, dz = z - other.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}

/// One camera frame of AR state, decoded from the native DoubleArray.
/// The layout is documented on `ArMeasureView.kt`.
class ArFrame {
  const ArFrame({
    required this.status,
    required this.issue,
    required this.planes,
    required this.reticle,
    required this.points,
  });

  static const empty = ArFrame(
    status: TrackingStatus.stopped,
    issue: TrackingIssue.none,
    planes: 0,
    reticle: null,
    points: [],
  );

  static const _header = 10;
  static const _stride = 6;

  final TrackingStatus status;
  final TrackingIssue issue;
  final int planes;

  /// Where the screen centre hits a surface, or null if it doesn't.
  final ArPoint? reticle;
  final List<ArPoint> points;

  factory ArFrame.parse(List<double> d) {
    if (d.length < _header) return empty;
    final count = d[9].toInt().clamp(0, (d.length - _header) ~/ _stride);
    return ArFrame(
      status: TrackingStatus.values[d[0].toInt().clamp(0, 2)],
      issue: TrackingIssue.values[d[1].toInt().clamp(0, 5)],
      planes: d[2].toInt(),
      reticle: d[3] == 1
          ? ArPoint(x: d[4], y: d[5], z: d[6], screen: Offset(d[7], d[8]), visible: true)
          : null,
      points: [
        for (var i = 0; i < count; i++)
          ArPoint(
            x: d[_header + i * _stride],
            y: d[_header + i * _stride + 1],
            z: d[_header + i * _stride + 2],
            screen: Offset(d[_header + i * _stride + 3], d[_header + i * _stride + 4]),
            visible: d[_header + i * _stride + 5] == 1,
          ),
      ],
    );
  }

  double get totalLength {
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += points[i - 1].distanceTo(points[i]);
    }
    return sum;
  }
}
