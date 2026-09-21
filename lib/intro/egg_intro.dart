import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../common/diamond.dart';
import '../theme.dart';
import 'logo_painter.dart';
import 'starfield.dart';

/// Connect the ring of diamonds, watch the logo fly out of the starfield,
/// then hold it to launch. Calls [onLaunch] once (also when skipped).
class EggIntro extends StatefulWidget {
  const EggIntro({super.key, required this.onLaunch});

  final VoidCallback onLaunch;

  @override
  State<EggIntro> createState() => _EggIntroState();
}

enum _Stage { connect, reveal, ready }

class _EggIntroState extends State<EggIntro> with TickerProviderStateMixin {
  static const _count = 12;
  static const _hitRadius = 40.0;

  final _stars = generateStars(110);
  late final Ticker _ticker;
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _charge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  double _time = 0;
  double _flow = 0;
  Duration _last = Duration.zero;

  final List<int> _lit = [];
  Offset? _finger;
  Size _size = Size.zero;
  Timer? _haptics;
  bool _launched = false;

  Offset get _ringCenter => _size.center(Offset.zero);
  double get _ringRadius => math.min(_size.width, _size.height) * 0.34;
  double get _logoRadius => math.min(_size.width, _size.height) * 0.30;

  _Stage get _stage {
    if (_lit.length < _count) return _Stage.connect;
    return _reveal.isCompleted ? _Stage.ready : _Stage.reveal;
  }

  double get _streak {
    if (_stage == _Stage.connect) return 0;
    final fly = 1 - Curves.easeOut.transform(_reveal.value);
    final c = _charge.value;
    return fly * 1.2 + c * c * 2;
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _charge.addStatusListener((status) {
      if (status == AnimationStatus.completed) _launch();
    });
  }

  @override
  void dispose() {
    _haptics?.cancel();
    _ticker.dispose();
    _reveal.dispose();
    _charge.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _time += dt;
    _flow += dt * (_streak * 0.12 + 0.008);
    setState(() {});
  }

  Offset _diamond(int i) =>
      _ringCenter + Offset.fromDirection(-math.pi / 2 + i * 2 * math.pi / _count, _ringRadius);

  void _touch(Offset p) {
    if (_lit.length >= _count) return;
    for (var i = 0; i < _count; i++) {
      if (_lit.contains(i) || (p - _diamond(i)).distance > _hitRadius) continue;
      _lit.add(i);
      HapticFeedback.selectionClick();
      if (_lit.length == _count) {
        _finger = null;
        HapticFeedback.mediumImpact();
        _reveal.forward();
      }
      break;
    }
  }

  void _pressStart(Offset p) {
    if (_stage != _Stage.ready || _launched) return;
    if ((p - _ringCenter).distance > _logoRadius * 1.4) return;
    _charge.forward(from: _charge.value);
    _haptics?.cancel();
    _haptics = Timer.periodic(const Duration(milliseconds: 120), (_) {
      final c = _charge.value;
      if (c <= 0 || _launched) return;
      HapticFeedback.lightImpact();
    });
  }

  void _pressEnd() {
    _haptics?.cancel();
    if (_launched || _charge.value == 0) return;
    _charge.animateBack(0, duration: const Duration(milliseconds: 400));
  }

  void _launch() {
    if (_launched) return;
    _launched = true;
    _haptics?.cancel();
    HapticFeedback.mediumImpact();
    widget.onLaunch();
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;
    final reveal = Curves.easeOutCubic.transform(_reveal.value);
    final charge = _charge.value;

    return Scaffold(
      backgroundColor: Sky.space,
      body: LayoutBuilder(
        builder: (context, box) {
          _size = box.biggest;
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => _pressStart(e.localPosition),
            onPointerUp: (_) => _pressEnd(),
            onPointerCancel: (_) => _pressEnd(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _touch(d.localPosition),
              onPanUpdate: (d) {
                _finger = d.localPosition;
                _touch(d.localPosition);
              },
              onPanEnd: (_) => _finger = null,
              onPanCancel: () => _finger = null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: StarfieldPainter(
                      stars: _stars,
                      time: _time,
                      flow: _flow,
                      streak: _streak,
                    ),
                  ),
                  CustomPaint(
                    painter: _RingPainter(
                      center: _ringCenter,
                      radius: _ringRadius,
                      count: _count,
                      lit: List.of(_lit),
                      finger: _finger,
                      time: _time,
                      opacity: stage == _Stage.connect ? 1 : 1 - math.min(1, _reveal.value * 5),
                    ),
                  ),
                  CustomPaint(
                    painter: LogoPainter(
                      scale: stage == _Stage.connect ? 0 : 0.8 + 0.2 * reveal,
                      opacity: stage == _Stage.connect ? 0 : math.min(1, _reveal.value * 2.5),
                      time: _time,
                      charge: charge,
                      showRing: stage == _Stage.ready,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _size.height / 2 + _logoRadius * 1.4,
                    child: Opacity(
                      opacity: math.max(0, (_reveal.value - 0.6) / 0.4),
                      child: const _Caption('STAR MEASURE', size: 13, spacing: 6, color: Sky.star),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 48,
                    child: SafeArea(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: switch (stage) {
                          _Stage.connect => const _Caption('CONNECT THE STARS', key: ValueKey('c')),
                          _Stage.reveal => const SizedBox(key: ValueKey('r'), height: 16),
                          _Stage.ready => const _Caption('HOLD THE LOGO TO LAUNCH', key: ValueKey('h')),
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 8,
                    child: SafeArea(
                      child: TextButton(
                        onPressed: _launch,
                        style: TextButton.styleFrom(foregroundColor: Sky.dust),
                        child: const Text('SKIP', style: TextStyle(letterSpacing: 3, fontSize: 12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {super.key, this.size = 12, this.spacing = 3, this.color = Sky.dust});

  final String text;
  final double size, spacing;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w600,
          letterSpacing: spacing,
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.center,
    required this.radius,
    required this.count,
    required this.lit,
    required this.finger,
    required this.time,
    required this.opacity,
  });

  final Offset center;
  final double radius, time, opacity;
  final int count;
  final List<int> lit;
  final Offset? finger;

  Offset _at(int i) => center + Offset.fromDirection(-math.pi / 2 + i * 2 * math.pi / count, radius);

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    final line = Paint()
      ..color = Sky.star.withValues(alpha: 0.8 * opacity)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < lit.length; i++) {
      canvas.drawLine(_at(lit[i - 1]), _at(lit[i]), line);
    }
    if (finger != null && lit.isNotEmpty) {
      canvas.drawLine(
        _at(lit.last),
        finger!,
        Paint()
          ..color = Sky.star.withValues(alpha: 0.35 * opacity)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i < count; i++) {
      final p = _at(i);
      if (lit.contains(i)) {
        canvas
          ..drawPath(
            diamondPath(p, 14),
            Paint()
              ..color = Sky.planet.withValues(alpha: 0.25 * opacity)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          )
          ..drawPath(diamondPath(p, 10), Paint()..color = Sky.star.withValues(alpha: opacity))
          ..drawPath(diamondPath(p, 4), Paint()..color = Sky.planet.withValues(alpha: opacity));
      } else {
        final pulse = math.sin(time * 2 + i);
        canvas.drawPath(
          diamondPath(p, 11 + 1.5 * pulse),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Sky.star.withValues(alpha: (0.35 + 0.25 * pulse) * opacity),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => true;
}
