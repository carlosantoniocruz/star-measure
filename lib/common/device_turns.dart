import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// How far to turn content, in clockwise quarter turns, so it reads upright
/// however the phone is held — while the screen itself stays locked to
/// portrait. 0 = portrait, 1 = turned onto its left edge, -1 = onto its right
/// edge. Upside-down is ignored and keeps whatever was showing.
///
/// Reads the accelerometer at [SensorInterval.normalInterval] (5 Hz, the
/// slowest standard rate) — enough to follow the phone being turned, at a
/// fraction of the cost of the game rate the Leveler needs.
class DeviceTurns extends ValueNotifier<int> {
  DeviceTurns() : super(0);

  StreamSubscription<AccelerometerEvent>? _sub;

  void start() {
    // onError: ignored — no accelerometer (or no platform, in tests) just
    // leaves everything upright.
    _sub ??= accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen(
      (e) => value = quarterTurnsFor(e.x, e.y, value),
      onError: (Object _) {},
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Degrees either side of the 45° diagonal where the current orientation is
/// kept, so the buttons don't flip back and forth when the phone is held
/// right at the boundary.
const _hysteresisDeg = 10.0;

/// Below this much in-screen gravity (m/s²) the phone is lying roughly flat,
/// and which way is "up" on screen is meaningless — keep [current].
const _flatThreshold = 3.0;

/// [x] and [y] are raw accelerometer readings in the phone's own frame (m/s²):
/// held upright in portrait, y ≈ +9.8; lying on its left edge, x ≈ +9.8.
@visibleForTesting
int quarterTurnsFor(double x, double y, int current) {
  if (math.sqrt(x * x + y * y) < _flatThreshold) return current;
  // 0° = upright portrait, +90° = on its left edge, -90° = on its right edge.
  final deg = math.atan2(x, y) * 180 / math.pi;
  if (deg.abs() < 45 - _hysteresisDeg) return 0;
  if (deg > 45 + _hysteresisDeg && deg < 135 - _hysteresisDeg) return 1;
  if (deg < -45 - _hysteresisDeg && deg > -135 + _hysteresisDeg) return -1;
  return current;
}
