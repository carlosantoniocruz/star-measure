import 'dart:math' as math;

import 'ar_frame.dart';

class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x, y, z;

  double distanceTo(Vec3 o) {
    final dx = x - o.x, dy = y - o.y, dz = z - o.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}

/// A finished measurement: an ordered list of points in ARCore world space
/// (metres, origin wherever the session started), and the segments between them.
class Recording {
  Recording({required this.id, required this.createdAt, required this.points});

  factory Recording.fromPoints(List<ArPoint> pts, {DateTime? now}) {
    final at = now ?? DateTime.now();
    return Recording(
      id: at.microsecondsSinceEpoch.toString(),
      createdAt: at,
      points: [for (final p in pts) Vec3(p.x, p.y, p.z)],
    );
  }

  factory Recording.fromJson(Map<String, dynamic> j) => Recording(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        points: [
          for (final p in j['points'] as List)
            Vec3((p[0] as num).toDouble(), (p[1] as num).toDouble(), (p[2] as num).toDouble()),
        ],
      );

  /// Not shown to the user or in exports — kept only for a stable id and a
  /// unique export filename.
  final DateTime createdAt;

  final String id;
  final List<Vec3> points;

  List<double> get segments => [
        for (var i = 1; i < points.length; i++) points[i - 1].distanceTo(points[i]),
      ];

  double get total => segments.fold(0.0, (a, b) => a + b);

  /// Storage form.
  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'points': [for (final p in points) [p.x, p.y, p.z]],
      };
}
