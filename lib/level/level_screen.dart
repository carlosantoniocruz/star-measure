import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../common/caption.dart';
import '../theme.dart';

/// Within this many degrees of plumb, the bubble reads as level.
const _levelThresholdDeg = 0.3;

/// A bubble level for things mounted on a wall — a shelf, a picture frame, a
/// TV bracket. Hold the phone upright and flat against the wall (or against
/// whatever you're checking); the dot centres and the ring lights up
/// when it's plumb.
class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  // Smoothed tilt, in units of g (roughly -1..1 near plumb). Raw readings are
  // noisy, so each sample nudges this rather than replacing it outright.
  final _tilt = ValueNotifier<Offset>(Offset.zero);
  StreamSubscription<AccelerometerEvent>? _sub;

  static const _smoothing = 0.15;

  @override
  void initState() {
    super.initState();
    // onError: ignored — a device without an accelerometer (or a platform
    // that can't reach it) just leaves the bubble centred, instead of crashing.
    _sub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
        .listen(_onEvent, onError: (_) {});
  }

  void _onEvent(AccelerometerEvent e) {
    // Held upright and flat against a wall, plumb reads x≈0, z≈0, y≈±9.8
    // (gravity's reaction force runs down the phone's long axis, not out of
    // the screen). x is roll — tilting left/right while flush against the
    // wall, which is what "is this shelf level" actually measures. z is
    // whether the phone itself is held flush against the wall rather than
    // tipped forward or back off it.
    const g = 9.80665;
    final sample = Offset(e.x / g, e.z / g);
    final prev = _tilt.value;
    _tilt.value = Offset(
      prev.dx + (sample.dx - prev.dx) * _smoothing,
      prev.dy + (sample.dy - prev.dy) * _smoothing,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tilt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.bar,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.onSurface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Caption('LEVEL', color: palette.onSurface),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<Offset>(
          valueListenable: _tilt,
          builder: (context, tilt, _) {
            final degrees = math.atan(tilt.distance) * 180 / math.pi;
            final level = degrees <= _levelThresholdDeg;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
                  child: Caption(
                    'HOLD FLAT AGAINST THE WALL',
                    size: 11,
                    spacing: 2,
                    color: palette.onBaseMuted,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: CustomPaint(
                      size: const Size(260, 260),
                      painter: _BubblePainter(tilt: tilt, level: level, palette: palette),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Text(
                    '${degrees.toStringAsFixed(1)}°',
                    style: TextStyle(
                      // Text always uses onBase — emphasis isn't guaranteed
                      // to meet text contrast in every theme (see theme.dart);
                      // "level" is already signalled by the ring lighting up.
                      color: palette.onBase,
                      fontSize: 40,
                      fontWeight: FontWeight.w200,
                      fontFeatures: [...showdistFontFeatures, const FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter({required this.tilt, required this.level, required this.palette});

  final Offset tilt;
  final bool level;
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = palette.onBase.withValues(alpha: 0.35);
    canvas.drawCircle(c, radius, ring);
    canvas.drawCircle(c, 1.5, Paint()..color = palette.onBase.withValues(alpha: 0.35));

    // Bubble offset from centre, clamped to the ring.
    final raw = Offset(tilt.dx, -tilt.dy) * radius;
    final bubble = raw.distance > radius ? raw * (radius / raw.distance) : raw;
    final accent = level ? palette.emphasis : palette.onBase;

    canvas.drawCircle(c + bubble, level ? 12 : 9, Paint()..color = accent);
    if (level) {
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = palette.emphasis,
      );
    }
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.tilt != tilt || old.level != level || old.palette != palette;
}
