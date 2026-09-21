import 'package:ar_measure/measure/ar_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Layout mirrors ArMeasureView.kt: 10 header values, then 6 per point.
  test('decodes header, reticle and points', () {
    final f = ArFrame.parse([
      1, 0, 2, // tracking, no issue, 2 planes
      1, 0.5, 0, -1, 0.5, 0.5, // reticle hit + screen position
      2, // two points
      0, 0, 0, 0.25, 0.75, 1,
      3, 4, 0, 0.75, 0.25, 0,
    ]);
    expect(f.status, TrackingStatus.tracking);
    expect(f.issue, TrackingIssue.none);
    expect(f.planes, 2);
    expect(f.reticle, isNotNull);
    expect(f.reticle!.screen, const Offset(0.5, 0.5));
    expect(f.points, hasLength(2));
    expect(f.points[0].visible, isTrue);
    expect(f.points[1].visible, isFalse);
    expect(f.points[0].screen, const Offset(0.25, 0.75));
    expect(f.totalLength, closeTo(5, 1e-9)); // 3-4-5 triangle
  });

  test('no reticle when the centre misses a surface', () {
    final f = ArFrame.parse([1, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    expect(f.reticle, isNull);
    expect(f.points, isEmpty);
  });

  test('a truncated payload never throws', () {
    expect(ArFrame.parse([1, 0]).status, TrackingStatus.stopped);
    // Claims 5 points but only carries one.
    final f = ArFrame.parse([1, 0, 0, 0, 0, 0, 0, 0, 0, 5, 1, 2, 3, 0.1, 0.2, 1]);
    expect(f.points, hasLength(1));
  });

  test('lost tracking reports the reason', () {
    final f = ArFrame.parse([2, 3, 0, 0, 0, 0, 0, 0, 0, 0]);
    expect(f.status, TrackingStatus.lost);
    expect(f.issue, TrackingIssue.tooFast);
  });
}
