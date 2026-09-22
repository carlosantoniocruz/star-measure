import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ar_frame.dart';

/// Registered as a `MaterialApp` navigator observer; lets [MeasureScreen]
/// (via `RouteAware`) tell when it's covered by another route — e.g. History
/// pushed on top of it — versus fully closed, so it can pause the AR session
/// in place rather than tearing it down.
final arRouteObserver = RouteObserver<PageRoute<void>>();

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

  /// Pauses (or resumes) the session in place — points and anchors survive —
  /// for when the user leaves the AR screen without fully closing it, e.g.
  /// by opening History on top of it.
  static Future<void> pause() => _method.invokeMethod<void>('pause');
  static Future<void> resume() => _method.invokeMethod<void>('resume');

  static Future<void> addPoint() => _method.invokeMethod<void>('addPoint');
  static Future<void> undo() => _method.invokeMethod<void>('undo');
  static Future<void> clear() => _method.invokeMethod<void>('clear');

  /// [onHigh] runs (at most once per session) when the native side finds the
  /// session using too much memory — the system is running short, or this
  /// session's heap has grown past its budget. Pass null to stop listening.
  static void onMemoryHigh(VoidCallback? onHigh) {
    _method.setMethodCallHandler(onHigh == null
        ? null
        : (call) async {
            if (call.method == 'memoryHigh') onHigh();
          });
  }

  static Stream<ArFrame> frames() => _events
      .receiveBroadcastStream()
      .map((event) => ArFrame.parse((event as List).cast<double>()));
}
