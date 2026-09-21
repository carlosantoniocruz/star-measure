import 'dart:convert';
import 'dart:io';

import 'package:ar_measure/measure/recording.dart';
import 'package:ar_measure/measure/recording_store.dart';
import 'package:ar_measure/measure/units.dart';
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
      expect(csv, contains('39′ 4″')); // 12 m
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
      expect(j['app'], 'Star Measure');
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

    test('keeps an unreadable file aside instead of overwriting it', () async {
      file.writeAsStringSync('{ not json');
      final store = await RecordingStore.openAt(file);
      expect(store.items, isEmpty);
      expect(File('${file.path}.corrupt').existsSync(), isTrue);
      expect(File('${file.path}.corrupt').readAsStringSync(), '{ not json');
    });
  });
}
