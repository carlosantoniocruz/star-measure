import 'package:showdist/measure/ar_frame.dart';
import 'package:showdist/measure/constellation_painter.dart';
import 'package:showdist/measure/units.dart';
import 'package:showdist/theme.dart';
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

  group('reticle', () {
    /// Every circle the painter draws at time [t], as (centre, ARGB colour).
    /// Colours are compared as 32-bit ARGB: a [Paint] stores them as floats,
    /// so a round-trip through one isn't `==` to the original constant.
    List<(Offset, int)> circles(ArFrame frame, double t) {
      final canvas = TestRecordingCanvas();
      ConstellationPainter(frame: ValueNotifier(frame), time: ValueNotifier(t), units: UnitSystem.metric)
          .paint(canvas, _screen);
      return [
        for (final call in canvas.invocations)
          if (call.invocation.memberName == #drawCircle)
            (
              call.invocation.positionalArguments[0] as Offset,
              (call.invocation.positionalArguments[2] as Paint).color.toARGB32(),
            ),
      ];
    }

    final aimed = frameOf([], reticle: pt(0, 0.5, 0.5));
    final centre = _screen.center(Offset.zero);

    List<Offset> dots(double t) => [for (final (at, color) in circles(aimed, t)) if (color == Palette.seaGreen.toARGB32()) at];

    test('three seaGreen dots in a triangle, the first straight up', () {
      final d = dots(0);
      expect(d, hasLength(3));
      expect(d[0].dx, closeTo(centre.dx, 1e-6));
      expect(d[0].dy, closeTo(centre.dy - 22, 1e-6));
      // Equilateral: every side the same length.
      final sides = [(d[0] - d[1]).distance, (d[1] - d[2]).distance, (d[2] - d[0]).distance];
      for (final side in sides) {
        expect(side, closeTo(22 * 1.7320508, 1e-6));
      }
    });

    test('a white centre dot', () {
      expect(circles(aimed, 0).where((c) => c.$1 == centre && c.$2 == Palette.white.toARGB32()), hasLength(1));
    });

    test('turns clockwise, one full turn per period', () {
      final quarter = dots(reticlePeriod / 4)[0];
      expect(quarter.dx, closeTo(centre.dx + 22, 1e-6), reason: 'a quarter turn puts the top dot at the right');
      expect(quarter.dy, closeTo(centre.dy, 1e-6));
      final full = dots(reticlePeriod)[0];
      expect(full.dx, closeTo(centre.dx, 1e-6));
      expect(full.dy, closeTo(centre.dy - 22, 1e-6));
      expect(reticlePeriod, inInclusiveRange(10, 12));
    });

    test('every reticle dot has a dark drop shadow beneath it', () {
      final all = circles(aimed, 0);
      // Black (RGB 0) and translucent.
      final shadows = all.where((c) => c.$2 & 0xFFFFFF == 0 && c.$2 >>> 24 < 0x80);
      expect(shadows, hasLength(4), reason: 'three dots plus the centre');
    });

    test('placed points are peachRed', () {
      final placed = circles(frameOf([pt(0, 0.3, 0.5), pt(1, 0.7, 0.5)]), 0);
      expect(placed.where((c) => c.$2 == Palette.peachRed.toARGB32()), hasLength(2));
    });
  });

  testWidgets('distance labels sit on a black 50% scrim', (tester) async {
    final ro = await pumpOverlay(tester, frameOf([pt(0, 0.3, 0.5), pt(1, 0.7, 0.5)]));
    expect(ro, paints..rrect(color: labelScrim));
    expect(labelScrim, const Color(0x80000000));
  });
}
