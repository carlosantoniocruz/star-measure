import 'package:flutter_test/flutter_test.dart';
import 'package:showdist/common/device_turns.dart';

void main() {
  const g = 9.81;

  test('upright portrait needs no turn', () {
    expect(quarterTurnsFor(0, g, 1), 0);
  });

  test('on its left edge turns clockwise; on its right, counterclockwise', () {
    expect(quarterTurnsFor(g, 0, 0), 1);
    expect(quarterTurnsFor(-g, 0, 0), -1);
  });

  test('near the 45° diagonal keeps whatever was showing', () {
    // 45° exactly, and 50° (inside the 10° dead zone either side).
    expect(quarterTurnsFor(g, g, 0), 0);
    expect(quarterTurnsFor(g, g, 1), 1);
    final x50 = g * 0.766, y50 = g * 0.643;
    expect(quarterTurnsFor(x50, y50, 0), 0);
    // Past the dead zone (60°) it switches.
    expect(quarterTurnsFor(g * 0.866, g * 0.5, 0), 1);
  });

  test('lying flat keeps whatever was showing', () {
    expect(quarterTurnsFor(0.5, 0.8, 1), 1);
    expect(quarterTurnsFor(0.5, 0.8, -1), -1);
  });

  test('upside down keeps whatever was showing', () {
    expect(quarterTurnsFor(0, -g, 1), 1);
    expect(quarterTurnsFor(0, -g, 0), 0);
  });
}
