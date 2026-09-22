import 'package:showdist/measure/ar_frame.dart';
import 'package:showdist/measure/constellation_painter.dart';
import 'package:showdist/measure/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _screen = Size(400, 800);

/// A point 1 m apart along x per unit of [worldX]; [sx]/[sy] are normalised screen coordinates.
ArPoint pt(double worldX, double sx, double sy, {bool visible = true}) =>
    ArPoint(x: worldX, y: 0, z: 0, screen: Offset(sx, sy), visible: visible);

ArFrame frameOf(List<ArPoint> points, {ArPoint? reticle}) => ArFrame(
      status: TrackingStatus.tracking,
      issue: TrackingIssue.none,
      planes: 1,
      reticle: reticle,
      points: points,
    );

/// Pumps the overlay and returns its render object, to inspect what was drawn.
Future<RenderObject> pumpOverlay(WidgetTester tester, ArFrame frame) async {
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox.fromSize(
        size: _screen,
        child: CustomPaint(
          painter: ConstellationPainter(
            frame: ValueNotifier(frame),
            time: ValueNotifier(0),
            units: UnitSystem.metric,
          ),
        ),
      ),
    ),
  ));
  return tester.renderObject(find.byType(CustomPaint).last);
}

void main() {
  group('labelVisible', () {
    test('true anywhere on screen, including the edges', () {
      expect(ConstellationPainter.labelVisible(const Offset(200, 400), _screen), isTrue);
      expect(ConstellationPainter.labelVisible(Offset.zero, _screen), isTrue);
      expect(ConstellationPainter.labelVisible(const Offset(400, 800), _screen), isTrue);
    });

    test('false once the midpoint is off any side', () {
      expect(ConstellationPainter.labelVisible(const Offset(-1, 400), _screen), isFalse);
      expect(ConstellationPainter.labelVisible(const Offset(401, 400), _screen), isFalse);
      expect(ConstellationPainter.labelVisible(const Offset(200, -1), _screen), isFalse);
      expect(ConstellationPainter.labelVisible(const Offset(200, 801), _screen), isFalse);
    });
  });

  group('segment labels', () {
    testWidgets('an on-screen segment gets a label', (tester) async {
      final ro = await pumpOverlay(tester, frameOf([pt(0, 0.3, 0.5), pt(1, 0.7, 0.5)]));
      expect(ro, paints..rrect());
    });

    testWidgets('a segment whose midpoint is off-screen gets no label', (tester) async {
      // Both ends are to the right of the screen, so is the midpoint.
      final ro = await pumpOverlay(tester, frameOf([pt(0, 1.4, 0.5), pt(1, 1.8, 0.5)]));
      expect(ro, isNot(paints..rrect()));
    });

    testWidgets('a segment running off the bottom edge gets no label', (tester) async {
      final ro = await pumpOverlay(tester, frameOf([pt(0, 0.5, 1.2), pt(1, 0.5, 1.6)]));
      expect(ro, isNot(paints..rrect()));
    });

    testWidgets('one end off-screen but the midpoint on-screen keeps its label', (tester) async {
      final ro = await pumpOverlay(tester, frameOf([pt(0, -0.2, 0.5), pt(1, 0.6, 0.5)])); // midpoint x = 0.2
      expect(ro, paints..rrect());
    });

    testWidgets('a label just inside an edge is still shown', (tester) async {
      final ro = await pumpOverlay(tester, frameOf([pt(0, 0.9, 0.5), pt(1, 1.09, 0.5)])); // midpoint x ≈ 0.995
      expect(ro, paints..rrect());
    });

    testWidgets('only the off-screen segments lose their labels', (tester) async {
      // Five segments: the first two and the last are off-screen; the middle two are on-screen.
      final ro = await pumpOverlay(
        tester,
        frameOf([
          pt(0, -0.9, 0.5),
          pt(1, -0.5, 0.5), // segment 1 midpoint x = -0.7  (off)
          pt(2, 0.4, 0.5), //  segment 2 midpoint x = -0.05 (off)
          pt(3, 0.6, 0.5), //  segment 3 midpoint x = 0.5   (on)
          pt(4, 0.8, 0.5), //  segment 4 midpoint x = 0.7   (on)
          pt(5, 2.0, 0.5), //  segment 5 midpoint x = 1.4   (off)
        ]),
      );
      // One pill fill per label: exactly the two on-screen segments.
      expect(ro, paintsExactlyCountTimes(#drawRRect, 2));
    });

    testWidgets('the live distance label is hidden when its midpoint is off-screen', (tester) async {
      // Last point far off to the right; reticle at the screen centre. Midpoint x = (2.0 + 0.5) / 2 > 1.
      final ro = await pumpOverlay(
        tester,
        frameOf([pt(0, 1.9, 0.5), pt(1, 2.1, 0.5)], reticle: pt(2, 0.5, 0.5)),
      );
      expect(ro, isNot(paints..rrect()));
    });

    testWidgets('the live distance label shows when its midpoint is on-screen', (tester) async {
      final ro = await pumpOverlay(tester, frameOf([pt(0, 0.2, 0.5)], reticle: pt(1, 0.5, 0.5)));
      expect(ro, paints..rrect());
    });
  });
}
