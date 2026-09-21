import 'package:flutter/services.dart';

import 'ar_frame.dart';

/// Thin wrapper over the native ARCore bridge in `ArMeasureController.kt`.
abstract final class ArChannel {
  static const viewType = 'ar_measure/view';
  static const _method = MethodChannel('ar_measure/ar');
  static const _events = EventChannel('ar_measure/frames');

  /// The app's private `files` and `cache` directories.
  static Future<({String files, String cache})> dirs() async {
    final m = await _method.invokeMapMethod<String, String>('dirs');
    return (files: m!['files']!, cache: m['cache']!);
  }

  /// Starts (or resumes) the session. Returns `ready`, `installRequested`,
  /// `cameraDenied`, `unsupported`, `declined`, `outdated`, `cameraBusy` or `error:<msg>`.
  static Future<String> start() async =>
      await _method.invokeMethod<String>('start') ?? 'error:no response';

  static Future<void> stop() => _method.invokeMethod<void>('stop');
  static Future<void> addPoint() => _method.invokeMethod<void>('addPoint');
  static Future<void> undo() => _method.invokeMethod<void>('undo');
  static Future<void> clear() => _method.invokeMethod<void>('clear');

  static Stream<ArFrame> frames() => _events
      .receiveBroadcastStream()
      .map((event) => ArFrame.parse((event as List).cast<double>()));
}
