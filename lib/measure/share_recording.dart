import 'dart:io';

import 'package:share_plus/share_plus.dart';

import 'ar_channel.dart';
import 'recording.dart';
import 'units.dart';

enum ExportFormat {
  csv('csv', 'text/csv'),
  json('json', 'application/json');

  const ExportFormat(this.extension, this.mimeType);

  final String extension, mimeType;
  String get label => extension.toUpperCase();
}

/// Opens the Android share sheet with the recording attached as a file.
Future<void> shareRecording(Recording r, UnitSystem units, ExportFormat format) async {
  // share_plus can only hand out files that live under <cache>/share_plus/.
  final dir = Directory('${(await ArChannel.dirs()).cache}/share_plus');
  await dir.create(recursive: true);

  final t = r.createdAt;
  String two(int n) => n.toString().padLeft(2, '0');
  final name = 'star-measure-${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}.${format.extension}';
  final file = File('${dir.path}/$name');
  await file.writeAsString(
    format == ExportFormat.csv ? r.toCsv(units) : r.toExportJson(units),
    flush: true,
  );

  final total = formatLength(r.total, units);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: format.mimeType, name: name)],
      subject: 'Star Measure: $total',
      text: 'Star Measure: $total across ${r.points.length} points',
    ),
  );
}
