import 'package:showdist/level/level_screen.dart';
import 'package:showdist/menu/main_menu_screen.dart';
import 'package:showdist/settings.dart';
import 'package:showdist/theme.dart';
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
      home: MainMenuScreen(settings: await settings()),
    ));
    expect(find.text('MEASURE'), findsOneWidget);
    expect(find.text('LEVELER'), findsOneWidget);
  });

  testWidgets('Leveler opens the bubble level, reading level before any tilt', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: MainMenuScreen(settings: await settings()),
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
      home: MainMenuScreen(settings: await settings()),
    ));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('UNITS'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });
}
