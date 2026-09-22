import 'package:showdist/about_screen.dart';
import 'package:showdist/level/level_screen.dart';
import 'package:showdist/measure/history_screen.dart';
import 'package:showdist/measure/recording.dart';
import 'package:showdist/measure/recording_store.dart';
import 'package:showdist/menu/main_menu_screen.dart';
import 'package:showdist/settings.dart';
import 'package:showdist/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppSettings> settings() async {
  SharedPreferences.setMockInitialValues({});
  return AppSettings.load();
}

void main() {
  testWidgets('shows Measure and Leveler tiles', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: MainMenuScreen(settings: await settings(), store: RecordingStore.inMemory()),
    ));
    expect(find.text('MEASURE'), findsOneWidget);
    expect(find.text('LEVELER'), findsOneWidget);
  });

  testWidgets('Leveler opens the bubble level, reading level before any tilt', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: MainMenuScreen(settings: await settings(), store: RecordingStore.inMemory()),
    ));
    await tester.tap(find.text('LEVELER'));
    await tester.pumpAndSettle();
    expect(find.byType(LevelScreen), findsOneWidget);
    // No sensor events have arrived (unmocked in tests), so tilt stays at
    // the initial zero reading.
    expect(find.text('0.0°'), findsOneWidget);
  });

  testWidgets('the gear icon opens Settings', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: MainMenuScreen(settings: await settings(), store: RecordingStore.inMemory()),
    ));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('UNITS'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('no About icon on the menu; About lives in Settings', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: MainMenuScreen(settings: await settings(), store: RecordingStore.inMemory()),
    ));
    expect(find.byTooltip('About'), findsNothing);
    expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
  });

  testWidgets('History under Measure shows the saved count and opens History', (tester) async {
    final store = RecordingStore.inMemory([
      for (final id in ['a', 'b'])
        Recording(id: id, createdAt: DateTime(2026, 9, 22), points: const [Vec3(0, 0, 0), Vec3(1, 0, 0)]),
    ]);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: MainMenuScreen(settings: await settings(), store: store),
    ));
    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.text('2 saved'), findsOneWidget);
    // Below Measure, above Leveler.
    final y = tester.getCenter(find.text('HISTORY')).dy;
    expect(y, greaterThan(tester.getCenter(find.text('MEASURE')).dy));
    expect(y, lessThan(tester.getCenter(find.text('LEVELER')).dy));

    await store.remove('a');
    await tester.pump();
    expect(find.text('1 saved'), findsOneWidget);

    await tester.tap(find.text('HISTORY'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
  });

  /// The ruler's drift (0..1 through one cycle), read off its painter.
  double drift(WidgetTester tester) {
    final paint = tester.widgetList<CustomPaint>(find.byType(CustomPaint, skipOffstage: false)).firstWhere(
          (p) => p.painter.runtimeType.toString() == '_RulerPainter',
        );
    return ((paint.painter as dynamic).drift as ValueListenable<double>).value;
  }

  testWidgets('the ruler keeps drifting, unless reduced motion is on', (tester) async {
    final s = await settings();
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: MainMenuScreen(settings: s, store: RecordingStore.inMemory()),
    ));
    final before = drift(tester);
    await tester.pump(const Duration(seconds: 3));
    // 3 s of a 12 s cycle.
    expect(drift(tester) - before, closeTo(0.25, 0.01));

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: buildTheme(),
        home: MainMenuScreen(settings: s, store: RecordingStore.inMemory()),
      ),
    ));
    final still = drift(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(drift(tester), still);
  });

  testWidgets('the ruler stops while another screen covers the menu', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: MainMenuScreen(settings: await settings(), store: RecordingStore.inMemory()),
    ));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final covered = drift(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(drift(tester), covered);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(drift(tester), isNot(covered));
  });

  testWidgets('History is hidden until something is saved', (tester) async {
    final store = RecordingStore.inMemory();
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: MainMenuScreen(settings: await settings(), store: store),
    ));
    expect(find.text('HISTORY'), findsNothing);

    await store.add(Recording(id: 'a', createdAt: DateTime(2026, 9, 22), points: const [Vec3(0, 0, 0), Vec3(1, 0, 0)]));
    await tester.pump();
    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.text('1 saved'), findsOneWidget);

    await store.clear();
    await tester.pump();
    expect(find.text('HISTORY'), findsNothing);
  });

  testWidgets('About: Developer shows just the email; no separate Contact', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const AboutScreen()));
    expect(find.text('DEVELOPER'), findsOneWidget);
    expect(find.text('sh.run.configs@gmail.com'), findsOneWidget);
    expect(find.text('Contact'), findsNothing);
    expect(
      tester.getTopLeft(find.text('sh.run.configs@gmail.com')).dy,
      greaterThan(tester.getTopLeft(find.text('DEVELOPER')).dy),
    );
  });
}
