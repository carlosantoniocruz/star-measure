import 'package:showdist/measure/recording.dart';
import 'package:showdist/measure/shape_outline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no points gives no outline', () => expect(shapeOutline(const []), isEmpty));

  test('a single point, or coincident points, sit in the centre', () {
    expect(shapeOutline(const [Vec3(1, 2, 3)]), [const Offset(0.5, 0.5)]);
    expect(shapeOutline(const [Vec3(1, 2, 3), Vec3(1, 2, 3)]), everyElement(const Offset(0.5, 0.5)));
  });

  test('a line along x is horizontal and centred', () {
    final o = shapeOutline(const [Vec3(0, 0, 0), Vec3(2, 0, 0)]);
    expect(o[0], const Offset(0, 0.5));
    expect(o[1], const Offset(1, 0.5));
  });

  test('a measurement on the floor is seen from above (y ignored)', () {
    // A 2 x 1 rectangle on a constant-height floor.
    final o = shapeOutline(const [
      Vec3(0, -1, 0),
      Vec3(2, -1, 0),
      Vec3(2, -1, 1),
      Vec3(0, -1, 1),
    ]);
    expect(o.map((p) => p.dx), [0, 1, 1, 0]);
    // Scaled uniformly by the longer side: height is half the width, centred.
    expect((o[2].dy - o[1].dy).abs(), closeTo(0.5, 1e-9));
    expect((o[1].dy + o[2].dy) / 2, closeTo(0.5, 1e-9));
  });

  test('world-up stays up on screen for a vertical measurement', () {
    final o = shapeOutline(const [Vec3(0, 0, 0), Vec3(0, 2, 0)]); // bottom then top
    expect(o[0].dy, greaterThan(o[1].dy)); // canvas y grows downward
    expect(o[0].dy, closeTo(1, 1e-9));
    expect(o[1].dy, closeTo(0, 1e-9));
  });

  test('every point lands inside the unit square', () {
    final o = shapeOutline(const [Vec3(-3, 0.2, 4), Vec3(5, -1, 0), Vec3(0, 3, -2), Vec3(1, 1, 1)]);
    for (final p in o) {
      expect(p.dx, inInclusiveRange(0, 1));
      expect(p.dy, inInclusiveRange(0, 1));
    }
  });
}
