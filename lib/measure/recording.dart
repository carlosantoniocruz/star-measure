import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'ar_frame.dart';
import 'units.dart';

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

  final String id;
  final DateTime createdAt;
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

  /// One row per segment, plus a total row. Lengths in metres and in [units].
  String toCsv(UnitSystem units) {
    final when = createdAt.toIso8601String();
    final rows = <List<Object>>[
      [
        'recorded_at', 'segment', 'from_point', 'to_point', 'length_m', 'length_display',
        'x1_m', 'y1_m', 'z1_m', 'x2_m', 'y2_m', 'z2_m',
      ],
    ];
    final segs = segments;
    for (var i = 0; i < segs.length; i++) {
      final a = points[i], b = points[i + 1];
      rows.add([
        when, i + 1, i + 1, i + 2, _m(segs[i]), formatLength(segs[i], units),
        _m(a.x), _m(a.y), _m(a.z), _m(b.x), _m(b.y), _m(b.z),
      ]);
    }
    rows.add([when, 'total', '', '', _m(total), formatLength(total, units), '', '', '', '', '', '']);
    return '${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}\r\n';
  }

  /// Readable, machine-friendly export.
  String toExportJson(UnitSystem units) {
    final segs = segments;
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'Star Measure',
      'recorded_at': createdAt.toIso8601String(),
      'unit_system': units.name,
      'total_m': double.parse(_m(total)),
      'total_display': formatLength(total, units),
      'coordinates': 'ARCore world space, metres; origin is where the AR session started',
      'points': [
        for (var i = 0; i < points.length; i++)
          {
            'index': i + 1,
            'x': double.parse(_m(points[i].x)),
            'y': double.parse(_m(points[i].y)),
            'z': double.parse(_m(points[i].z)),
          },
      ],
      'segments': [
        for (var i = 0; i < segs.length; i++)
          {
            'index': i + 1,
            'from': i + 1,
            'to': i + 2,
            'length_m': double.parse(_m(segs[i])),
            'length_display': formatLength(segs[i], units),
          },
      ],
    });
  }

  static String _m(double v) => v.toStringAsFixed(4);

  @visibleForTesting
  static String csvCell(Object v) {
    final s = '$v';
    return s.contains(RegExp(r'[",\r\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Sep 21, 16:40"
String formatStamp(DateTime t) =>
    '${_months[t.month - 1]} ${t.day}, ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
