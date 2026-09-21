import 'dart:math' as math;

import 'package:ar_measure/intro/egg_intro.dart';
import 'package:ar_measure/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('connecting all twelve diamonds reveals the logo and enables hold-to-launch',
      (tester) async {
    var launched = 0;
    await tester.pumpWidget(MaterialApp(
      theme: Sky.theme(),
      home: EggIntro(onLaunch: () => launched++),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('CONNECT THE STARS'), findsOneWidget);
    expect(find.text('HOLD THE LOGO TO LAUNCH'), findsNothing);

    // Drag a finger through every diamond on the ring, in order.
    final size = tester.getSize(find.byType(EggIntro));
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.34;
    Offset diamond(int i) => center + Offset.fromDirection(-math.pi / 2 + i * math.pi / 6, radius);

    final gesture = await tester.startGesture(diamond(0));
    for (var i = 1; i < 12; i++) {
      await gesture.moveTo(diamond(i));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();

    // Logo flies in over 2.6s.
    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.text('HOLD THE LOGO TO LAUNCH'), findsOneWidget);
    expect(find.text('STAR MEASURE'), findsOneWidget);
    expect(launched, 0);

    // Holding the logo for the full charge launches.
    final hold = await tester.startGesture(center);
    await tester.pump(); // a ticker's first frame is elapsed == 0
    await tester.pump(const Duration(milliseconds: 1800));
    await hold.up();
    expect(launched, 1);
  });

  testWidgets('a partial hold cancels instead of launching', (tester) async {
    var launched = 0;
    await tester.pumpWidget(MaterialApp(
      theme: Sky.theme(),
      home: EggIntro(onLaunch: () => launched++),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final size = tester.getSize(find.byType(EggIntro));
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.34;
    final g = await tester.startGesture(center + Offset.fromDirection(-math.pi / 2, radius));
    for (var i = 1; i < 12; i++) {
      await g.moveTo(center + Offset.fromDirection(-math.pi / 2 + i * math.pi / 6, radius));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 3000));

    final hold = await tester.startGesture(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await hold.up();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(launched, 0);
  });

  testWidgets('skip launches immediately, once', (tester) async {
    var launched = 0;
    await tester.pumpWidget(MaterialApp(
      theme: Sky.theme(),
      home: EggIntro(onLaunch: () => launched++),
    ));
    await tester.tap(find.text('SKIP'));
    await tester.tap(find.text('SKIP'));
    expect(launched, 1);
  });
}
