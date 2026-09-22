import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../common/caption.dart';
import '../theme.dart';

/// Within this many degrees of true level, the bubble reads as level.
const _levelThresholdDeg = 0.3;

/// How noisy raw accelerometer samples are smoothed into the displayed
/// reading — each sample nudges the estimate rather than replacing it.
const _smoothing = 0.15;

/// Degrees of roll needed to push the bubble all the way to the end of the
/// vial. Small — a hardware spirit level is sensitive.
const _fullScaleDeg = 15.0;

/// A single-axis bubble level for hanging shelves and picture frames: hold
/// the phone flat against the wall (or the surface itself), whichever long
/// edge resting against it. Works in portrait or landscape — the vial always
/// runs along the phone's current long edge — and Zero (top right) can null
/// the reading against a wall that isn't quite true.
class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  // Smoothed raw accelerometer x/y, in the phone's own fixed frame (not the
  // screen's — see _rollDeg). Roughly -1..1 g near level.
  final _raw = ValueNotifier<Offset>(Offset.zero);
  StreamSubscription<AccelerometerEvent>? _sub;

  /// The roll reading at the moment Zero was last pressed, subtracted from
  /// every reading after. Zero itself means "not calibrated".
  double _zeroDeg = 0;

  @override
  void initState() {
    super.initState();
    // The rest of the app is portrait-only; this screen alone follows
    // however the phone is actually being held against the surface.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // onError: ignored — a device without an accelerometer (or a platform
    // that can't reach it) just leaves the bubble centred, instead of crashing.
    _sub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
        .listen(_onEvent, onError: (_) {});
  }

  void _onEvent(AccelerometerEvent e) {
    const g = 9.80665;
    final sample = Offset(e.x / g, e.y / g);
    final prev = _raw.value;
    _raw.value = Offset(
      prev.dx + (sample.dx - prev.dx) * _smoothing,
      prev.dy + (sample.dy - prev.dy) * _smoothing,
    );
  }

  /// Roll relative to the *nearest* axis-aligned orientation (portrait, or
  /// either landscape), from raw device-frame accelerometer g-fractions.
  /// Working relative to the nearest 90° means the same formula reads
  /// correctly in portrait and landscape without needing to ask Flutter
  /// which one it's currently rendering.
  static double _rollDeg(Offset xy) {
    final theta = math.atan2(xy.dx, xy.dy) * 180 / math.pi;
    final nearest90 = (theta / 90).round() * 90;
    return theta - nearest90;
  }

  void _zero() {
    HapticFeedback.selectionClick();
    setState(() => _zeroDeg = _rollDeg(_raw.value));
  }

  void _resetZero() {
    HapticFeedback.selectionClick();
    setState(() => _zeroDeg = 0);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _raw.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return Scaffold(
      // The vial's own screen: warmGray background, with darkTyrianBlue for
      // its outline, centre marks and readout — buttons and the heading stay
      // on the app's usual theme (below) for contrast and consistency.
      backgroundColor: Palette.warmGray,
      appBar: AppBar(
        backgroundColor: Palette.darkTyrianBlue,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Palette.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Caption('LEVELER', color: Palette.white),
        actions: [
          IconButton(
            tooltip: 'Zero — null against an uneven wall',
            icon: const Icon(Icons.center_focus_strong_rounded),
            onPressed: _zero,
          ),
          IconButton(
            tooltip: 'Reset to true level',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _zeroDeg == 0 ? null : _resetZero,
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<Offset>(
          valueListenable: _raw,
          builder: (context, raw, _) {
            final deg = _rollDeg(raw) - _zeroDeg;
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(32, 20, 32, 0),
                  child: Caption(
                    'HOLD FLAT AGAINST THE SURFACE',
                    size: 11,
                    spacing: 2,
                    color: Palette.darkTyrianBlue,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) => CustomPaint(
                        size: constraints.biggest,
                        painter: _VialPainter(degrees: deg, portrait: portrait),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Text(
                    '${deg.abs().toStringAsFixed(1)}°',
                    style: TextStyle(
                      color: Palette.darkTyrianBlue,
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

/// A rounded vial — like a real hardware-store spirit level — running along
/// whichever of [size]'s dimensions is currently the phone's long edge, with
/// a bubble sliding smoothly along it as [degrees] changes.
class _VialPainter extends CustomPainter {
  const _VialPainter({required this.degrees, required this.portrait});

  final double degrees;
  final bool portrait;

  static const _thickness = 84.0;
  static const _margin = 28.0;
  static const _bubbleDiameter = 56.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final length = (portrait ? size.height : size.width) - _margin * 2;
    final vialSize = portrait ? Size(_thickness, length) : Size(length, _thickness);
    final vialRect = Rect.fromCenter(center: center, width: vialSize.width, height: vialSize.height);
    final rrect = RRect.fromRectAndRadius(vialRect, Radius.circular(_thickness / 2));

    // seaGreen "liquid" filling the vial, darkTyrianBlue for its own outline.
    canvas.drawRRect(rrect, Paint()..color = Palette.seaGreen);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Palette.darkTyrianBlue,
    );

    // Centre marks — the etched lines a real vial has either side of true
    // centre — framing where the bubble sits when level. They brighten to
    // white, the bubble's own colour, as extra confirmation once it's
    // actually settled between them.
    final level = degrees.abs() <= _levelThresholdDeg;
    final markGap = _bubbleDiameter / 2 + 5;
    final markHalf = _thickness / 2 - 10;
    final markPaint = Paint()
      ..strokeWidth = level ? 3.5 : 2.5
      ..color = level ? Palette.white : Palette.darkTyrianBlue;
    if (portrait) {
      canvas.drawLine(center + Offset(-markHalf, -markGap), center + Offset(markHalf, -markGap), markPaint);
      canvas.drawLine(center + Offset(-markHalf, markGap), center + Offset(markHalf, markGap), markPaint);
    } else {
      canvas.drawLine(center + Offset(-markGap, -markHalf), center + Offset(-markGap, markHalf), markPaint);
      canvas.drawLine(center + Offset(markGap, -markHalf), center + Offset(markGap, markHalf), markPaint);
    }

    // The bubble, clamped so it never slides past the vial's rounded ends.
    // White on seaGreen alone is a soft edge, so it gets a thin darkTyrianBlue
    // outline too, like the meniscus around a real bubble.
    final travel = length / 2 - _bubbleDiameter / 2 - 6;
    final fraction = (degrees / _fullScaleDeg).clamp(-1.0, 1.0);
    final offset = portrait ? Offset(0, fraction * travel) : Offset(fraction * travel, 0);
    final bubbleCenter = center + offset;
    canvas.drawCircle(bubbleCenter, _bubbleDiameter / 2, Paint()..color = Palette.white);
    canvas.drawCircle(
      bubbleCenter,
      _bubbleDiameter / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Palette.darkTyrianBlue,
    );
  }

  @override
  bool shouldRepaint(_VialPainter old) => old.degrees != degrees || old.portrait != portrait;
}
