import 'package:ar_measure/measure/history_screen.dart';
import 'package:ar_measure/measure/recording.dart';
import 'package:ar_measure/measure/recording_store.dart';
import 'package:ar_measure/measure/units.dart';
import 'package:ar_measure/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// [metres] long, along x, saved at minute [minute].
Recording rec(String id, double metres, int minute) => Recording(
      id: id,
      createdAt: DateTime(2026, 9, 21, 12, minute),
      points: [const Vec3(0, 0, 0), Vec3(metres, 0, 0)],
    );

Future<RecordingStore> pumpHistory(WidgetTester tester, {List<Recording>? items}) async {
  final store = RecordingStore.inMemory(items ?? [rec('c', 3, 30), rec('b', 2, 20), rec('a', 1, 10)]);
  await tester.pumpWidget(MaterialApp(
    theme: Sky.theme(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => HistoryScreen(store: store, units: UnitSystem.metric)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('lists measurements newest first', (tester) async {
    await pumpHistory(tester);
    expect(find.text('HISTORY'), findsOneWidget);
    final y = [for (final t in ['3.00 m', '2.00 m', '1.00 m']) tester.getTopLeft(find.text(t)).dy];
    expect(y, orderedEquals([...y]..sort()), reason: 'newest at the top, scrolling down goes back in time');
    expect(find.text('2 points · Sep 21, 12:30'), findsOneWidget);
  });

  testWidgets('shows an empty state', (tester) async {
    await pumpHistory(tester, items: []);
    expect(find.textContaining('No measurements yet'), findsOneWidget);
  });

  testWidgets('back arrow returns to the previous screen', (tester) async {
    await pumpHistory(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('HISTORY'), findsNothing);
  });

  testWidgets('long-press selects; tapping toggles others; delete asks first', (tester) async {
    final store = await pumpHistory(tester);

    await tester.longPress(find.text('2.00 m'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('1.00 m'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 measurements?'), findsOneWidget);
    expect(store.items, hasLength(3), reason: 'nothing is deleted before confirming');

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(store.items.map((r) => r.id), ['c']);
    expect(find.text('HISTORY'), findsOneWidget, reason: 'selection mode ends after deleting');
    expect(find.text('2.00 m'), findsNothing);
    expect(find.text('3.00 m'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation keeps everything', (tester) async {
    final store = await pumpHistory(tester);
    await tester.longPress(find.text('1.00 m'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 measurement?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.items, hasLength(3));
  });

  testWidgets('select all then delete removes everything', (tester) async {
    final store = await pumpHistory(tester);
    await tester.longPress(find.text('3.00 m'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(store.items, isEmpty);
    expect(find.textContaining('No measurements yet'), findsOneWidget);
  });

  testWidgets('menu: Delete all confirms, then clears', (tester) async {
    final store = await pumpHistory(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all'));
    await tester.pumpAndSettle();
    expect(find.text('Delete all 3 measurements?'), findsOneWidget);
    await tester.tap(find.text('Delete all').last);
    await tester.pumpAndSettle();
    expect(store.items, isEmpty);
  });

  testWidgets('menu: Select enters selection mode with nothing picked', (tester) async {
    await pumpHistory(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
    // Delete is unavailable until something is picked.
    final delete = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.delete_outline_rounded));
    expect(delete.onPressed, isNull);
  });

  testWidgets('system back leaves selection mode before leaving the screen', (tester) async {
    await pumpHistory(tester);
    await tester.longPress(find.text('1.00 m'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('HISTORY'), findsOneWidget, reason: 'first back only cancels selection');
    expect(find.textContaining('selected'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget, reason: 'second back leaves History');
  });

  testWidgets('opening a row shows every segment; Copy text copies the summary', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final three = Recording(
      id: 'x',
      createdAt: DateTime(2026, 9, 21, 12, 5),
      points: const [Vec3(0, 0, 0), Vec3(3, 4, 0), Vec3(3, 4, 12)],
    );
    await pumpHistory(tester, items: [three]);

    await tester.tap(find.text('17.00 m'));
    await tester.pumpAndSettle();
    expect(find.text('MEASUREMENT'), findsOneWidget);
    expect(find.text('5.00 m'), findsOneWidget);
    expect(find.text('12.00 m'), findsOneWidget);
    expect(find.text('Copy text'), findsOneWidget);

    await tester.tap(find.text('Copy text'));
    await tester.pumpAndSettle();

    expect(copied, hasLength(1));
    expect(copied.single, startsWith('Star Measure: 17.00 m'));
    expect(copied.single, contains('1. 5.00 m'));
    expect(copied.single, contains('2. 12.00 m'));
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('the row share menu offers CSV, JSON and Copy text', (tester) async {
    await pumpHistory(tester, items: [rec('a', 1, 10)]);
    await tester.tap(find.byTooltip('Share or copy'));
    await tester.pumpAndSettle();
    expect(find.text('Share CSV'), findsOneWidget);
    expect(find.text('Share JSON'), findsOneWidget);
    expect(find.text('Copy text'), findsOneWidget);
  });
}
