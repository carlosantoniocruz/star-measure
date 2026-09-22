import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../common/caption.dart';
import '../common/wordmark_painter.dart';
import '../level/level_screen.dart';
import '../measure/measure_screen.dart';
import '../measure/settings_screen.dart';
import '../settings.dart';
import '../theme.dart';

/// The app's home screen: choose Measurement or Level. Settings is one tap
/// away, top-right; the Showdist mark sits at the bottom, bare.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with SingleTickerProviderStateMixin {
  /// Drift of the ruler ticks, in pixels.
  final _offset = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((d) => _offset.value = d.inMicroseconds / 1e6 * _speed);

  static const _speed = 26.0; // px/s

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: _offset,
                builder: (context, offset, _) => CustomPaint(painter: _RulerPainter(offset: offset, palette: palette)),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Settings',
                icon: Icon(Icons.settings_outlined, color: palette.onBaseMuted),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => SettingsScreen(settings: widget.settings)),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MenuTile(
                        label: 'MEASUREMENT',
                        palette: palette,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => MeasureScreen(settings: widget.settings)),
                        ),
                      ),
                      _MenuTile(
                        label: 'LEVEL',
                        palette: palette,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const LevelScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Center(
                child: RepaintBoundary(
                  child: ClipRect(
                    child: SizedBox(
                      width: 180,
                      height: 84,
                      child: CustomPaint(
                        painter: WordmarkPainter(
                          paintBackground: false,
                          topColor: palette.onBase,
                          bottomColor: palette.emphasis,
                          maxWidthFraction: 0.95,
                          maxHeightFraction: 0.85,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A drifting ruler edge — a baseline with alternating minor/major tick
/// marks hanging from it, like a tape measure — behind the menu's tiles.
class _RulerPainter extends CustomPainter {
  const _RulerPainter({required this.offset, required this.palette});

  final double offset;
  final Palette palette;

  static const _minorSpacing = 24.0;
  static const _majorEvery = 5;
  static const _minorHeight = 16.0;
  static const _majorHeight = 34.0;
  static const _bandY = 0.22; // fraction of the screen height

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = palette.emphasis.withValues(alpha: 0.16)
      ..strokeWidth = 1.6;
    final major = Paint()
      ..color = palette.emphasis.withValues(alpha: 0.32)
      ..strokeWidth = 2.4;
    final baseline = Paint()
      ..color = palette.emphasis.withValues(alpha: 0.22)
      ..strokeWidth = 1.6;

    final y = size.height * _bandY;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), baseline);

    final period = _minorSpacing * _majorEvery;
    final shift = offset % period;
    var i = 0;
    for (var x = -shift; x < size.width + _minorSpacing; x += _minorSpacing, i++) {
      final isMajor = i % _majorEvery == 0;
      final h = isMajor ? _majorHeight : _minorHeight;
      canvas.drawLine(Offset(x, y), Offset(x, y + h), isMajor ? major : minor);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.offset != offset || old.palette != palette;
}

/// Just the word — no icon, no container, no divider. Tappable, centred.
class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.label, required this.onTap, required this.palette});

  final String label;
  final VoidCallback onTap;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Center(child: Caption(label, size: 15, spacing: 2, color: palette.onBase)),
        ),
      ),
    );
  }
}
