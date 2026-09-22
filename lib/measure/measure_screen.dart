import 'dart:async';

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../common/caption.dart';
import '../settings.dart';
import '../theme.dart';
import 'ar_channel.dart' show ArChannel, arRouteObserver;
import 'ar_frame.dart';
import 'constellation_painter.dart';
import 'history_screen.dart';
import 'recording.dart';
import 'recording_sheet.dart';
import 'recording_store.dart';
import 'units.dart';

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key, required this.settings, required this.store});

  final AppSettings settings;

  /// Saved measurements — shared with the main menu, which owns it.
  final RecordingStore store;

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

/// Something that stops AR from starting, with what the user can do about it.
class _Problem {
  const _Problem(this.title, this.body, {this.action, this.onAction, this.retryOnResume = false});

  final String title, body;
  final String? action;
  final VoidCallback? onAction;

  /// Retry automatically when the app comes back to the foreground
  /// (after installing ARCore or granting permission in Settings).
  final bool retryOnResume;
}

class _MeasureScreenState extends State<MeasureScreen>
    with WidgetsBindingObserver, RouteAware, TickerProviderStateMixin {
  final _frame = ValueNotifier<ArFrame>(ArFrame.empty);
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6);

  /// Hold anywhere on screen to save: shared by the full-screen gesture
  /// detector and the button's own charge-ring display.
  late final AnimationController _charge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _record();
        _charge.value = 0;
      }
    });

  StreamSubscription<ArFrame>? _sub;
  _Problem? _problem;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker.start();
    _begin();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) arRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    arRouteObserver.unsubscribe(this);
    _sub?.cancel();
    ArChannel.stop();
    _ticker.dispose();
    _charge.dispose();
    _frame.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && (_problem?.retryOnResume ?? false)) _begin();
  }

  /// Another route (History) was pushed on top of this one — pause the
  /// session in place rather than tearing it down; points and anchors survive.
  @override
  void didPushNext() => ArChannel.pause();

  /// Back from that route — resume where we left off.
  @override
  void didPopNext() => ArChannel.resume();

  Future<void> _begin() async {
    setState(() {
      _problem = null;
      _running = false;
    });

    final permission = await Permission.camera.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      final forever = permission.isPermanentlyDenied;
      _fail(_Problem(
        'Camera access needed',
        'Measuring uses the camera to track surfaces. Nothing is recorded or uploaded.',
        action: forever ? 'Open settings' : 'Allow camera',
        onAction: forever ? openAppSettings : _begin,
        retryOnResume: forever,
      ));
      return;
    }

    final status = await ArChannel.start();
    if (!mounted) return;
    switch (status) {
      case 'ready':
        _sub ??= ArChannel.frames().listen((f) => _frame.value = f);
        setState(() => _running = true);
      case 'installRequested':
        _fail(const _Problem(
          'Installing AR services',
          'Google Play Services for AR is being installed. Come back here when it finishes.',
          retryOnResume: true,
        ));
      case 'declined':
        _fail(_Problem(
          'AR services required',
          'Showdist needs Google Play Services for AR to see surfaces.',
          action: 'Try again',
          onAction: _begin,
        ));
      case 'unsupported':
        _fail(const _Problem(
          'Device not supported',
          'This device does not support ARCore, which measuring depends on.',
        ));
      case 'outdated':
        _fail(_Problem(
          'AR services out of date',
          'Update Google Play Services for AR from the Play Store, then try again.',
          action: 'Try again',
          onAction: _begin,
        ));
      case 'cameraBusy':
        _fail(_Problem(
          'Camera unavailable',
          'Another app is using the camera. Close it and try again.',
          action: 'Try again',
          onAction: _begin,
        ));
      default:
        _fail(_Problem('Something went wrong', status, action: 'Try again', onAction: _begin));
    }
  }

  void _fail(_Problem problem) => setState(() => _problem = problem);

  void _addPoint() {
    HapticFeedback.selectionClick();
    ArChannel.addPoint();
  }

  /// Start the save charge — from the button, or from anywhere else on
  /// screen. Ignored with fewer than two points, same as before.
  void _chargeStart() {
    if (_frame.value.points.length < 2) return;
    if (_charge.status == AnimationStatus.forward) return;
    HapticFeedback.selectionClick();
    _charge.forward(from: 0);
  }

  void _chargeCancel() {
    if (_charge.status != AnimationStatus.completed) {
      _charge.animateBack(0, duration: const Duration(milliseconds: 200));
    }
  }

  /// Charge completed: stop measuring, save what's on screen, and start fresh.
  Future<void> _record() async {
    final points = _frame.value.points;
    if (points.length < 2) return;
    HapticFeedback.mediumImpact();
    final recording = Recording.fromPoints(points);
    await ArChannel.clear();
    await widget.store.add(recording);
    if (!mounted) return;
    await _showSaved(recording);
  }

  Future<void> _showSaved(Recording r) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.darkTyrianBlue,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => RecordingSheet(
        title: 'SAVED',
        recording: r,
        units: widget.settings.units,
        onChoice: (choice) {
          Navigator.pop(sheetContext);
          performShareChoice(sheetContext, r, widget.settings.units, choice);
        },
      ),
    );
  }

  Future<void> _showHistory() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(store: widget.store, units: widget.settings.units),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return Scaffold(
      backgroundColor: Palette.darkTyrianBlue,
      body: problem != null
          ? _ProblemView(problem: problem)
          : _running
              ? _buildAr()
              : const Center(child: Caption('WAKING THE CAMERA', color: Palette.warmGray)),
    );
  }

  Widget _buildAr() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (_) => _chargeStart(),
      onLongPressEnd: (_) => _chargeCancel(),
      onLongPressCancel: _chargeCancel,
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) {
          final units = widget.settings.units;
          return Stack(
            fit: StackFit.expand,
            children: [
              const _ArView(),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // darkTyrianBlue, faded in from transparent — a scrim so
                    // the white/peachRed/seaGreen overlay reads against any
                    // real-world background, without resorting to plain black.
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x9912354E), Color(0x0012354E), Color(0x0012354E), Color(0xAA12354E)],
                      stops: [0, 0.18, 0.72, 1],
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: ConstellationPainter(frame: _frame, time: _time, units: units),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
                  child: Column(
                    children: [
                      ValueListenableBuilder<ArFrame>(
                        valueListenable: _frame,
                        builder: (context, f, _) => Column(
                          children: [
                            _Hint(text: _hint(f), color: Palette.white),
                            if (f.points.length >= 2) ...[
                              const SizedBox(height: 6),
                              Text(
                                formatLength(f.totalLength, units),
                                style: TextStyle(
                                  color: Palette.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w200,
                                  fontFeatures: [...showdistFontFeatures, const FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),
                      ValueListenableBuilder<ArFrame>(
                        valueListenable: _frame,
                        builder: (context, f, _) {
                          final hasPoints = f.points.isNotEmpty;
                          // Two items each side of the main button keeps it centred.
                          return Row(
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ListenableBuilder(
                                      listenable: widget.store,
                                      builder: (context, _) => _IconAction(
                                        icon: Icons.history_rounded,
                                        tooltip: 'History',
                                        badge: widget.store.items.length,
                                        onTap: _showHistory,
                                      ),
                                    ),
                                    _IconAction(
                                      icon: Icons.undo_rounded,
                                      tooltip: 'Undo last point',
                                      onTap: hasPoints ? ArChannel.undo : null,
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _charge,
                                builder: (context, _) => _AddButton(
                                  enabled: f.reticle != null,
                                  charge: _charge.value,
                                  onAdd: _addPoint,
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _IconAction(
                                      icon: Icons.close_rounded,
                                      tooltip: 'Clear all points',
                                      onTap: hasPoints ? ArChannel.clear : null,
                                    ),
                                    _UnitToggle(
                                      value: units,
                                      onChanged: widget.settings.setUnits,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _hint(ArFrame f) {
    switch (f.status) {
      case TrackingStatus.stopped:
        return 'Starting camera…';
      case TrackingStatus.lost:
        return switch (f.issue) {
          TrackingIssue.tooDark => 'Too dark. Find some light',
          TrackingIssue.tooFast => 'Slow down',
          TrackingIssue.fewFeatures => 'Point at a textured surface',
          TrackingIssue.cameraUnavailable => 'Camera unavailable',
          _ => 'Tracking lost. Move slowly',
        };
      case TrackingStatus.tracking:
        if (f.planes == 0 && f.reticle == null) return 'Move slowly to scan surfaces';
        if (f.reticle == null && f.points.length < 2) return 'Aim at a surface';
        if (f.points.isEmpty) return 'Tap to place a point';
        if (f.points.length == 1) return 'Place the next point';
        return 'Tap to add · hold anywhere to save';
    }
  }
}

/// The native ARCore camera view, hosted with hybrid composition so Flutter
/// widgets can draw on top of it.
class _ArView extends StatelessWidget {
  const _ArView();

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: ArChannel.viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      onCreatePlatformView: (params) {
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: ArChannel.viewType,
          layoutDirection: TextDirection.ltr,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}

/// One quiet line of guidance; no chip, no border.
class _Hint extends StatelessWidget {
  const _Hint({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        text,
        key: ValueKey(text),
        style: TextStyle(
          color: color.withValues(alpha: 0.85),
          fontSize: 13,
          letterSpacing: 0.3,
          shadows: const [Shadow(blurRadius: 6, color: Color(0xAA12354E))], // darkTyrianBlue
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.value, required this.onChanged});

  final UnitSystem value;
  final ValueChanged<UnitSystem> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(UnitSystem u, String label) {
      final on = value == u;
      return GestureDetector(
        onTap: () => onChanged(u),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 16),
          child: Text(
            label,
            style: TextStyle(
              // Weight and opacity carry the on/off state, not colour — small
              // text stays white so it always clears contrast on the camera feed.
              color: on ? Palette.white : Palette.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [option(UnitSystem.metric, 'M'), option(UnitSystem.imperial, 'FT')],
    );
  }
}

/// Bare icon, no container. Optional count badge.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: Palette.white.withValues(alpha: enabled ? 0.9 : 0.3), size: 24),
              if (badge > 0)
                Positioned(
                  right: 4,
                  top: 6,
                  child: Text(
                    '$badge',
                    style: const TextStyle(color: Palette.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A thin ring around a dot. Tap adds a point (lit when the reticle is on
/// a surface). [charge] (0 to 1, driven by holding anywhere on screen) fills
/// the ring; reaching 1 saves the measurement.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.enabled, required this.charge, required this.onAdd});

  final bool enabled;
  final double charge;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Place point. Hold anywhere on screen to save measurement',
      child: GestureDetector(
        onTap: enabled ? onAdd : null,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          size: const Size(96, 96),
          painter: _AddButtonPainter(lit: enabled, charge: charge),
        ),
      ),
    );
  }
}

class _AddButtonPainter extends CustomPainter {
  const _AddButtonPainter({required this.lit, required this.charge});

  final bool lit;
  final double charge;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    // peachRed — "actions: the capture button" — once the reticle is on a
    // surface; a dim white ring otherwise.
    final accent = lit ? Palette.peachRed : Palette.white.withValues(alpha: 0.35);

    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = accent,
    );
    if (charge > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius),
        -3.14159265 / 2,
        2 * 3.14159265 * charge,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3
          ..color = Palette.white,
      );
    }
    canvas.drawCircle(c, 14, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_AddButtonPainter old) => old.lit != lit || old.charge != charge;
}

class _ProblemView extends StatelessWidget {
  const _ProblemView({required this.problem});

  final _Problem problem;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CustomPaint(painter: _CircleMark(Palette.peachRed.withValues(alpha: 0.85))),
              ),
              const SizedBox(height: 24),
              Text(
                problem.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.white, fontSize: 22, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 12),
              Text(
                problem.body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.warmGray, fontSize: 14, height: 1.4),
              ),
              if (problem.action != null) ...[
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: problem.onAction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.white,
                    side: BorderSide(color: Palette.white.withValues(alpha: 0.3)),
                  ),
                  child: Text(problem.action!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleMark extends CustomPainter {
  const _CircleMark(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawCircle(size.center(Offset.zero), size.height / 2, Paint()..color = color);

  @override
  bool shouldRepaint(_CircleMark old) => old.color != color;
}
