import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show Clipboard, ClipboardData, PlatformException;
import 'package:share_plus/share_plus.dart';

import 'ar_channel.dart';
import 'recording.dart';
import 'units.dart';

/// Everything you can do with a recording from a share menu.
enum ShareChoice {
  shareText('Share .txt'),
  copyText('Copy text');

  const ShareChoice(this.label);

  final String label;
}

/// Puts the plain-text summary (total and every segment) on the clipboard.
Future<void> copyRecordingText(Recording r, UnitSystem units) =>
    Clipboard.setData(ClipboardData(text: recordingSummary(r, units)));

/// Where export files are written before sharing.
///
/// This must NOT be `<cache>/share_plus`: share_plus empties that folder at the
/// start of every share, and throws if the file being shared lives inside it.
/// It copies the file into its own folder, so anywhere else in the cache works.
@visibleForTesting
String exportDirPath(String cacheDir) => '$cacheDir/exports';

/// Plain-text version of a recording: the total and every segment. Used both
/// as the shared .txt file's contents and as the copy-to-clipboard text.
String recordingSummary(Recording r, UnitSystem units, {int maxSegments = 20}) {
  final segments = r.segments;
  final buf = StringBuffer()
    ..writeln('Showdist: ${formatLength(r.total, units)}')
    ..writeln('${r.points.length} points, ${segments.length} segments');
  final shown = segments.length < maxSegments ? segments.length : maxSegments;
  for (var i = 0; i < shown; i++) {
    buf.writeln('${i + 1}. ${formatLength(segments[i], units)}');
  }
  if (segments.length > shown) buf.writeln('+ ${segments.length - shown} more in the attached file');
  return buf.toString().trimRight();
}

/// Opens the Android share sheet — the standard system picker of installed
/// apps — with the recording as a .txt file attachment.
Future<void> shareRecording(Recording r, UnitSystem units) async {
  final file = await _writeExport('showdist-${_stamp(r.createdAt)}.txt', recordingSummary(r, units));
  await _shareFile(
    file,
    subject: 'Showdist: ${formatLength(r.total, units)}',
    text: recordingSummary(r, units),
  );
}

/// Several recordings as one plain-text document, in the order given: a
/// count, then each recording's date and full summary, every segment listed.
/// Used both as the bulk .txt file's contents and as the bulk copy text.
String recordingsSummary(List<Recording> rs, UnitSystem units) {
  if (rs.length == 1) return recordingSummary(rs.single, units, maxSegments: 1 << 30);
  final buf = StringBuffer()..writeln('Showdist: ${rs.length} measurements');
  for (final r in rs) {
    buf
      ..writeln()
      ..writeln(_dateLine(r.createdAt))
      ..writeln(recordingSummary(r, units, maxSegments: 1 << 30));
  }
  return buf.toString().trimRight();
}

/// Puts [recordingsSummary] on the clipboard.
Future<void> copyRecordingsText(List<Recording> rs, UnitSystem units) =>
    Clipboard.setData(ClipboardData(text: recordingsSummary(rs, units)));

/// Opens the Android share sheet with every recording in [rs] in one .txt file.
Future<void> shareRecordings(List<Recording> rs, UnitSystem units) async {
  if (rs.length == 1) return shareRecording(rs.single, units);
  final name = 'showdist-${_stamp(DateTime.now())}-${rs.length}.txt';
  final file = await _writeExport(name, recordingsSummary(rs, units));
  await _shareFile(file, subject: 'Showdist: ${rs.length} measurements');
}

String _two(int n) => n.toString().padLeft(2, '0');

String _stamp(DateTime t) =>
    '${t.year}${_two(t.month)}${_two(t.day)}-${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';

String _dateLine(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

/// Writes [contents] to a fresh export file named [name].
Future<File> _writeExport(String name, String contents) async {
  final dir = Directory(exportDirPath((await ArChannel.dirs()).cache));
  // Drop earlier exports; share_plus has already copied whatever it needed.
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
  final file = File('${dir.path}/$name');
  await file.writeAsString(contents, flush: true);
  return file;
}

Future<void> _shareFile(File file, {required String subject, String? text}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/plain', name: file.uri.pathSegments.last)],
      subject: subject,
      text: text,
    ),
  );
}

/// A one-line reason for a failed share, without the Java stack trace.
String shareErrorMessage(Object e) {
  final raw = e is PlatformException ? (e.message ?? e.code) : e.toString();
  final firstLine = raw.split('\n').first.trim();
  return firstLine.length > 120 ? '${firstLine.substring(0, 117)}...' : firstLine;
}
