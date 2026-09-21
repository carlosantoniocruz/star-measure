import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show PlatformException;
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

/// Where export files are written before sharing.
///
/// This must NOT be `<cache>/share_plus`: share_plus empties that folder at the
/// start of every share, and throws if the file being shared lives inside it.
/// It copies the file into its own folder, so anywhere else in the cache works.
@visibleForTesting
String exportDirPath(String cacheDir) => '$cacheDir/exports';

/// Plain-text version of a recording, for apps that show only the message text
/// and drop the attached file (messaging apps, notes).
String recordingSummary(Recording r, UnitSystem units, {int maxSegments = 20}) {
  final segments = r.segments;
  final buf = StringBuffer()
    ..writeln('Star Measure: ${formatLength(r.total, units)}')
    ..writeln('${r.points.length} points, ${segments.length} segments · ${formatStamp(r.createdAt)}');
  final shown = segments.length < maxSegments ? segments.length : maxSegments;
  for (var i = 0; i < shown; i++) {
    buf.writeln('${i + 1}. ${formatLength(segments[i], units)}');
  }
  if (segments.length > shown) buf.writeln('+ ${segments.length - shown} more in the attached file');
  return buf.toString().trimRight();
}

/// Opens the Android share sheet with the recording attached as a file and its
/// segment lengths as text. Throws if the file can't be written or shared.
Future<void> shareRecording(Recording r, UnitSystem units, ExportFormat format) async {
  final dir = Directory(exportDirPath((await ArChannel.dirs()).cache));
  // Drop earlier exports; share_plus has already copied whatever it needed.
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);

  final t = r.createdAt;
  String two(int n) => n.toString().padLeft(2, '0');
  final name =
      'star-measure-${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}.${format.extension}';
  final file = File('${dir.path}/$name');
  await file.writeAsString(
    format == ExportFormat.csv ? r.toCsv(units) : r.toExportJson(units),
    flush: true,
  );

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: format.mimeType, name: name)],
      subject: 'Star Measure: ${formatLength(r.total, units)}',
      text: recordingSummary(r, units),
    ),
  );
}

/// A one-line reason for a failed share, without the Java stack trace.
String shareErrorMessage(Object e) {
  final raw = e is PlatformException ? (e.message ?? e.code) : e.toString();
  final firstLine = raw.split('\n').first.trim();
  return firstLine.length > 120 ? '${firstLine.substring(0, 117)}...' : firstLine;
}
