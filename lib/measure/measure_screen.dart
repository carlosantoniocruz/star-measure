import 'dart:async';

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../common/diamond.dart';
import '../theme.dart';
import 'ar_channel.dart';
import 'ar_frame.dart';
import 'constellation_painter.dart';
import 'recording.dart';
import 'recording_store.dart';
import 'share_recording.dart';
import 'units.dart';

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _frame = ValueNotifier<ArFrame>(ArFrame.empty);
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6);

  StreamSubscription<ArFrame>? _sub;
  RecordingStore? _store;
  _Problem? _problem;
  bool _running = false;
  UnitSystem _units = UnitSystem.metric;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker.start();
    RecordingStore.open().then((s) {
      if (mounted) setState(() => _store = s);
    });
    _begin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    ArChannel.stop();
    _ticker.dispose();
    _frame.dispose();
    _time.dispose();
    _store?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && (_problem?.retryOnResume ?? false)) _begin();
  }

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
          'Star Measure needs Google Play Services for AR to see surfaces.',
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

  /// Long-press: stop measuring, save what's on screen, and start fresh.
  Future<void> _record() async {
    final points = _frame.value.points;
    if (points.length < 2) return;
    final store = _store;
    if (store == null) return;

    HapticFeedback.mediumImpact();
    final recording = Recording.fromPoints(points);
    await ArChannel.clear();
    await store.add(recording);
    if (!mounted) return;
    await _showSaved(recording);
  }

  Future<void> _share(Recording r, ExportFormat format) async {
    try {
      await shareRecording(r, _units, format);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share: ${shareErrorMessage(e)}')),
      );
    }
  }

  Future<void> _showSaved(Recording r) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Sky.space,
      showDragHandle: true,
      builder: (context) => _SavedSheet(
        recording: r,
        units: _units,
        onShare: (format) {
          Navigator.pop(context);
          _share(r, format);
        },
      ),
    );
  }

  Future<void> _showRecordings() {
    final store = _store;
    if (store == null) return Future.value();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Sky.space,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _RecordingsSheet(
        store: store,
        units: _units,
        onShare: (r, format) {
          Navigator.pop(context);
          _share(r, format);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return Scaffold(
      backgroundColor: Sky.space,
      body: problem != null
          ? _ProblemView(problem: problem)
          : _running
              ? _buildAr()
              : const Center(child: _Caption('WAKING THE CAMERA')),
    );
  }

  Widget _buildAr() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _ArView(),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xAA000000)],
                stops: [0, 0.18, 0.72, 1],
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: ConstellationPainter(frame: _frame, time: _time, units: _units),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    ListenableBuilder(
                      listenable: _store ?? _time,
                      builder: (context, _) => _IconAction(
                        icon: Icons.format_list_bulleted_rounded,
                        tooltip: 'Saved measurements',
                        badge: _store?.items.length ?? 0,
                        onTap: _store == null ? null : _showRecordings,
                      ),
                    ),
                    const Spacer(),
                    _UnitToggle(value: _units, onChanged: (u) => setState(() => _units = u)),
                    const SizedBox(width: 4),
                  ],
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<ArFrame>(
                  valueListenable: _frame,
                  builder: (context, f, _) => Column(
                    children: [
                      _Hint(text: _hint(f)),
                      if (f.points.length >= 2) ...[
                        const SizedBox(height: 6),
                        Text(
                          formatLength(f.totalLength, _units),
                          style: const TextStyle(
                            color: Sky.star,
                            fontSize: 34,
                            fontWeight: FontWeight.w200,
                            fontFeatures: [FontFeature.tabularFigures()],
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
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _IconAction(
                          icon: Icons.undo_rounded,
                          tooltip: 'Undo last point',
                          onTap: hasPoints ? ArChannel.undo : null,
                        ),
                        _AddButton(
                          enabled: f.reticle != null,
                          canRecord: f.points.length >= 2,
                          onAdd: _addPoint,
                          onRecord: _record,
                        ),
                        _IconAction(
                          icon: Icons.close_rounded,
                          tooltip: 'Clear all points',
                          onTap: hasPoints ? ArChannel.clear : null,
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
        return 'Tap to add · hold to save';
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

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: Sky.dust, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 3),
      );
}

/// One quiet line of guidance; no chip, no border.
class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        text,
        key: ValueKey(text),
        style: TextStyle(
          color: Sky.star.withValues(alpha: 0.85),
          fontSize: 13,
          letterSpacing: 0.3,
          shadows: const [Shadow(blurRadius: 6, color: Color(0xAA000000))],
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              color: on ? Sky.planet : Sky.star.withValues(alpha: 0.5),
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
  const _IconAction({required this.icon, required this.tooltip, required this.onTap, this.badge = 0});

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
              Icon(icon, color: Sky.star.withValues(alpha: enabled ? 0.9 : 0.3), size: 24),
              if (badge > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Text(
                    '$badge',
                    style: const TextStyle(color: Sky.planet, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A thin ring around a diamond. Tap adds a point (lit green when the reticle
/// is on a surface). Once two points exist, holding fills the ring and saves.
class _AddButton extends StatefulWidget {
  const _AddButton({
    required this.enabled,
    required this.canRecord,
    required this.onAdd,
    required this.onRecord,
  });

  final bool enabled, canRecord;
  final VoidCallback onAdd, onRecord;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> with SingleTickerProviderStateMixin {
  late final AnimationController _charge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onRecord();
        _charge.value = 0;
      }
    });

  @override
  void dispose() {
    _charge.dispose();
    super.dispose();
  }

  void _cancel() {
    if (_charge.status != AnimationStatus.completed) {
      _charge.animateBack(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lit = widget.enabled;
    return Semantics(
      button: true,
      enabled: lit,
      label: 'Place point. Hold to save measurement',
      child: GestureDetector(
        onTap: lit ? widget.onAdd : null,
        onLongPressStart: widget.canRecord
            ? (_) {
                HapticFeedback.selectionClick();
                _charge.forward(from: 0);
              }
            : null,
        onLongPressEnd: (_) => _cancel(),
        onLongPressCancel: _cancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _charge,
          builder: (context, _) => CustomPaint(
            size: const Size(76, 76),
            painter: _AddButtonPainter(lit: lit, charge: _charge.value),
          ),
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
    final accent = lit ? Sky.planet : Sky.star.withValues(alpha: 0.35);

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
          ..color = Sky.star,
      );
    }
    canvas.drawPath(diamondPath(c, 11), Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_AddButtonPainter old) => old.lit != lit || old.charge != charge;
}

/// Shown right after a long-press save.
class _SavedSheet extends StatelessWidget {
  const _SavedSheet({required this.recording, required this.units, required this.onShare});

  final Recording recording;
  final UnitSystem units;
  final ValueChanged<ExportFormat> onShare;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Caption('SAVED'),
            const SizedBox(height: 10),
            Text(
              formatLength(recording.total, units),
              style: const TextStyle(color: Sky.star, fontSize: 44, fontWeight: FontWeight.w200),
            ),
            const SizedBox(height: 4),
            Text(
              '${recording.points.length} points · ${recording.segments.length} segments',
              style: const TextStyle(color: Sky.dust, fontSize: 13),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                for (final format in ExportFormat.values) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onShare(format),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text('Share ${format.label}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Sky.star,
                        side: BorderSide(color: Sky.star.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  if (format != ExportFormat.values.last) const SizedBox(width: 12),
                ],
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Sky.dust),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingsSheet extends StatelessWidget {
  const _RecordingsSheet({required this.store, required this.units, required this.onShare});

  final RecordingStore store;
  final UnitSystem units;
  final void Function(Recording, ExportFormat) onShare;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final items = store.items;
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(32, 8, 32, 40),
                child: Text(
                  'Nothing saved yet.\nPlace two or more points, then hold the diamond to save.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Sky.dust, fontSize: 14, height: 1.5),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: Sky.star.withValues(alpha: 0.08)),
              itemBuilder: (context, i) {
                final r = items[i];
                return ListTile(
                  title: Text(
                    formatLength(r.total, units),
                    style: const TextStyle(color: Sky.star, fontSize: 20, fontWeight: FontWeight.w300),
                  ),
                  subtitle: Text(
                    '${r.points.length} points · ${formatStamp(r.createdAt)}',
                    style: const TextStyle(color: Sky.dust, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<ExportFormat>(
                        tooltip: 'Share',
                        icon: const Icon(Icons.ios_share_rounded, color: Sky.star, size: 22),
                        color: const Color(0xFF12141C),
                        onSelected: (format) => onShare(r, format),
                        itemBuilder: (_) => [
                          for (final format in ExportFormat.values)
                            PopupMenuItem(value: format, child: Text('Share ${format.label}')),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: Icon(Icons.delete_outline_rounded, color: Sky.star.withValues(alpha: 0.6), size: 22),
                        onPressed: () => store.remove(r.id),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
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
                child: CustomPaint(painter: _DiamondMark(Sky.planet.withValues(alpha: 0.85))),
              ),
              const SizedBox(height: 24),
              Text(
                problem.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Sky.star, fontSize: 22, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 12),
              Text(
                problem.body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Sky.dust, fontSize: 14, height: 1.4),
              ),
              if (problem.action != null) ...[
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: problem.onAction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Sky.star,
                    side: BorderSide(color: Sky.star.withValues(alpha: 0.3)),
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

class _DiamondMark extends CustomPainter {
  const _DiamondMark(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
        diamondPath(size.center(Offset.zero), size.height / 2),
        Paint()..color = color,
      );

  @override
  bool shouldRepaint(_DiamondMark old) => old.color != color;
}
