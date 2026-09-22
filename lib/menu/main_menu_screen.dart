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
/// away, top-right.
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

  static const _speed = 16.0; // px/s

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
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 100,
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
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      _MenuTile(
                        icon: Icons.straighten_rounded,
                        label: 'MEASUREMENT',
                        palette: palette,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => MeasureScreen(settings: widget.settings)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MenuTile(
                        icon: Icons.architecture_rounded,
                        label: 'LEVEL',
                        palette: palette,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const LevelScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of ruler tick marks along the top and bottom edges, drifting
/// sideways — a quiet nod to measuring, kept well behind the menu's content.
class _RulerPainter extends CustomPainter {
  const _RulerPainter({required this.offset, required this.palette});

  final double offset;
  final Palette palette;

  static const _minorSpacing = 16.0;
  static const _majorEvery = 5;
  static const _minorHeight = 7.0;
  static const _majorHeight = 15.0;

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = palette.emphasis.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = palette.emphasis.withValues(alpha: 0.22)
      ..strokeWidth = 1.4;

    final period = _minorSpacing * _majorEvery;
    final shift = offset % period;
    var i = 0;
    for (var x = -shift; x < size.width + _minorSpacing; x += _minorSpacing, i++) {
      final isMajor = i % _majorEvery == 0;
      final paint = isMajor ? major : minor;
      final h = isMajor ? _majorHeight : _minorHeight;
      canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
      canvas.drawLine(Offset(x, size.height - h), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.offset != offset || old.palette != palette;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap, required this.palette});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: palette.onSurface, size: 26),
              const SizedBox(width: 18),
              Expanded(child: Caption(label, size: 15, spacing: 2, color: palette.onSurface)),
              Icon(Icons.chevron_right_rounded, color: palette.onSurfaceMuted),
            ],
          ),
        ),
      ),
    );
  }
}
