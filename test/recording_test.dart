import 'dart:convert';
import 'dart:io';

import 'package:showdist/measure/recording.dart';
import 'package:showdist/measure/recording_store.dart';
import 'package:showdist/measure/share_recording.dart';
import 'package:showdist/measure/units.dart';
import 'package:flutter_test/flutter_test.dart';

Recording sample({DateTime? at}) => Recording(
      id: '1',
      createdAt: at ?? DateTime(2026, 9, 21, 16, 40, 5),
      // 3-4-5 then a 12 straight up: segments 5 m and 12 m.
      points: const [Vec3(0, 0, 0), Vec3(3, 4, 0), Vec3(3, 4, 12)],
    );

void main() {
  group('Recording', () {
    test('measures segments and total', () {
      final r = sample();
      expect(r.segments, [5.0, 12.0]);
      expect(r.total, 17.0);
    });

    test('CSV has a header, one row per segment, and a total row', () {
      final lines = const LineSplitter().convert(sample().toCsv(UnitSystem.metric));
      expect(lines, hasLength(4));
      expect(lines[0], startsWith('recorded_at,segment,from_point,to_point,length_m,length_display'));
      expect(lines[1], contains(',1,1,2,5.0000,5.00 m,'));
      expect(lines[2], contains(',2,2,3,12.0000,12.00 m,'));
      expect(lines[3], contains(',total,,,17.0000,17.00 m,'));
    });

    test('CSV shows lengths in the chosen unit system', () {
      final csv = sample().toCsv(UnitSystem.imperial);
      expect(csv, contains('16′ 5″')); // 5 m
      expect(csv, contains('39′ 4 1/2″')); // 12 m, to the nearest half inch
    });

    test('CSV cells are escaped only when needed', () {
      expect(Recording.csvCell('plain'), 'plain');
      expect(Recording.csvCell(1.5), '1.5');
      expect(Recording.csvCell('a,b'), '"a,b"');
      expect(Recording.csvCell('say "hi"'), '"say ""hi"""');
      expect(Recording.csvCell('two\nlines'), '"two\nlines"');
    });

    test('export JSON is structured and complete', () {
      final j = jsonDecode(sample().toExportJson(UnitSystem.metric)) as Map<String, dynamic>;
      expect(j['app'], 'Showdist');
      expect(j['unit_system'], 'metric');
      expect(j['total_m'], 17.0);
      expect(j['points'], hasLength(3));
      expect((j['segments'] as List)[0]['length_m'], 5.0);
      expect((j['segments'] as List)[1]['to'], 3);
    });

    test('survives a storage round trip', () {
      final r = Recording.fromJson(jsonDecode(jsonEncode(sample().toJson())) as Map<String, dynamic>);
      expect(r.id, '1');
      expect(r.createdAt, DateTime(2026, 9, 21, 16, 40, 5));
      expect(r.total, 17.0);
    });

    test('formatStamp', () => expect(formatStamp(DateTime(2026, 9, 21, 7, 5)), 'Sep 21, 07:05'));
  });

  group('RecordingStore', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('recordings_test');
      file = File('${dir.path}/recordings.json');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('starts empty when there is no file', () async {
      expect((await RecordingStore.openAt(file)).items, isEmpty);
    });

    test('persists, keeps newest first, and removes', () async {
      final store = await RecordingStore.openAt(file);
      await store.add(Recording(id: 'a', createdAt: DateTime(2026, 1, 1), points: const [Vec3(0, 0, 0), Vec3(1, 0, 0)]));
      await store.add(Recording(id: 'b', createdAt: DateTime(2026, 1, 2), points: const [Vec3(0, 0, 0), Vec3(2, 0, 0)]));
      expect(store.items.map((r) => r.id), ['b', 'a']);

      final reopened = await RecordingStore.openAt(file);
      expect(reopened.items.map((r) => r.id), ['b', 'a']);
      expect(reopened.items.first.total, 2.0);

      await reopened.remove('b');
      expect((await RecordingStore.openAt(file)).items.map((r) => r.id), ['a']);
    });

    test('notifies listeners on change', () async {
      final store = await RecordingStore.openAt(file);
      var calls = 0;
      store.addListener(() => calls++);
      await store.add(sample());
      await store.remove('1');
      expect(calls, 2);
    });

    test('removeMany deletes only the given ids and persists', () async {
      final store = await RecordingStore.openAt(file);
      for (final id in ['a', 'b', 'c', 'd']) {
        await store.add(Recording(id: id, createdAt: DateTime(2026, 1, 1), points: const [Vec3(0, 0, 0), Vec3(1, 0, 0)]));
      }
      await store.removeMany({'b', 'd', 'nope'});
      expect(store.items.map((r) => r.id), ['c', 'a']);
      expect((await RecordingStore.openAt(file)).items.map((r) => r.id), ['c', 'a']);
    });

    test('removeMany with nothing to remove does not notify', () async {
      final store = await RecordingStore.openAt(file);
      await store.add(sample());
      var calls = 0;
      store.addListener(() => calls++);
      await store.removeMany({'missing'});
      expect(calls, 0);
    });

    test('clear empties the store and the file', () async {
      final store = await RecordingStore.openAt(file);
      await store.add(sample());
      await store.clear();
      expect(store.items, isEmpty);
      expect((await RecordingStore.openAt(file)).items, isEmpty);
    });

    test('keeps an unreadable file aside instead of overwriting it', () async {
      file.writeAsStringSync('{ not json');
      final store = await RecordingStore.openAt(file);
      expect(store.items, isEmpty);
      expect(File('${file.path}.corrupt').existsSync(), isTrue);
      expect(File('${file.path}.corrupt').readAsStringSync(), '{ not json');
    });
  });

  group('sharing', () {
    test('export files are never written into share_plus\'s own cache folder', () {
      // share_plus wipes <cache>/share_plus before every share and throws if the
      // file is inside it, which broke sharing on a real device.
      final dir = exportDirPath('/data/user/0/app/cache');
      expect(dir, isNot(contains('share_plus')));
      expect(dir, startsWith('/data/user/0/app/cache/'));
    });

    test('summary lists the total and every segment', () {
      final text = recordingSummary(sample(), UnitSystem.metric);
      expect(text, startsWith('Showdist: 17.00 m'));
      expect(text, contains('3 points, 2 segments'));
      expect(text, contains('1. 5.00 m'));
      expect(text, contains('2. 12.00 m'));
    });

    test('summary respects the unit system', () {
      expect(recordingSummary(sample(), UnitSystem.imperial), contains('1. 16′ 5″'));
    });

    test('summary truncates long recordings and points at the file', () {
      final many = Recording(
        id: 'm',
        createdAt: DateTime(2026, 1, 1),
        points: [for (var i = 0; i < 30; i++) Vec3(i.toDouble(), 0, 0)],
      );
      final text = recordingSummary(many, UnitSystem.metric, maxSegments: 5);
      expect(text, contains('5. 1.00 m'));
      expect(text, isNot(contains('6. ')));
      expect(text, endsWith('+ 24 more in the attached file'));
    });

    test('error messages are one short line', () {
      final long = 'Share failed\n at dev.example.Foo.bar(Foo.kt:1)';
      expect(shareErrorMessage(Exception(long)), isNot(contains('\n')));
      expect(shareErrorMessage(Exception('x' * 500)).length, lessThanOrEqualTo(120));
    });
  });
}
